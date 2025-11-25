// Fichier : lib/pages/deck_detail_page.dart
// VERSION CORRIGÉE : Fix Export Modal Overflow + Nav Bar Padding

import 'dart:developer';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

// Import Models & Services
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/deck_service.dart';
import '../../services/collection_service.dart';

// Import Widgets
import '../../widgets/decks/deck_stats_tab.dart';
import '../../widgets/decks/draw_test_simulator.dart';
import '../../widgets/decks/deck_card_list_tab.dart'; 
import '../../widgets/decks/deck_financial_sheet.dart';
import '../../widgets/decks/deck_card_picker.dart'; 

const Map<String, Map<String, String>> kBasicLands = {
  'W': {'id': 'f5f80d82-d64c-466f-8874-9cfb00469f02', 'name': 'Plains'},
  'U': {'id': '560384fe-7be0-4b93-a515-2fe687ab2492', 'name': 'Island'},
  'B': {'id': 'e713819e-74f3-421c-a3db-e9e000e0e0e7', 'name': 'Swamp'},
  'R': {'id': '354110de-1e3d-4a94-a550-4d87dae7cd6a', 'name': 'Mountain'},
  'G': {'id': '1850d588-436e-4886-bd76-1f3a2f3a55d4', 'name': 'Forest'},
};

class DeckDetailPage extends StatefulWidget {
  final Deck deck;
  const DeckDetailPage({super.key, required this.deck});

  @override
  State<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends State<DeckDetailPage> with TickerProviderStateMixin {
  late Deck _currentDeck;
  final DeckService _deckService = DeckService();
  final CollectionService _collectionService = CollectionService();
  late TabController _tabController;
  
  // ignore: unused_field
  bool _isValidating = false; 
  bool _isLoading = true;
  
  List<ScryfallCard> _fullCardData = [];
  List<DeckCard> _myCollection = [];
  
  double _totalDeckPrice = 0.0;
  final RegExp _manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');

  @override
  void initState() {
    super.initState();
    _currentDeck = widget.deck;
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- CHARGEMENT DES DONNÉES ---

  Future<void> _loadInitialData() async {
    setState(() { _isLoading = true; });
    await Future.wait([
      _loadFullCardData(),
      _loadCollection(),
    ]);
    _calculateDeckValue(); 
    if (mounted) setState(() { _isLoading = false; });
  }

  Future<void> _loadCollection() async {
    final col = await _collectionService.loadCollection();
    if (mounted) setState(() { _myCollection = col; });
  }

  Future<void> _loadFullCardData() async {
    final allCards = [..._currentDeck.mainboard, ..._currentDeck.sideboard];
    
    final uniqueIds = allCards
        .map((c) => c.scryfallId)
        .where((id) => id.isNotEmpty && !id.startsWith('LOCAL:'))
        .toSet()
        .toList();

    if (uniqueIds.isEmpty) {
      _fullCardData = [];
      return;
    }

    List<ScryfallCard> loadedCards = [];
    const int chunkSize = 75;
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final end = (i + chunkSize < uniqueIds.length) ? i + chunkSize : uniqueIds.length;
      final batchIds = uniqueIds.sublist(i, end);
      
      final requestBody = json.encode({
        'identifiers': batchIds.map((id) => {'id': id}).toList()
      });

      try {
        final response = await http.post(
          Uri.parse('https://api.scryfall.com/cards/collection'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          final List<ScryfallCard> batchCards = (data['data'] as List)
              .map((cardJson) => ScryfallCard.fromJson(cardJson))
              .toList();
          loadedCards.addAll(batchCards);
        }
      } catch (e) {
        log('Exception Scryfall: $e');
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final Set<String> computedColors = {};
    for (var card in loadedCards) {
       computedColors.addAll(card.colorIdentity);
    }
    final order = {'W':0, 'U':1, 'B':2, 'R':3, 'G':4, 'C':5};
    final sortedColors = computedColors.toList()..sort((a,b) => (order[a]??9).compareTo(order[b]??9));
    
    if (_currentDeck.colors.join() != sortedColors.join()) {
       _currentDeck.colors = sortedColors;
       _deckService.updateDeck(_currentDeck);
    }

    _fullCardData = loadedCards;
  }

  // --- CALCUL FINANCIER ---

  void _calculateDeckValue() {
    double total = 0.0;
    final allCards = [..._currentDeck.mainboard, ..._currentDeck.sideboard];

    for (var deckCard in allCards) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      
      ScryfallCard? scryfallCard;
      try {
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) { continue; }

      final double unitPrice = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
      final int realQuantity = (deckCard.quantity - deckCard.proxyQuantity).clamp(0, deckCard.quantity);
      total += (realQuantity * unitPrice);
    }

    if (mounted) {
      setState(() {
        _totalDeckPrice = total;
      });
    }
  }

  // --- ACTIONS ---

  Future<void> _openCardPicker() async {
    final List<Map<String, dynamic>>? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DeckCardPicker(),
    );

    if (result != null && result.isNotEmpty) {
      setState(() { _isLoading = true; });
      
      int countAdded = 0;
      for (var item in result) {
        final ScryfallCard card = item['card'];
        final int qty = item['quantity'];
        
        await _deckService.upsertCardInDeck(
          deckId: _currentDeck.id,
          scryfallId: card.id,
          cardName: card.name,
          quantityToAdd: qty,
        );
        countAdded += qty;
      }
      
      final updated = (await _deckService.loadDecks()).firstWhere((d) => d.id == _currentDeck.id);
      _currentDeck = updated;
      await _loadInitialData();
      _calculateDeckValue(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$countAdded cartes ajoutées !', style: GoogleFonts.cinzel()), backgroundColor: Colors.green.shade700)
        );
      }
    }
  }

  Future<void> _updateQuantity(DeckCard card, int change) async {
    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: _currentDeck.id,
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: change,
    );
    setState(() { _currentDeck = updatedDeck; });
    _calculateDeckValue(); 
  }

