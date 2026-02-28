// Fichier : lib/pages/decks/deck_detail_page.dart

import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/deck_service.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/scryfall_api_service.dart';
import '../../providers/service_providers.dart';

import '../../widgets/decks/deck_stats_tab.dart';
import '../../widgets/decks/deck_suggestions_tab.dart';
import '../../widgets/decks/deck_card_list_tab.dart'; 
import '../../widgets/decks/deck_financial_sheet.dart';
import '../../widgets/decks/deck_card_picker.dart'; 
// IMPORT DU NOUVEAU WIDGET
import '../../widgets/decks/deck_visual_share_list.dart'; 

class DeckDetailPage extends ConsumerStatefulWidget {
  final Deck deck;
  const DeckDetailPage({super.key, required this.deck});

  @override
  ConsumerState<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends ConsumerState<DeckDetailPage> with TickerProviderStateMixin {
  DeckService get _deckService => ref.read(deckServiceProvider);
  CollectionService get _collectionService => ref.read(collectionServiceProvider);
  WishlistService get _wishlistService => ref.read(wishlistServiceProvider);
  ScryfallApiService get _apiService => ref.read(scryfallApiServiceProvider);

  late Deck _currentDeck;
  late TabController _tabController;
  
  bool _isValidating = false;
  bool _isLoading = true;
  
  List<ScryfallCard> _fullCardData = [];
  List<DeckCard> _myCollection = [];
  double _totalDeckPrice = 0.0;
  
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentDeck = widget.deck;
    _tabController = TabController(length: 6, vsync: this);
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

      try {
        final data = await _apiService.fetchCollection(
          batchIds.map((id) => {'id': id}).toList(),
        );
        final List<ScryfallCard> batchCards = (data['data'] as List).map((cardJson) => ScryfallCard.fromJson(cardJson)).toList();
        loadedCards.addAll(batchCards);
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
    final activeCards = [..._currentDeck.mainboard, ..._currentDeck.sideboard];

    for (var deckCard in activeCards) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      ScryfallCard? scryfallCard;
      try {
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) { continue; }

      String priceKey = deckCard.isFoil ? 'eur_foil' : 'eur';
      final double unitPrice = double.tryParse(scryfallCard.prices[priceKey] ?? scryfallCard.prices['eur'] ?? '0') ?? 0.0;
      
      final int realQuantity = (deckCard.quantity - deckCard.proxyQuantity).clamp(0, deckCard.quantity);
      total += (realQuantity * unitPrice);
    }

    if (mounted) setState(() { _totalDeckPrice = total; });
  }

