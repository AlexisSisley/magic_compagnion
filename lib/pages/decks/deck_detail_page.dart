// Fichier : lib/pages/decks/deck_detail_page.dart

import 'dart:developer';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/deck_service.dart';
import '../../services/collection_service.dart';

import '../../widgets/decks/deck_stats_tab.dart';
import '../../widgets/decks/deck_suggestions_tab.dart';
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
  
  // ignore: unused_field
  double _totalDeckPrice = 0.0;
  // ignore: unused_field
  final RegExp _manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');

  @override
  void initState() {
    super.initState();
    _currentDeck = widget.deck;
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

    // Ajouter les commandants aux IDs à charger
    if (_currentDeck.commanderScryfallId != null) uniqueIds.add(_currentDeck.commanderScryfallId!);
    if (_currentDeck.commanderSecondaryScryfallId != null) uniqueIds.add(_currentDeck.commanderSecondaryScryfallId!);

    if (uniqueIds.isEmpty) { _fullCardData = []; return; }

    List<ScryfallCard> loadedCards = [];
    const int chunkSize = 75;
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final end = (i + chunkSize < uniqueIds.length) ? i + chunkSize : uniqueIds.length;
      final batchIds = uniqueIds.sublist(i, end);
      
      final requestBody = json.encode({'identifiers': batchIds.map((id) => {'id': id}).toList()});

      try {
        final response = await http.post(
          Uri.parse('https://api.scryfall.com/cards/collection'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          final List<ScryfallCard> batchCards = (data['data'] as List).map((cardJson) => ScryfallCard.fromJson(cardJson)).toList();
          loadedCards.addAll(batchCards);
        }
      } catch (e) { log('Exception Scryfall: $e'); }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Calcul des couleurs du deck
    final Set<String> computedColors = {};
    for (var card in loadedCards) {
       // On ne compte que les couleurs des cartes dans le deck (ou les commandants)
       if (_currentDeck.mainboard.any((c) => c.scryfallId == card.id) || 
           card.id == _currentDeck.commanderScryfallId || 
           card.id == _currentDeck.commanderSecondaryScryfallId) {
         computedColors.addAll(card.colorIdentity);
       }
    }
    final order = {'W':0, 'U':1, 'B':2, 'R':3, 'G':4, 'C':5};
    final sortedColors = computedColors.toList()..sort((a,b) => (order[a]??9).compareTo(order[b]??9));
    
    if (_currentDeck.colors.join() != sortedColors.join()) {
       _currentDeck.colors = sortedColors;
       _deckService.updateDeck(_currentDeck);
    }

    _fullCardData = loadedCards;
  }

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

    if (mounted) setState(() { _totalDeckPrice = total; });
  }

  // --- ACTIONS ---

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

  Future<void> _setCommanderLogic(DeckCard deckCard) async {
    if (deckCard.scryfallId.startsWith('LOCAL:')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carte locale : Impossible de définir comme Cdt.')));
      return;
    }
    
    ScryfallCard scryfallCard;
    try {
      scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur: Données carte introuvables.')));
      return;
    }

    if (!scryfallCard.typeLine.toLowerCase().contains('legendary') && 
        !scryfallCard.rulesText.toLowerCase().contains('can be your commander')) {
       // On autorise si c'est légendaire ou si "can be your commander" (ex: Planeswalkers spécifiques)
       if (!scryfallCard.typeLine.toLowerCase().contains('legendary')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le commandant doit être une créature légendaire.')));
          return;
       }
    }

    // Demander le slot (Principal ou Partenaire)
    int? slot = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Définir comme...', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Padding(padding: EdgeInsets.all(8.0), child: Text('Commandant Principal', style: TextStyle(color: Colors.yellow))),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 2),
            child: const Padding(padding: EdgeInsets.all(8.0), child: Text('Partenaire / Background', style: TextStyle(color: Colors.blueAccent))),
          ),
        ],
      )
    );

    if (slot == null) return;

    // ignore: unused_local_variable
    final updatedDeck = await _deckService.setCommander(_currentDeck.id, scryfallCard.id, slot: slot);
    
    // Si la carte était dans le mainboard, on la retire (car elle va en zone de commandement)
    if (_currentDeck.mainboard.any((c) => c.scryfallId == scryfallCard.id)) {
       await _deckService.upsertCardInDeck(deckId: _currentDeck.id, scryfallId: scryfallCard.id, cardName: scryfallCard.name, quantityToAdd: -1);
    }

    final reloadedDeck = (await _deckService.loadDecks()).firstWhere((d) => d.id == _currentDeck.id);
    
    setState(() { _currentDeck = reloadedDeck; });
    // Recharger les données pour être sûr d'avoir l'image du partenaire si nouveau
    await _loadFullCardData(); 
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${scryfallCard.name}" défini en slot $slot.', style: GoogleFonts.cinzel())));
  }

  // --- VALIDATION LÉGALITÉ AVEC PARTENAIRES ---
  Map<String, String> _validateDeckRules(List<ScryfallCard> cardData) {
    Map<String, String> results = {};
    const List<String> formats = ['standard', 'pioneer', 'modern', 'commander'];
    
    ScryfallCard? getCard(String id) {
      if (id.startsWith('LOCAL:')) return null;
      try { return cardData.firstWhere((sc) => sc.id == id); } catch (e) { return null; }
    }

    int mainCount = _currentDeck.mainboard.fold(0, (sum, c) => sum + c.quantity);
    int commanderCount = 0;
    if (_currentDeck.commanderScryfallId != null) commanderCount++;
    if (_currentDeck.commanderSecondaryScryfallId != null) commanderCount++;

    int totalDeckSize = mainCount + commanderCount;

    for (final format in formats) {
      String status = '✅ Légal';
      
      if (format == 'commander') {
        if (totalDeckSize != 100) { 
          results[format] = '❌ $totalDeckSize cartes (100 requises)'; 
          continue; 
        }
        if (_currentDeck.commanderScryfallId == null) { 
          results[format] = '❌ Cdt manquant'; 
          continue; 
        }
        
        // Vérification Identité Couleur
        Set<String> cmdColors = {};
        final c1 = getCard(_currentDeck.commanderScryfallId!);
        if (c1 != null) cmdColors.addAll(c1.colorIdentity);
        
        if (_currentDeck.commanderSecondaryScryfallId != null) {
          final c2 = getCard(_currentDeck.commanderSecondaryScryfallId!);
          if (c2 != null) cmdColors.addAll(c2.colorIdentity);
        }

        for (final c in _currentDeck.mainboard) {
           final sc = getCard(c.scryfallId);
           if (sc == null) continue;
           if (!sc.colorIdentity.every((col) => cmdColors.contains(col))) {
             status = '❌ Illégal (Couleur: ${sc.name})';
             break;
           }
        }
      } 
      // Autres formats (Standard, Modern...)
      else {
        // En format construits 60 cartes, le commander n'existe pas vraiment, 
        // ou alors c'est du Brawl (qui n'est pas checké ici). On check juste le mainboard.
        if (mainCount < 60) {
           results[format] = '❌ < 60 cartes';
           continue;
        }
        
        for (final c in _currentDeck.mainboard) {
          final sc = getCard(c.scryfallId);
          if (sc == null) continue;
          
          final legality = sc.legalities[format];
          if (legality == 'not_legal' || legality == 'banned') {
            status = '❌ Bannie (${sc.name})';
            break;
          }
          if (!sc.typeLine.toLowerCase().contains('basic land') && c.quantity > 4) {
             status = '❌ >4 exemplaires (${sc.name})';
             break;
          }
        }
      }
      results[format] = status;
    }
    return results;
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    // Calcul du compte total incluant les commandants pour l'affichage
    int mainCount = _currentDeck.mainboard.fold(0, (s,c)=>s+c.quantity);
    int cmdCount = 0;
    if (_currentDeck.commanderScryfallId != null) cmdCount++;
    if (_currentDeck.commanderSecondaryScryfallId != null) cmdCount++;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentDeck.name, style: GoogleFonts.cinzel(fontWeight: FontWeight.w600, fontSize: 16)),
            Text("${mainCount + cmdCount} cartes • ${_currentDeck.format}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(),
          indicatorColor: Colors.yellow.shade800,
          isScrollable: true,
          tabs: [
            Tab(text: 'Main ($mainCount)'),
            Tab(text: 'Side (${_currentDeck.sideboard.fold(0, (s,c)=>s+c.quantity)})'),
            const Tab(text: 'Stats'),
            const Tab(text: 'Suggestions'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle, color: Colors.yellow), onPressed: _openCardPicker),
          // Bouton menu simplifié
          PopupMenuButton<String>(
            onSelected: (val) {
               if(val == 'legality') { setState((){_isValidating=true;}); _showValidationResults(_validateDeckRules(_fullCardData)); setState((){_isValidating=false;}); }
               if(val == 'finance') _showFinancialAnalysis();
               if(val == 'share') _shareDeck();
               if(val == 'clear') _showClearDeckDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'finance', child: Text('Finance')),
              const PopupMenuItem(value: 'legality', child: Text('Légalité')),
              const PopupMenuItem(value: 'share', child: Text('Partager')),
              const PopupMenuItem(value: 'clear', child: Text('Vider', style: TextStyle(color: Colors.red))),
            ]
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                _buildCommanderHeader(), // <--- NOUVEAU HEADER PARTENAIRES
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
                        onSetCommander: _setCommanderLogic,
                      ),
                      DeckCardListTab(
                        cardList: _currentDeck.sideboard,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        commanderId: null,
                        onUpdateQuantity: (c, q) async {
                          await _deckService.upsertCardInDeck(deckId: _currentDeck.id, scryfallId: c.scryfallId, cardName: c.name, quantityToAdd: q, toSideboard: true);
                          final d = (await _deckService.loadDecks()).firstWhere((d)=>d.id==_currentDeck.id);
                          setState(() => _currentDeck = d);
                          _calculateDeckValue();
                        }, 
                        onSetCommander: (_) {},
                      ),
                      DeckStatsTab(mainboard: _currentDeck.mainboard, cardData: _fullCardData),
                      DeckSuggestionsTab(deck: _currentDeck),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- HEADER COMMANDANTS (PARTENAIRES) ---
  Widget _buildCommanderHeader() {
    final c1Id = _currentDeck.commanderScryfallId;
    final c2Id = _currentDeck.commanderSecondaryScryfallId;

    if (c1Id == null && c2Id == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.black54,
        child: const Text("Aucun Commandant défini", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.yellow.shade900, width: 2)),
        image: const DecorationImage(image: AssetImage('assets/images/background_texture_black.png'), fit: BoxFit.cover, opacity: 0.5)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (c1Id != null) _buildSingleCommander(c1Id, "Commander"),
          if (c1Id != null && c2Id != null) 
             Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.add, color: Colors.yellow.shade700)),
          if (c2Id != null) _buildSingleCommander(c2Id, "Partenaire"),
        ],
      ),
    );
  }

  Widget _buildSingleCommander(String id, String label) {
    String imageUrl = "";
    String name = "Chargement...";
    try {
      final card = _fullCardData.firstWhere((c) => c.id == id);
      // On préfère l'art crop pour l'en-tête
      imageUrl = "https://api.scryfall.com/cards/$id?format=image&version=art_crop";
      name = card.name;
    } catch(e) {}

    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 60,
              width: double.infinity,
              color: Colors.grey.shade900,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty) Image.network(imageUrl, fit: BoxFit.cover, alignment: Alignment.topCenter),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])
                    ),
                  ),
                  Positioned(
                    bottom: 4, left: 4, right: 4,
                    child: Text(name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS (MODALES) --- (Repris de l'ancien fichier pour complétude)
  Future<void> _openCardPicker() async {
    final List<Map<String, dynamic>>? result = await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const DeckCardPicker());
    if (result != null && result.isNotEmpty) {
      setState(() { _isLoading = true; });
      for (var item in result) {
        await _deckService.upsertCardInDeck(deckId: _currentDeck.id, scryfallId: item['card'].id, cardName: item['card'].name, quantityToAdd: item['quantity']);
      }
      final updated = (await _deckService.loadDecks()).firstWhere((d) => d.id == _currentDeck.id);
      _currentDeck = updated;
      await _loadInitialData();
      _calculateDeckValue(); 
    }
  }
  
  void _showFinancialAnalysis() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => DeckFinancialSheet(deck: _currentDeck, fullCardData: _fullCardData, collection: _myCollection));
  }
  
  void _showValidationResults(Map<String, String> results) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) => Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: results.entries.map((e) => ListTile(title: Text(e.key, style: const TextStyle(color: Colors.white)), trailing: Text(e.value, style: TextStyle(color: e.value.startsWith('❌')?Colors.red:Colors.green)))).toList())));
  }
  
  void _shareDeck() {
    StringBuffer sb = StringBuffer();
    sb.writeln("Deck: ${_currentDeck.name}");
    for(var c in _currentDeck.mainboard) sb.writeln("${c.quantity} ${c.name}");
    Share.share(sb.toString());
  }
  
  Future<void> _showClearDeckDialog() async {
     await _deckService.clearDeck(_currentDeck.id);
     final d = (await _deckService.loadDecks()).firstWhere((d)=>d.id==_currentDeck.id);
     setState(() { _currentDeck = d; _fullCardData=[]; _totalDeckPrice=0; });
  }
  
  // ignore: unused_element
  Widget _getManaIcon(String symbol) => SvgPicture.network('https://svgs.scryfall.io/card-symbols/${symbol.replaceAll(RegExp(r'[{}/]'),'').toUpperCase()}.svg', width: 14);
}