  Future<void> _setCommander(DeckCard deckCard) async {
    if (deckCard.scryfallId.startsWith('LOCAL:')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carte locale : Impossible de définir comme Cdt.')));
      return;
    }
    
    try {
      final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      
      if (!scryfallCard.typeLine.toLowerCase().contains('legendary') ||
          !scryfallCard.typeLine.toLowerCase().contains('creature')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le commandant doit être une créature légendaire.')));
        return;
      }

      final updatedDeck = await _deckService.setCommander(_currentDeck.id, scryfallCard.id);
      setState(() { _currentDeck = updatedDeck; });
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${scryfallCard.name}" est votre commandant.', style: GoogleFonts.cinzel())));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur: Données carte introuvables.')));
    }
  }

  // --- FONCTIONNALITÉS ---

  void _openDrawSimulator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DrawTestSimulator(
        mainboard: _currentDeck.mainboard,
        fullCardData: _fullCardData
      )
    );
  }

  Future<void> _checkLegality() async {
    setState(() { _isValidating = true; });
    final bool hasOnlyLocalCards = _currentDeck.mainboard.isNotEmpty && 
        _currentDeck.mainboard.every((card) => card.scryfallId.startsWith('LOCAL:'));
            
    if(hasOnlyLocalCards) {
        setState(() { _isValidating = false; });
      _showValidationResults({'Erreur': 'Aucune donnée Scryfall trouvée pour ce deck.'});
      return;
    }

    final validationResults = _validateDeckRules(_fullCardData); 
    setState(() { _isValidating = false; });
    _showValidationResults(validationResults);
  }

  Map<String, String> _validateDeckRules(List<ScryfallCard> cardData) {
    Map<String, String> results = {};
    const List<String> formats = ['standard', 'pioneer', 'modern', 'commander'];
    
    ScryfallCard? getCard(String id) {
      if (id.startsWith('LOCAL:')) return null;
      try { return cardData.firstWhere((sc) => sc.id == id); } catch (e) { return null; }
    }

    int mainCount = _currentDeck.mainboard.fold(0, (sum, c) => sum + c.quantity);
    int sideCount = _currentDeck.sideboard.fold(0, (sum, c) => sum + c.quantity);

    results['Deck (formats 60)'] = (mainCount < 60) ? '❌ < 60 cartes' : '✅ OK';
    results['Sideboard'] = (sideCount > 15) ? '❌ > 15 cartes' : '✅ OK';

    for (final format in formats) {
      String status = '✅ Légal';
      if (format == 'commander') {
        if (mainCount != 100) { results[format] = '❌ Illégal (100 cartes requises)'; continue; }
        if (_currentDeck.commanderScryfallId == null) { results[format] = '❌ Cdt manquant'; continue; }
        
        final cmd = getCard(_currentDeck.commanderScryfallId!);
        if (cmd == null) { results[format] = '❌ Données Cdt manquantes'; continue; }
        
        final Set<String> cmdColors = cmd.colorIdentity.toSet();
        for (final c in _currentDeck.mainboard) {
           final sc = getCard(c.scryfallId);
           if (sc == null) continue;
           if (!sc.colorIdentity.every((col) => cmdColors.contains(col))) {
             status = '❌ Illégal (Identité couleur: ${sc.name})';
             break;
           }
        }
      } else {
        for (final c in _currentDeck.mainboard) {
          final sc = getCard(c.scryfallId);
          if (sc == null) { if(format!='commander') status = '❔ Inconnu (${c.name})'; continue; }
          
          final legality = sc.legalities[format];
          if (legality == 'not_legal' || legality == 'banned') {
            status = '❌ Illégal (${sc.name})';
            break;
          }
          if (!sc.typeLine.toLowerCase().contains('basic land') && c.quantity > 4) {
             status = '❌ Illégal (>4x ${sc.name})';
             break;
          }
        }
      }
      results[format] = status;
    }
    return results;
  }

  // --- GESTION DES TERRAINS ---

  Map<String, int> _calculatePipCount() {
    Map<String, int> pipCount = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0};
    for (final deckCard in _currentDeck.mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      try {
        final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
        if (scryfallCard.typeLine.toLowerCase().contains('land')) continue;
        
        final matches = _manaPipRegex.allMatches(scryfallCard.manaCost ?? '');
        for (final match in matches) {
          final pip = match.group(1);
          if (pip != null && pipCount.containsKey(pip)) {
            pipCount[pip] = (pipCount[pip] ?? 0) + deckCard.quantity;
          }
        }
      } catch (e) { /* ignore */ }
    }
    return pipCount;
  }

  Map<String, int> _estimateLands(int targetSize, Map<String, int> pipCount) {
    final int currentNonLandCount = _currentDeck.mainboard
        .where((card) => !card.scryfallId.startsWith('LOCAL:')) 
        .fold(0, (sum, card) => sum + card.quantity);

    final int landsNeeded = targetSize - currentNonLandCount;
    if (landsNeeded <= 0) return {};

    final int totalPips = pipCount.values.fold(0, (a, b) => a + b);
    if (totalPips == 0) return {};

    Map<String, int> estimation = {};
    int landsAddedSoFar = 0;

    for (final pip in pipCount.keys) {
      int count = ((pipCount[pip]! / totalPips) * landsNeeded).round();
      if (count > 0) {
        estimation[pip] = count;
        landsAddedSoFar += count;
      }
    }

    int diff = landsNeeded - landsAddedSoFar;
    if (diff != 0 && estimation.isNotEmpty) {
      String mainPip = pipCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      estimation[mainPip] = (estimation[mainPip] ?? 0) + diff;
    }

    estimation.removeWhere((key, value) => value <= 0);
    return estimation;
  }

  Future<void> _showAutoFillLandsModal() async {
    setState(() { _isLoading = true; });
    await _loadFullCardData(); 
    setState(() { _isLoading = false; });

    final pipCount = _calculatePipCount();
    final int totalPips = pipCount.values.fold(0, (a, b) => a + b);
    final est60 = _estimateLands(60, pipCount);
    final est100 = _estimateLands(100, pipCount);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            Icon(Icons.landscape, color: Colors.green.shade400),
            const SizedBox(width: 8),
            Text('Générateur de Mana', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Total Pips', '$totalPips symboles'),
              const SizedBox(height: 4),
              _buildPipBar(pipCount, totalPips),
              const Divider(color: Colors.white24, height: 24),
              Text('Estimation pour 60 cartes :', style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildEstimationView(est60),
              const SizedBox(height: 16),
              Text('Estimation pour 100 cartes :', style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildEstimationView(est100),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.cinzel(color: Colors.white54)),
          ),
          if (est60.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addLandsToDeck(60, pipCount, totalPips);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
              child: Text('Vers 60', style: GoogleFonts.cinzel(color: Colors.white)),
            ),
          if (est100.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addLandsToDeck(100, pipCount, totalPips);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
              child: Text('Vers 100', style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Future<void> _addLandsToDeck(int targetCount, Map<String, int> pipCount, int totalPips) async {
    setState(() { _isLoading = true; });
    Deck deckCopy = _currentDeck;
    
    final int currentNonLand = _currentDeck.mainboard.fold(0, (s, c) => s + c.quantity);
    final int landsNeeded = targetCount - currentNonLand;

    if (landsNeeded > 0 && totalPips > 0) {
      Map<String, int> landsToAdd = {};
      int addedSoFar = 0;
      for (final pip in pipCount.keys) {
        int count = ((pipCount[pip]! / totalPips) * landsNeeded).round();
        landsToAdd[pip] = count;
        addedSoFar += count;
      }
      int diff = landsNeeded - addedSoFar;
      if (diff != 0) {
        String mainPip = pipCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        landsToAdd[mainPip] = (landsToAdd[mainPip] ?? 0) + diff;
      }
      for (final entry in landsToAdd.entries) {
        if (entry.value > 0) {
          deckCopy = await _deckService.upsertCardInDeck(
            deckId: deckCopy.id, 
            scryfallId: kBasicLands[entry.key]!['id']!, 
            cardName: kBasicLands[entry.key]!['name']!, 
            quantityToAdd: entry.value
          );
        }
      }
      _currentDeck = deckCopy;
    }
    
    await _loadFullCardData();
    _calculateDeckValue();
    setState(() { _isLoading = false; });
  }

  Future<void> _showClearDeckDialog() async {
     final confirm = await showDialog<bool>(
       context: context, 
       builder: (c) => AlertDialog(
         backgroundColor: const Color(0xFF1A1A1A),
         title: Text("Vider le deck ?", style: GoogleFonts.cinzel(color: Colors.white)), 
         content: const Text("Cette action est irréversible.", style: TextStyle(color: Colors.white70)),
         actions: [
           TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Annuler")),
           TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Vider", style: TextStyle(color: Colors.red))),
         ]
       )
     );
     if (confirm == true) {
       final cleared = await _deckService.clearDeck(_currentDeck.id);
       setState(() { _currentDeck = cleared; _fullCardData = []; _totalDeckPrice = 0.0; });
     }
  }

  // --- NOUVEAU : PARTAGE AVEC OPTIONS (CORRIGÉ) ---
  void _shareDeck() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true, // Permet d'adapter la hauteur
      builder: (context) {
        // On récupère le padding du bas (pour la barre de nav)
        final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        
        return Container(
          // On retire la hauteur fixe pour éviter l'overflow
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min, // S'adapte au contenu
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Format d'exportation", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Colors.white70),
                title: const Text("Liste Simple", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Quantité + Nom (Lisible)", style: TextStyle(color: Colors.white38)),
                onTap: () {
                  Navigator.pop(context);
                  _performShare(isArenaFormat: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videogame_asset, color: Colors.purpleAccent),
                title: const Text("Format Arena / MOX", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Quantité + Nom + Set + ID (Importable)", style: TextStyle(color: Colors.white38)),
                onTap: () {
                  Navigator.pop(context);
                  _performShare(isArenaFormat: true);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _performShare({required bool isArenaFormat}) {
    final sb = StringBuffer();
    
    if (!isArenaFormat) {
      // Entête lisible pour humains
      sb.writeln('Deck: ${_currentDeck.name}');
      if (_currentDeck.commanderScryfallId != null) {
         try {
           final c = _fullCardData.firstWhere((x)=>x.id==_currentDeck.commanderScryfallId);
           sb.writeln("Commander: ${c.name}");
         } catch(e){ /* */ }
      }
      sb.writeln("");
    } else {
      // Pour Arena, on commence direct par "Deck" ou "Commander"
      if (_currentDeck.commanderScryfallId != null) {
         try {
           final c = _fullCardData.firstWhere((x)=>x.id==_currentDeck.commanderScryfallId);
           sb.writeln("Commander");
           sb.writeln("1 ${c.name} (${c.setCode.toUpperCase()}) ${c.collectorNumber}");
           sb.writeln("");
         } catch(e){ /* */ }
      }
      sb.writeln("Deck");
    }

    // Fonction helper pour écrire une ligne
    void writeCardLine(DeckCard card) {
      if (isArenaFormat) {
        // Format: Qty Name (SET) CollNum
        try {
          final sc = _fullCardData.firstWhere((x) => x.id == card.scryfallId);
          sb.writeln("${card.quantity} ${sc.name} (${sc.setCode.toUpperCase()}) ${sc.collectorNumber}");
        } catch (e) {
          sb.writeln("${card.quantity} ${card.name}");
        }
      } else {
        // Format Simple
        sb.writeln("${card.quantity} ${card.name}");
      }
    }

    for(var c in _currentDeck.mainboard) {
      // Si c'est le commander, on ne le remet pas dans le deck pour Arena si déjà mis en "Commander"
      if (isArenaFormat && c.scryfallId == _currentDeck.commanderScryfallId) continue;
      writeCardLine(c);
    }

    if(_currentDeck.sideboard.isNotEmpty) {
      sb.writeln("");
      sb.writeln("Sideboard");
      for(var c in _currentDeck.sideboard) writeCardLine(c);
    }
    
    Share.share(sb.toString());
  }

  void _showFinancialAnalysis() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeckFinancialSheet(
        deck: _currentDeck,
        fullCardData: _fullCardData,
        collection: _myCollection
      ),
    );
  }

  void _showValidationResults(Map<String, String> results) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true, 
      builder: (context) => DraggableScrollableSheet( 
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text("Résultats Légalité", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...results.entries.map((e) {
                    final isError = e.value.startsWith('❌');
                    return ListTile(
                      title: Text(e.key, style: const TextStyle(color: Colors.white)), 
                      trailing: Flexible(
                        child: Text(e.value, 
                          style: TextStyle(color: isError ? Colors.red.shade300 : Colors.green.shade300, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        )
                      )
                    );
                  }),
                ],
              ),
            ),
          );
        }
      )
    );
  }

  void _showTopCardsModal() {
    List<Map<String, dynamic>> topCards = [];
    final allCards = [..._currentDeck.mainboard, ..._currentDeck.sideboard];

    for (final deckCard in allCards) {
       if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
       try {
         final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
         final double unitPrice = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
         if (unitPrice > 0) {
           topCards.add({
             'name': scryfallCard.name,
             'unitPrice': unitPrice,
             'quantity': deckCard.quantity,
             'image': scryfallCard.smallImageUrl
           });
         }
       } catch (e) { /* ... */ }
    }

    topCards.sort((a, b) => (b['unitPrice'] as double).compareTo(a['unitPrice'] as double));
    final top10 = topCards.take(10).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Top Cartes (Valeur)", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: top10.length,
                separatorBuilder: (_,__) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final item = top10[index];
                  return ListTile(
                    leading: item['image'] != null 
                        ? Image.network(item['image'], width: 30, fit: BoxFit.cover) 
                        : const Icon(Icons.style),
                    title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text("${item['quantity']}x", style: const TextStyle(color: Colors.white54)),
                    trailing: Text("${item['unitPrice']} €", style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            )
          ],
        ),
      )
    );
  }

  // --- HELPERS WIDGETS ---

  Widget _buildFinancialHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.yellow.shade900.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade800.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Valeur Estimée", style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '${_totalDeckPrice.toStringAsFixed(2)} €',
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            tooltip: 'Top Cartes',
            onPressed: _showTopCardsModal,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPipBar(Map<String, int> pips, int total) {
    if (total == 0) return const Text("Aucun coût de mana détecté.", style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 12));
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 12,
        child: Row(
          children: pips.entries.map((e) {
            if (e.value == 0) return const SizedBox();
            return Expanded(
              flex: e.value,
              child: Container(
                color: _getLandColor(e.key),
                child: Center(child: Text(e.key, style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold))),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEstimationView(Map<String, int> estimation) {
    if (estimation.isEmpty) return const Text("Le deck est déjà plein ou vide de mana.", style: TextStyle(color: Colors.white38, fontSize: 12));
    
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: estimation.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getLandColor(e.key).withValues(alpha: 0.2),
            border: Border.all(color: _getLandColor(e.key).withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _getManaIcon(e.key),
              const SizedBox(width: 4),
              Text("+${e.value}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getLandColor(String pip) {
    switch (pip) {
      case 'W': return const Color(0xFFF9FAF4);
      case 'U': return const Color(0xFF0E68AB);
      case 'B': return const Color(0xFF150B00);
      case 'R': return const Color(0xFFD3202A);
      case 'G': return const Color(0xFF00733E);
      default: return Colors.grey;
    }
  }

  Widget _getManaIcon(String symbol) {
    final String cleanSymbol = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    final String svgUrl = 'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg';
    return SvgPicture.network(
      svgUrl, height: 14, width: 14,
      placeholderBuilder: (_) => Text(symbol, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14)),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(_currentDeck.name, style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(),
          indicatorColor: Colors.yellow.shade800,
          tabs: [
            Tab(text: 'Main (${_currentDeck.mainboard.fold(0, (s,c)=>s+c.quantity)})'),
            Tab(text: 'Side (${_currentDeck.sideboard.fold(0, (s,c)=>s+c.quantity)})'),
            Tab(text: 'Stats'),
          ],
        ),
        actions: [
          // MENU 1 : GESTION DU DECK
          PopupMenuButton<String>(
            icon: const Icon(Icons.dashboard_customize, color: Colors.yellow),
            tooltip: 'Gestion du Deck',
            color: const Color(0xFF1A1A1A),
            onSelected: (value) {
              if (_isLoading) return;
              switch (value) {
                case 'add': _openCardPicker(); break;
                case 'lands': _showAutoFillLandsModal(); break;
                case 'play': _openDrawSimulator(); break;
                case 'legality': _checkLegality(); break;
                case 'clear': _showClearDeckDialog(); break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'add',
                child: Row(
                  children: [
                    const Icon(Icons.add_circle, color: Colors.yellow),
                    const SizedBox(width: 12),
                    Text('Ajouter des cartes', style: GoogleFonts.cinzel(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'lands',
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    Text('Terrains Auto', style: GoogleFonts.cinzel(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'play',
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Text('Main de départ', style: GoogleFonts.cinzel(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'legality',
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('Vérifier Légalité', style: GoogleFonts.cinzel(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red.shade300),
                    const SizedBox(width: 12),
                    Text('Vider le deck', style: GoogleFonts.cinzel(color: Colors.red.shade200)),
                  ],
                ),
              ),
            ],
          ),

          // MENU 2 : OUTILS
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            tooltip: 'Plus d\'options',
            color: const Color(0xFF1A1A1A),
            onSelected: (value) {
              if (_isLoading) return;
              switch (value) {
                case 'finance': _showFinancialAnalysis(); break;
                case 'share': _shareDeck(); break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'finance',
                child: Row(
                  children: [
                    const Icon(Icons.euro, color: Colors.amber),
                    const SizedBox(width: 12),
                    Text('Estimation & Manquants', style: GoogleFonts.cinzel(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.share, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text('Partager / Exporter', style: GoogleFonts.cinzel(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                _buildFinancialHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      DeckCardListTab(
                        cardList: _currentDeck.mainboard,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        commanderId: _currentDeck.commanderScryfallId,
                        onUpdateQuantity: _updateQuantity,
                        onSetCommander: _setCommander,
                      ),
                      DeckCardListTab(
                        cardList: _currentDeck.sideboard,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        commanderId: null,
                        onUpdateQuantity: (c, q) async {
                          await _deckService.upsertCardInDeck(
                             deckId: _currentDeck.id, scryfallId: c.scryfallId, cardName: c.name, quantityToAdd: q, toSideboard: true
                          );
                          final d = (await _deckService.loadDecks()).firstWhere((d)=>d.id==_currentDeck.id);
                          setState(() => _currentDeck = d);
                          _calculateDeckValue();
                        }, 
                        onSetCommander: (_) {},
                      ),
                      DeckStatsTab(mainboard: _currentDeck.mainboard, cardData: _fullCardData),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}