  Future<void> _updateQuantity(DeckCard card, int change, DeckBoard board) async {
    if (change > 0 && board == DeckBoard.main && _currentDeck.format.toLowerCase() == 'commander') {
      bool isBasicLand = false;
      try {
        final scryfall = _fullCardData.firstWhere((s) => s.id == card.scryfallId);
        if (scryfall.typeLine.toLowerCase().contains('basic land')) isBasicLand = true;
        if (scryfall.rulesText.toLowerCase().contains('a deck can have any number')) isBasicLand = true;
      } catch (e) { /* Local card fallback */ }

      if (!isBasicLand && card.quantity >= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Commander : 1 seul exemplaire autorisé (sauf terrains de base)."), backgroundColor: Colors.orange)
        );
        return;
      }
    }

    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: _currentDeck.id, scryfallId: card.scryfallId, cardName: card.name,
      quantityToAdd: change, board: board
    );
    setState(() { _currentDeck = updatedDeck; });
    _calculateDeckValue(); 
  }

  Future<void> _toggleFoil(DeckCard card, DeckBoard board) async {
    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: _currentDeck.id, scryfallId: card.scryfallId, cardName: card.name,
      board: board, isFoil: !card.isFoil
    );
    setState(() { _currentDeck = updatedDeck; });
    _calculateDeckValue();
  }

  Future<void> _switchVersion(DeckCard card, ScryfallCard newVersion, DeckBoard board) async {
    final updatedDeck = await _deckService.changeCardVersion(
      deckId: _currentDeck.id, oldCard: card, newVersion: newVersion, board: board
    );
    setState(() { _currentDeck = updatedDeck; });
    await _loadFullCardData(); 
    _calculateDeckValue();
  }

  Future<void> _moveCard(DeckCard card, DeckBoard targetBoard, DeckBoard sourceBoard) async {
    if (targetBoard == sourceBoard) return;
    
    if (targetBoard == DeckBoard.main && _currentDeck.format.toLowerCase() == 'commander') {
       bool exists = _currentDeck.mainboard.any((c) => c.scryfallId == card.scryfallId);
       if (exists) {
          bool isBasic = false;
          try {
             final sc = _fullCardData.firstWhere((s) => s.id == card.scryfallId);
             if (sc.typeLine.toLowerCase().contains('basic land')) isBasic = true;
          } catch(e){}
          
          if(!isBasic) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Déjà présent dans le deck (Règle Singleton)."), backgroundColor: Colors.orange));
             return;
          }
       }
    }

    final updatedDeck = await _deckService.moveCard(
      deckId: _currentDeck.id, card: card, fromBoard: sourceBoard, toBoard: targetBoard
    );
    setState(() { _currentDeck = updatedDeck; });
    _calculateDeckValue();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Carte déplacée vers ${targetBoard.name.toUpperCase()} !"), duration: const Duration(milliseconds: 800)));
  }

  Future<void> _updateTags(DeckCard card, List<String> tags, DeckBoard board) async {
    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: _currentDeck.id, scryfallId: card.scryfallId, cardName: card.name,
      board: board, newTags: tags
    );
    setState(() { _currentDeck = updatedDeck; });
  }

  Future<void> _exportDeckWishlistToGlobal() async {
    if (_currentDeck.wishlist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La Wishlist du deck est vide.")));
      return;
    }

    final controller = TextEditingController(text: "Achats: ${_currentDeck.name}");
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Créer une Wishlist Globale", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Cela va créer une nouvelle liste dans l'onglet Wishlist de l'application avec ces cartes.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nom de la liste")),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Annuler")),
          ElevatedButton(onPressed: ()=>Navigator.pop(c, controller.text), child: const Text("Créer")),
        ],
      )
    );

    if (name != null) {
      await _wishlistService.createWishlist(name);
      final lists = await _wishlistService.loadWishlists();
      final newList = lists.lastWhere((l) => l.name == name);
      
      for(var card in _currentDeck.wishlist) {
        await _wishlistService.upsertCard(
          wishlistId: newList.id, 
          scryfallId: card.scryfallId, 
          cardName: card.name, 
          quantityToAdd: card.quantity,
          isFoil: card.isFoil
        );
      }
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Wishlist '$name' créée avec succès !"), backgroundColor: Colors.green));
    }
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

  // -----------------------------------------------------------------------
  // --- NOUVELLE FONCTION DE PARTAGE VISUEL ---
  // -----------------------------------------------------------------------
  Future<void> _captureAndShare() async {
    if (_fullCardData.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Données des cartes non chargées. Veuillez patienter.")));
       return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(16),
          title: Column(
            children: [
              Text("Aperçu avant partage", style: GoogleFonts.cinzel(color: Colors.white)),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Génération du poster en cours...", 
                  style: TextStyle(color: Colors.orangeAccent.shade100, fontSize: 11, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              // FittedBox : Force le grand widget (1080px) à tenir dans l'écran pour la preview
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: _shareKey,
                  // On utilise le nouveau Widget ici
                  child: DeckVisualShareList(
                    deck: _currentDeck,
                    fullCardData: _fullCardData,
                    totalPrice: _totalDeckPrice,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text("Annuler", style: TextStyle(color: Colors.white54))
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share, color: Colors.black),
              label: const Text("Partager l'image", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: () async {
                showDialog(
                  context: dialogContext,
                  barrierDismissible: false,
                  builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
                );

                try {
                  await Future.delayed(const Duration(milliseconds: 500));

                  RenderRepaintBoundary boundary = _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                  // Ratio 1.5 suffisant pour 1080px de large
                  ui.Image image = await boundary.toImage(pixelRatio: 1.5); 
                  
                  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  Uint8List pngBytes = byteData!.buffer.asUint8List();

                  final tempDir = await getTemporaryDirectory();
                  final fileName = 'deck_share_${DateTime.now().millisecondsSinceEpoch}.png';
                  final file = await File('${tempDir.path}/$fileName').create();
                  await file.writeAsBytes(pngBytes);

                  if (mounted) Navigator.pop(dialogContext); // Close loader
                  if (mounted) Navigator.pop(dialogContext); // Close preview

                  await Share.shareXFiles(
                    [XFile(file.path)], 
                    text: "Mon deck Commander : ${_currentDeck.name}",
                  );
                  
                } catch (e) {
                  if (mounted) Navigator.pop(dialogContext); 
                  if (mounted) Navigator.pop(dialogContext);
                  debugPrint("Erreur capture: $e");
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la génération.")));
                }
              },
            ),
          ],
        );
      }
    );
  }

  // --- PARTAGES TEXTE ---

  void _shareFullDeck() {
    StringBuffer sb = StringBuffer();
    sb.writeln("Deck: ${_currentDeck.name}");
    sb.writeln("Format: ${_currentDeck.format}");
    sb.writeln("");
    
    if (_currentDeck.commanderScryfallId != null) {
       final cmd = _fullCardData.firstWhere(
         (c) => c.id == _currentDeck.commanderScryfallId, 
         orElse: () => _createUnknownCard()
       );
       sb.writeln("COMMANDER:");
       sb.writeln("1 ${cmd.name}");
    }
    if (_currentDeck.commanderSecondaryScryfallId != null) {
       final partner = _fullCardData.firstWhere(
         (c) => c.id == _currentDeck.commanderSecondaryScryfallId, 
         orElse: () => _createUnknownCard()
       );
       sb.writeln("1 ${partner.name}");
    }
    if (_currentDeck.commanderScryfallId != null) sb.writeln("");

    sb.writeln("MAINBOARD:");
    for(var c in _currentDeck.mainboard) {
      if (c.scryfallId != _currentDeck.commanderScryfallId && c.scryfallId != _currentDeck.commanderSecondaryScryfallId) {
        sb.writeln("${c.quantity} ${c.name}");
      }
    }
    sb.writeln("");

    if (_currentDeck.sideboard.isNotEmpty) {
      sb.writeln("SIDEBOARD:");
      for(var c in _currentDeck.sideboard) {
        sb.writeln("${c.quantity} ${c.name}");
      }
    }

    Share.share(sb.toString(), subject: "Decklist : ${_currentDeck.name}");
  }

  void _shareConsidering() {
    if (_currentDeck.considering.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La liste Considering est vide.")));
      return;
    }
    StringBuffer sb = StringBuffer();
    sb.writeln("Considering for: ${_currentDeck.name}");
    sb.writeln("");
    for(var c in _currentDeck.considering) {
      sb.writeln("${c.quantity} ${c.name}");
    }
    Share.share(sb.toString(), subject: "Considering : ${_currentDeck.name}");
  }

  void _shareWishlist() {
    if (_currentDeck.wishlist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La Wishlist du deck est vide.")));
      return;
    }
    StringBuffer sb = StringBuffer();
    sb.writeln("Wishlist for: ${_currentDeck.name}");
    sb.writeln("");
    for(var c in _currentDeck.wishlist) {
      sb.writeln("${c.quantity} ${c.name}");
    }
    Share.share(sb.toString(), subject: "Wishlist : ${_currentDeck.name}");
  }

  ScryfallCard _createUnknownCard() {
    return ScryfallCard(
      id: '', oracleId: '', name: 'Inconnu', imageUrl: '', rulesText: '', 
      typeLine: '', legalities: {}, prices: {}, lang: '', colorIdentity: [], 
      setName: '', setCode: '', collectorNumber: '', rarity: '', purchaseUris: {}
    );
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
    results['Bordeciel (Whiterun)'] = '🏹 Interdit (Arrow in the knee)';
    return results;
  }

  void _showValidationResults(Map<String, String> results) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: const Color(0xFF1A1A1A), 
      builder: (context) => SafeArea(
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
    int sideCount = _currentDeck.sideboard.fold(0, (s,c)=>s+c.quantity);
    int consCount = _currentDeck.considering.fold(0, (s,c)=>s+c.quantity);
    int wishCount = _currentDeck.wishlist.fold(0, (s,c)=>s+c.quantity);

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
                _buildDragTargetTab(DeckBoard.main, 'Main ($mainCount)'),
                _buildDragTargetTab(DeckBoard.side, 'Side ($sideCount)'),
                _buildDragTargetTab(DeckBoard.considering, 'Considering ($consCount)'),
                _buildDragTargetTab(DeckBoard.wishlist, 'Wishlist ($wishCount)'),
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
               
               if(val == 'share_deck') _shareFullDeck();
               if(val == 'share_considering') _shareConsidering();
               if(val == 'share_wishlist') _shareWishlist();
               
               if(val == 'share_image') _captureAndShare(); 
               if(val == 'clear') _showClearDeckDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'finance', child: Row(children: [Icon(Icons.euro, size: 18), SizedBox(width: 8), Text('Finance')])),
              const PopupMenuItem(value: 'legality', child: Row(children: [Icon(Icons.gavel, size: 18), SizedBox(width: 8), Text('Légalité')])),
              const PopupMenuItem(value: 'share_image', child: Row(children: [Icon(Icons.image, size: 18), SizedBox(width: 8), Text('Partager (Image)')])), 
              
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'share_deck', child: Row(children: [Icon(Icons.text_snippet, size: 18, color: Colors.white70), SizedBox(width: 8), Text('Copier Decklist')])),
              const PopupMenuItem(value: 'share_considering', child: Row(children: [Icon(Icons.question_mark, size: 18, color: Colors.white70), SizedBox(width: 8), Text('Copier Considering')])),
              const PopupMenuItem(value: 'share_wishlist', child: Row(children: [Icon(Icons.star_border, size: 18, color: Colors.white70), SizedBox(width: 8), Text('Copier Wishlist')])),
              const PopupMenuDivider(),

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
                        currentBoard: DeckBoard.main,
                        onUpdateQuantity: (c,q) => _updateQuantity(c,q, DeckBoard.main),
                        onMoveCard: (c, target) => _moveCard(c, target, DeckBoard.main),
                        onUpdateTags: (c, tags) => _updateTags(c, tags, DeckBoard.main),
                        onSetCommander: _setCommanderLogic,
                        onToggleFoil: (c) => _toggleFoil(c, DeckBoard.main),
                        onSwitchVersion: (c, newV) => _switchVersion(c, newV, DeckBoard.main),
                      ),
                      DeckCardListTab(
                        cardList: _currentDeck.sideboard,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        currentBoard: DeckBoard.side,
                        onUpdateQuantity: (c,q) => _updateQuantity(c,q, DeckBoard.side),
                        onMoveCard: (c, target) => _moveCard(c, target, DeckBoard.side),
                        onUpdateTags: (c, tags) => _updateTags(c, tags, DeckBoard.side),
                        onToggleFoil: (c) => _toggleFoil(c, DeckBoard.side),
                        onSwitchVersion: (c, newV) => _switchVersion(c, newV, DeckBoard.side),
                      ),
                      DeckCardListTab(
                        cardList: _currentDeck.considering,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        currentBoard: DeckBoard.considering,
                        onUpdateQuantity: (c,q) => _updateQuantity(c,q, DeckBoard.considering),
                        onMoveCard: (c, target) => _moveCard(c, target, DeckBoard.considering),
                        onUpdateTags: (c, tags) => _updateTags(c, tags, DeckBoard.considering),
                        onToggleFoil: (c) => _toggleFoil(c, DeckBoard.considering),
                        onSwitchVersion: (c, newV) => _switchVersion(c, newV, DeckBoard.considering),
                      ),
                      DeckCardListTab(
                        cardList: _currentDeck.wishlist,
                        fullCardData: _fullCardData,
                        collection: _myCollection,
                        currentBoard: DeckBoard.wishlist,
                        onUpdateQuantity: (c,q) => _updateQuantity(c,q, DeckBoard.wishlist),
                        onMoveCard: (c, target) => _moveCard(c, target, DeckBoard.wishlist),
                        onUpdateTags: (c, tags) => _updateTags(c, tags, DeckBoard.wishlist),
                        onExportToGlobalWishlist: _exportDeckWishlistToGlobal,
                        onToggleFoil: (c) => _toggleFoil(c, DeckBoard.wishlist),
                        onSwitchVersion: (c, newV) => _switchVersion(c, newV, DeckBoard.wishlist),
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
    String? imageUrl;
    String name = "Chargement...";
    try {
      final card = _fullCardData.firstWhere((c) => c.id == id);
      imageUrl = card.artCropUrl ?? card.imageUrl;
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
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Image.network(imageUrl, fit: BoxFit.cover, alignment: Alignment.topCenter,
                      errorBuilder: (c, e, s) => const SizedBox()),
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

  Widget _buildDragTargetTab(DeckBoard board, String label) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        return details.data['sourceBoard'] != board;
      },
      onAcceptWithDetails: (details) {
        final DeckCard card = details.data['card'];
        final DeckBoard source = details.data['sourceBoard'];
        _moveCard(card, board, source);
        int index = 0;
        switch(board) {
          case DeckBoard.main: index = 0; break;
          case DeckBoard.side: index = 1; break;
          case DeckBoard.considering: index = 2; break;
          case DeckBoard.wishlist: index = 3; break;
        }
        _tabController.animateTo(index);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;
        return Tab(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: isHovered ? 4 : 0),
            decoration: isHovered 
                ? BoxDecoration(color: Colors.yellow.shade900.withOpacity(0.5), borderRadius: BorderRadius.circular(8))
                : null,
            child: Text(label),
          ),
        );
      },
    );
  }

  Future<void> _openCardPicker() async {
    final List<Map<String, dynamic>>? result = await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const DeckCardPicker());
    if (result != null && result.isNotEmpty) {
      setState(() { _isLoading = true; });
      for (var item in result) {
        await _deckService.upsertCardInDeck(deckId: _currentDeck.id, scryfallId: item['card'].id, cardName: item['card'].name, quantityToAdd: item['quantity'], board: DeckBoard.main);
      }
      final updated = (await _deckService.loadDecks()).firstWhere((d) => d.id == _currentDeck.id);
      _currentDeck = updated;
      await _loadInitialData();
    }
  }
  
  void _showFinancialAnalysis() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => DeckFinancialSheet(deck: _currentDeck, fullCardData: _fullCardData, collection: _myCollection));
  }
  
  Future<void> _showClearDeckDialog() async {
     bool hadCards = _currentDeck.mainboard.isNotEmpty;
     await _deckService.clearDeck(_currentDeck.id);
     final d = (await _deckService.loadDecks()).firstWhere((d)=>d.id==_currentDeck.id);
     setState(() { _currentDeck = d; _fullCardData=[]; _totalDeckPrice=0; });
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