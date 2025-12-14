// Fichier : lib/pages/decks/deck_detail_page.dart

import 'dart:developer';
import 'dart:convert';
import 'dart:io'; // Pour File
import 'dart:ui' as ui; // Pour la capture d'image
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Pour RenderRepaintBoundary
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // Pour sauvegarder l'image temporaire
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
import '../../widgets/decks/deck_share_preview.dart';

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
  
  // Clé pour capturer l'image
  final GlobalKey _shareKey = GlobalKey();

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

    final Set<String> computedColors = {};
    for (var card in loadedCards) {
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

      // Gestion du Foil pour le calcul
      String priceKey = deckCard.isFoil ? 'eur_foil' : 'eur';
      final double unitPrice = double.tryParse(scryfallCard.prices[priceKey] ?? scryfallCard.prices['eur'] ?? '0') ?? 0.0;
      
      final int realQuantity = (deckCard.quantity - deckCard.proxyQuantity).clamp(0, deckCard.quantity);
      total += (realQuantity * unitPrice);
    }

    if (mounted) setState(() { _totalDeckPrice = total; });
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

  Future<void> _setCommanderLogic(DeckCard deckCard) async {
    if (deckCard.scryfallId == _currentDeck.commanderScryfallId) {
        await _deckService.unsetCommander(_currentDeck.id, slot: 1);
        final d = (await _deckService.loadDecks()).firstWhere((d) => d.id == _currentDeck.id);
        setState(() => _currentDeck = d);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retiré du slot Commandant.')));
        return;
    }
    if (deckCard.scryfallId == _currentDeck.commanderSecondaryScryfallId) {
        await _deckService.unsetCommander(_currentDeck.id, slot: 2);
        final d = (await _deckService.loadDecks()).firstWhere((d) => d.id == _currentDeck.id);
        setState(() => _currentDeck = d);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retiré du slot Partenaire.')));
        return;
    }

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
       if (!scryfallCard.typeLine.toLowerCase().contains('legendary')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le commandant doit être une créature légendaire.')));
          return;
       }
    }

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

    await _deckService.setCommander(_currentDeck.id, scryfallCard.id, slot: slot);
    final reloadedDeck = (await _deckService.loadDecks()).firstWhere((d) => d.id == _currentDeck.id);
    
    setState(() { _currentDeck = reloadedDeck; });
    await _loadFullCardData(); 
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${scryfallCard.name}" défini en slot $slot.', style: GoogleFonts.cinzel())));
  }

  // --- PARTAGE EN IMAGE ---
  Future<void> _captureAndShare() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("Aperçu à partager", style: GoogleFonts.cinzel(color: Colors.white)),
          content: SingleChildScrollView(
            child: RepaintBoundary(
              key: _shareKey,
              child: DeckSharePreview(
                deck: _currentDeck,
                fullCardData: _fullCardData,
                totalPrice: _totalDeckPrice,
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Annuler")),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text("Partager"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
              onPressed: () async {
                try {
                  RenderRepaintBoundary boundary = _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                  ui.Image image = await boundary.toImage(pixelRatio: 2.0); 
                  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  Uint8List pngBytes = byteData!.buffer.asUint8List();

                  final tempDir = await getTemporaryDirectory();
                  final file = await File('${tempDir.path}/deck_share.png').create();
                  await file.writeAsBytes(pngBytes);

                  if (mounted) Navigator.pop(dialogContext); 
                  await Share.shareXFiles([XFile(file.path)], text: "Mon Deck : ${_currentDeck.name}");
                  
                } catch (e) {
                  debugPrint("Erreur capture: $e");
                  if (mounted) Navigator.pop(dialogContext);
                }
              },
            ),
          ],
        );
      }
    );
  }

  void _shareDeckText() {
    StringBuffer sb = StringBuffer();
    sb.writeln("Deck: ${_currentDeck.name}");
    sb.writeln("Format: ${_currentDeck.format}");
    sb.writeln("");
    
    if (_currentDeck.commanderScryfallId != null) {
       final cmd = _fullCardData.firstWhere(
         (c) => c.id == _currentDeck.commanderScryfallId, 
         orElse: () => ScryfallCard(
           id: '', oracleId: '', name: 'Inconnu', imageUrl: '', rulesText: '', 
           typeLine: '', legalities: {}, prices: {}, lang: '', colorIdentity: [], 
           setName: '', setCode: '', collectorNumber: '', rarity: '', purchaseUris: {}
         )
       );
       sb.writeln("COMMANDER:");
       sb.writeln("1 ${cmd.name}");
       sb.writeln("");
    }

    sb.writeln("MAINBOARD:");
    for(var c in _currentDeck.mainboard) {
      if (c.scryfallId != _currentDeck.commanderScryfallId && c.scryfallId != _currentDeck.commanderSecondaryScryfallId) {
        sb.writeln("${c.quantity} ${c.name}");
      }
    }
    Share.share(sb.toString());
  }

  Map<String, String> _validateDeckRules(List<ScryfallCard> cardData) {
    Map<String, String> results = {};
    const List<String> formats = ['standard', 'pioneer', 'modern', 'commander'];
    
    int totalDeckSize = _currentDeck.mainboard.fold(0, (sum, c) => sum + c.quantity);

    for (final format in formats) {
      String status = '✅ Légal';
      if (format == 'commander') {
        if (totalDeckSize != 100) { results[format] = '❌ $totalDeckSize cartes (100 requises)'; continue; }
        if (_currentDeck.commanderScryfallId == null) { results[format] = '❌ Cdt manquant'; continue; }
      } 
      results[format] = status;
    }

    // --- EASTER EGG SKYRIM ---
    // Ajout d'un format fictif pour la blague
    results['Bordeciel (Whiterun)'] = '🏹 Interdit (Arrow in the knee)';

    return results;
  }

  // --- MODIFICATION ICI : SAFE AREA POUR ANDROID ---
  void _showValidationResults(Map<String, String> results) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: const Color(0xFF1A1A1A), 
      builder: (context) => SafeArea( // Ajout du SafeArea ici
        child: Container(
          padding: const EdgeInsets.all(16), 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: results.entries.map((e) => ListTile(
              title: Text(e.key, style: const TextStyle(color: Colors.white)), 
              trailing: Text(e.value, style: TextStyle(color: e.value.contains('✅') ? Colors.green : Colors.red))
            )).toList()
          )
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    int mainCount = _currentDeck.mainboard.fold(0, (s,c)=>s+c.quantity);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentDeck.name, style: GoogleFonts.cinzel(fontWeight: FontWeight.w600, fontSize: 16)),
            Text("$mainCount cartes • ${_currentDeck.format}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.black,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.orange, width: 1)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
              unselectedLabelColor: Colors.white54,
              unselectedLabelStyle: GoogleFonts.cinzel(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tabs: [
                Tab(text: 'Main ($mainCount)'),
                Tab(text: 'Side (${_currentDeck.sideboard.fold(0, (s,c)=>s+c.quantity)})'),
                const Tab(text: 'Stats'),
                const Tab(text: 'Suggestions'),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle, color: Colors.yellow), onPressed: _openCardPicker),
          PopupMenuButton<String>(
            onSelected: (val) {
               if(val == 'legality') { 
                 setState((){_isValidating=true;}); 
                 _showValidationResults(_validateDeckRules(_fullCardData)); 
                 setState((){_isValidating=false;}); 
               }
               if(val == 'finance') _showFinancialAnalysis();
               if(val == 'share_text') _shareDeckText(); 
               if(val == 'share_image') _captureAndShare(); 
               if(val == 'clear') _showClearDeckDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'finance', child: Row(children: [Icon(Icons.euro, size: 18), SizedBox(width: 8), Text('Finance')])),
              const PopupMenuItem(value: 'legality', child: Row(children: [Icon(Icons.gavel, size: 18), SizedBox(width: 8), Text('Légalité')])),
              const PopupMenuItem(value: 'share_image', child: Row(children: [Icon(Icons.image, size: 18), SizedBox(width: 8), Text('Partager (Image)')])), 
              const PopupMenuItem(value: 'share_text', child: Row(children: [Icon(Icons.text_fields, size: 18), SizedBox(width: 8), Text('Partager (Texte)')])),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Vider', style: TextStyle(color: Colors.red))])),
            ]
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                _buildCommanderHeader(), 
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      DeckCardListTab(
                        cardList: _currentDeck.mainboard,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        commanderId: _currentDeck.commanderScryfallId,
                        partnerId: _currentDeck.commanderSecondaryScryfallId,
                        onUpdateQuantity: _updateQuantity,
                        onSetCommander: _setCommanderLogic,
                      ),
                      DeckCardListTab(
                        cardList: _currentDeck.sideboard,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        commanderId: null,
                        partnerId: null,
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
  
  Future<void> _showClearDeckDialog() async {
     // On vérifie s'il y avait des cartes avant de vider pour la blague
     bool hadCards = _currentDeck.mainboard.isNotEmpty;

     await _deckService.clearDeck(_currentDeck.id);
     final d = (await _deckService.loadDecks()).firstWhere((d)=>d.id==_currentDeck.id);
     
     setState(() { _currentDeck = d; _fullCardData=[]; _totalDeckPrice=0; });

     // EASTER EGG STAR WARS
     if (mounted && hadCards) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text("L'Ordre 66 a été exécuté. (Deck vidé)", style: GoogleFonts.cinzel(color: Colors.redAccent)),
           backgroundColor: Colors.black,
         )
       );
     }
  }
}