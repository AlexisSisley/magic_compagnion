// Fichier : lib/widgets/decks/deck_card_picker.dart
// VERSION MISE À JOUR : Infinite Scroll + Sélecteur de Versions + Filtre Keyword

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/services/local_card_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/widgets/search/search_filter_modal.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/collection_service.dart';
import '../../providers/service_providers.dart';
import '../cards/versions_selector_sheet.dart'; // Import du sélecteur

class DeckCardPicker extends ConsumerStatefulWidget {
  const DeckCardPicker({super.key});

  @override
  ConsumerState<DeckCardPicker> createState() => _DeckCardPickerState();
}

class _DeckCardPickerState extends ConsumerState<DeckCardPicker> with SingleTickerProviderStateMixin {
  CollectionService get _collectionService => ref.read(collectionServiceProvider);
  LocalCardService get _localCardService => ref.read(localCardServiceProvider);
  ScryfallApiService get _apiService => ref.read(scryfallApiServiceProvider);

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController(); // Scroll partagé

  // Panier de sélection : ID Scryfall -> Quantité
  final Map<String, int> _selectedQuantities = {};
  // Cache pour renvoyer l'objet carte complet à la fin
  final Map<String, ScryfallCard> _cardCache = {};

  // --- ONGLET 1 : RECHERCHE API ---
  final TextEditingController _searchController = TextEditingController();
  List<ScryfallCard> _apiResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  SearchFilters _apiFilters = SearchFilters();
  String _apiSort = 'name'; 
  
  // Pagination API
  String? _nextApiPageUrl;
  bool _isApiLoadingMore = false;
  int _totalApiResults = 0;

  // --- ONGLET 2 : COLLECTION ---
  List<DeckCard> _fullCollection = []; // Toute la collection filtrée
  List<DeckCard> _displayedCollection = []; // Ce qu'on affiche (pagination locale)
  static const int _localPageSize = 30;
  
  final TextEditingController _collectionSearchController = TextEditingController();
  SearchFilters _collectionFilters = SearchFilters();
  String _collectionSort = 'name'; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadCollection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _collectionSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Gestion du Scroll Infini
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_tabController.index == 0) {
        _loadMoreApiResults();
      } else {
        _loadMoreLocalResults();
      }
    }
  }

  // ===========================================================================
  // LOGIQUE COLLECTION (LOCALE)
  // ===========================================================================

  Future<void> _loadCollection() async {
    if (!_localCardService.isLoaded) {
      await _localCardService.loadLocalData();
    }
    
    final col = await _collectionService.loadCollection(); 
    if (mounted) {
      setState(() {
        _fullCollection = col; // Charge brut
        _applyCollectionFilters(); // Filtre et initialise l'affichage
      });
    }
  }

  void _applyCollectionFilters() {
    final query = _collectionSearchController.text.toLowerCase();
    
    // 1. Filtrage
    List<DeckCard> filtered = _fullCollection.where((deckCard) {
      // Filtre Nom
      if (query.isNotEmpty && !deckCard.name.toLowerCase().contains(query)) {
        return false;
      }

      // Filtres Avancés
      if (_collectionFilters.cardType != null || 
          _collectionFilters.colors.isNotEmpty || 
          _collectionFilters.setCode != null ||
          _collectionFilters.keyword != null) { // <--- NOUVEAU
         
         final scryfallCard = _localCardService.getCardById(deckCard.scryfallId);
         if (scryfallCard == null) return false; 

         // Type
         if (_collectionFilters.cardType != null && 
             !scryfallCard.typeLine.toLowerCase().contains(_collectionFilters.cardType!.toLowerCase())) {
           return false;
         }
         // Couleurs
         if (_collectionFilters.colors.isNotEmpty) {
           final cardColors = scryfallCard.colorIdentity.toSet();
           if (!_collectionFilters.colors.every((c) => cardColors.contains(c))) return false;
         }
         // Set
         if (_collectionFilters.setCode != null && 
             scryfallCard.setCode.toLowerCase() != _collectionFilters.setCode!.toLowerCase()) {
           return false;
         }
         // Keyword <--- NOUVEAU
         if (_collectionFilters.keyword != null && 
             !scryfallCard.rulesText.toLowerCase().contains(_collectionFilters.keyword!.toLowerCase())) {
           return false;
         }
      }
      return true;
    }).toList();

    // 2. Tri
    filtered.sort((a, b) {
      final cardA = _localCardService.getCardById(a.scryfallId);
      final cardB = _localCardService.getCardById(b.scryfallId);

      switch (_collectionSort) {
        case 'price':
           double priceA = double.tryParse(cardA?.prices['eur'] ?? '0') ?? 0;
           double priceB = double.tryParse(cardB?.prices['eur'] ?? '0') ?? 0;
           return priceB.compareTo(priceA);
        case 'type':
           return (cardA?.typeLine ?? '').compareTo(cardB?.typeLine ?? '');
        case 'name':
        default:
           return a.name.compareTo(b.name);
      }
    });

    // 3. Reset Pagination Locale
    setState(() {
      _fullCollection = filtered; // On stocke le résultat filtré "complet" ici temporairement pour simplifier
      // Note: Dans une vraie app on garderait _allCards et _filteredCards séparés, 
      // mais ici _fullCollection est utilisé comme source filtrée.
      
      final int count = (filtered.length < _localPageSize) ? filtered.length : _localPageSize;
      _displayedCollection = filtered.sublist(0, count);
    });
  }

  void _loadMoreLocalResults() {
    if (_displayedCollection.length >= _fullCollection.length) return;
    setState(() {
      final int nextCount = (_displayedCollection.length + _localPageSize).clamp(0, _fullCollection.length);
      _displayedCollection = _fullCollection.sublist(0, nextCount);
    });
  }

  Future<void> _openCollectionFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(initialFilters: _collectionFilters),
    );
    if (newFilters != null) {
      setState(() => _collectionFilters = newFilters);
      // Recharger la collection complète brute avant de refiltrer
      // (car _fullCollection a été écrasé par le filtre précédent dans cette implémentation simplifiée)
      final col = await _collectionService.loadCollection();
      setState(() { _fullCollection = col; });
      _applyCollectionFilters();
    }
  }

  // ===========================================================================
  // LOGIQUE RECHERCHE (API)
  // ===========================================================================

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty || _apiFilters.cardType != null || _apiFilters.colors.isNotEmpty || _apiFilters.setCode != null) {
        _searchScryfall(query);
      }
    });
  }

  Future<void> _searchScryfall(String query) async {
    setState(() { _isSearching = true; _apiResults = []; _nextApiPageUrl = null; _totalApiResults = 0; });
    try {
      List<String> parts = [];
      if (query.trim().isNotEmpty) parts.add(query.trim());
      if (_apiFilters.setCode != null) parts.add('e:${_apiFilters.setCode}');
      if (_apiFilters.cardType != null) parts.add('t:${_apiFilters.cardType}');
      if (_apiFilters.colors.isNotEmpty) parts.add('c:${_apiFilters.colors.join()}');
      if (_apiFilters.rarity != null) parts.add('r:${_apiFilters.rarity}');
      if (_apiFilters.minCmc != null) parts.add('cmc>=${_apiFilters.minCmc!.toInt()}');
      if (_apiFilters.maxCmc != null) parts.add('cmc<=${_apiFilters.maxCmc!.toInt()}');
      
      // --- AJOUT DU FILTRE MOT-CLÉ/RÈGLE ---
      if (_apiFilters.keyword != null) parts.add('o:"${_apiFilters.keyword!.replaceAll('"', '')}"');
      
      String finalQuery = parts.join(' ');
      if (finalQuery.isEmpty) { 
        setState(() { _isSearching = false; });
        return; 
      }

      final data = await _apiService.searchCards(
        finalQuery,
        unique: 'cards',
        order: _apiSort,
      );

      // Gestion Pagination
      _totalApiResults = data['total_cards'] ?? 0;
      if (data['has_more'] == true) {
        _nextApiPageUrl = data['next_page'];
      }

      final List<dynamic> raw = data['data'] ?? [];
      setState(() {
        _apiResults = raw.map((json) => ScryfallCard.fromJson(json)).toList();
      });
    } catch (e) {
       // Erreur silencieuse
    } finally {
      if (mounted) setState(() { _isSearching = false; });
    }
  }

  Future<void> _loadMoreApiResults() async {
    if (_isApiLoadingMore || _nextApiPageUrl == null) return;
    setState(() { _isApiLoadingMore = true; });

    try {
      final data = await _apiService.fetchNextPage(_nextApiPageUrl!);
      if (data['has_more'] == true) {
        _nextApiPageUrl = data['next_page'];
      } else {
        _nextApiPageUrl = null;
      }

      final List<dynamic> raw = data['data'] ?? [];
      final newCards = raw.map((json) => ScryfallCard.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _apiResults.addAll(newCards);
        });
      }
    } catch (e) {
      // Erreur silencieuse
    } finally {
      if (mounted) setState(() { _isApiLoadingMore = false; });
    }
  }

  Future<void> _openApiFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(initialFilters: _apiFilters),
    );
    if (newFilters != null) {
      setState(() => _apiFilters = newFilters);
      _searchScryfall(_searchController.text);
    }
  }

  // ===========================================================================
  // GESTION DU PANIER & VERSIONS
  // ===========================================================================

  void _increment(ScryfallCard card) {
    setState(() {
      _selectedQuantities[card.id] = (_selectedQuantities[card.id] ?? 0) + 1;
      _cardCache[card.id] = card; 
    });
  }

  void _decrement(String id) {
    setState(() {
      if (_selectedQuantities.containsKey(id)) {
        _selectedQuantities[id] = _selectedQuantities[id]! - 1;
        if (_selectedQuantities[id]! <= 0) {
          _selectedQuantities.remove(id);
        }
      }
    });
  }

  void _submit() {
    List<Map<String, dynamic>> result = [];
    _selectedQuantities.forEach((id, qty) {
      if (_cardCache.containsKey(id)) {
        result.add({'card': _cardCache[id], 'quantity': qty});
      }
    });
    Navigator.pop(context, result);
  }

  Future<void> _openVersionSelector(ScryfallCard currentCard, int index, bool isApiTab) async {
    // Si c'est une carte locale sans oracle_id, on ne peut pas chercher de versions
    if (currentCard.oracleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible de trouver d'autres versions (Carte locale).")));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VersionsSelectorSheet(
        oracleId: currentCard.oracleId,
        currentCardId: currentCard.id,
        onVersionSelected: (ScryfallCard newVersion) {
          setState(() {
            // Remplace la carte dans la liste affichée
            if (isApiTab) {
              _apiResults[index] = newVersion;
            } else {
              // Pour la collection, c'est plus délicat car on manipule des DeckCard
              // Ici on met à jour l'affichage, mais l'ajout se fera avec le nouvel ID
              // Note: Cela ne modifie pas la collection physique, juste la carte qu'on s'apprête à ajouter au deck
              // Pour simplifier, on ne le fait que pour l'API ou on accepte que l'affichage change temporairement
            }
            
            // Si l'utilisateur avait déjà sélectionné l'ancienne version, on transfère la quantité ?
            // Pour l'instant, on considère que c'est une nouvelle sélection.
          });
        },
      ),
    );
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final int totalCards = _selectedQuantities.values.fold(0, (sum, qty) => sum + qty);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Ajouter des cartes", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.yellow.shade800,
          tabs: const [
            Tab(text: "Recherche API", icon: Icon(Icons.search)),
            Tab(text: "Ma Collection", icon: Icon(Icons.inventory_2_outlined)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildApiSearchTab(),
                _buildCollectionTab(),
              ],
            ),
          ),
          
          if (totalCards > 0)
            _buildBottomBar(totalCards),
        ],
      ),
    );
  }

  Widget _buildApiSearchTab() {
    return Column(
      children: [
        // Barre de recherche
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.black38,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.cinzel(color: Colors.white),
                  decoration: _buildInputDecoration("Nom de la carte...", 
                    isActive: _apiFilters.setCode != null || _apiFilters.colors.isNotEmpty || _apiFilters.cardType != null || _apiFilters.keyword != null // <--- NOUVEAU
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              _buildSortPopup(
                currentValue: _apiSort,
                onSelected: (val) { setState(() => _apiSort = val); _searchScryfall(_searchController.text); },
                options: {'name': 'Nom', 'cmc': 'Mana', 'released': 'Date', 'rarity': 'Rareté', 'eur': 'Prix'}
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: _apiFilters.setCode != null || _apiFilters.keyword != null ? Colors.yellow : Colors.white70), // <--- NOUVEAU
                onPressed: _openApiFilterModal,
              ),
            ],
          ),
        ),
        
        // Barre de statut (Nombre de résultats)
        if (_apiResults.isNotEmpty && !_isSearching)
          Container(
            width: double.infinity,
            color: Colors.black26,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Text(
              "$_totalApiResults résultats trouvés",
              style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
            ),
          ),

        if (_isSearching) const LinearProgressIndicator(color: Colors.yellow, minHeight: 2),
        
        Expanded(
          child: ListView.separated(
            controller: _scrollController, // Attaché ici
            itemCount: _apiResults.length + (_isApiLoadingMore ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              if (index == _apiResults.length) {
                return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
              }
              
              final card = _apiResults[index];
              final qty = _selectedQuantities[card.id] ?? 0;
              return _buildRichCardTile(
                card: card,
                quantity: qty,
                isApiTab: true,
                index: index,
                onAdd: () => _increment(card),
                onRemove: () => _decrement(card.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.black38,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _collectionSearchController,
                  style: GoogleFonts.cinzel(color: Colors.white),
                  decoration: _buildInputDecoration("Filtrer collection...", 
                    isActive: _collectionFilters.setCode != null || _collectionFilters.colors.isNotEmpty || _collectionFilters.keyword != null // <--- NOUVEAU
                  ),
                  onChanged: (_) => _applyCollectionFilters(),
                ),
              ),
              const SizedBox(width: 8),
               _buildSortPopup(
                currentValue: _collectionSort,
                onSelected: (val) { setState(() => _collectionSort = val); _applyCollectionFilters(); },
                options: {'name': 'Nom', 'price': 'Prix', 'type': 'Type'}
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: _collectionFilters.setCode != null || _collectionFilters.keyword != null ? Colors.yellow : Colors.white70), // <--- NOUVEAU
                onPressed: _openCollectionFilterModal,
              ),
            ],
          ),
        ),
        
        if (_displayedCollection.isNotEmpty)
           Container(
            width: double.infinity,
            color: Colors.black26,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Text(
              "${_fullCollection.length} cartes dans la collection (filtrées)",
              style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
            ),
          ),

        Expanded(
          child: ListView.separated(
            controller: _scrollController, // Attaché ici aussi
            itemCount: _displayedCollection.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final deckCard = _displayedCollection[index];
              final qtySelected = _selectedQuantities[deckCard.scryfallId] ?? 0;
              
              final scryfallCard = _localCardService.getCardById(deckCard.scryfallId) ?? 
                  ScryfallCard(
                    id: deckCard.scryfallId, 
                    oracleId: '', 
                    name: deckCard.name, 
                    imageUrl: '', 
                    rulesText: '', 
                    typeLine: '', 
                    legalities: {}, 
                    prices: {}, 
                    lang: 'en', 
                    colorIdentity: [], 
                    setName: '', 
                    setCode: '', 
                    collectorNumber: '', 
                    rarity: 'common',
                    purchaseUris: {} // <--- AJOUTÉ
                  );
              return _buildRichCardTile(
                card: scryfallCard,
                quantity: qtySelected,
                ownedQuantity: deckCard.quantity, 
                isApiTab: false,
                index: index,
                onAdd: () => _increment(scryfallCard),
                onRemove: () => _decrement(deckCard.scryfallId),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- WIDGET TUILE RICHE (Image + Mana + Boutons) ---
  Widget _buildRichCardTile({
    required ScryfallCard card,
    required int quantity,
    int? ownedQuantity,
    required bool isApiTab,
    required int index,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final imageUrl = card.smallImageUrl ?? card.imageUrl;
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      color: quantity > 0 ? Colors.yellow.shade900.withValues(alpha: 0.2) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: GestureDetector(
          // Le clic sur l'image ouvre aussi le sélecteur de version pour plus de fluidité
          onTap: isApiTab ? () => _openVersionSelector(card, index, isApiTab) : null,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: hasImage 
                  ? Image.network(imageUrl, width: 40, height: 56, fit: BoxFit.cover)
                  : Container(width: 40, height: 56, color: Colors.grey.shade800, child: const Icon(Icons.image, size: 20)),
              ),
              if (isApiTab)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    color: Colors.black54,
                    child: const Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                  ),
                )
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                card.name,
                style: GoogleFonts.cinzel(color: quantity > 0 ? Colors.yellow :Colors.white, fontWeight: quantity > 0 ? FontWeight.bold : FontWeight.normal),
                 overflow: TextOverflow.ellipsis,
                 maxLines: 1,
              ),
            ),
            // Bouton Version explicite
            if (isApiTab)
              IconButton(
                icon: const Icon(Icons.palette_outlined, size: 18, color: Colors.white54),
                tooltip: "Changer d'édition / illustration",
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(left: 8),
                onPressed: () => _openVersionSelector(card, index, isApiTab),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.manaCost != null && card.manaCost!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: _ManaDisplay(manaCost: card.manaCost!),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${card.typeLine} • ${card.setName}", 
                    style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 10), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                ),
                if (ownedQuantity != null)
                   Text(" • En stock: $ownedQuantity", style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
              ],
            )
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (quantity > 0) ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: onRemove,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              SizedBox(
                width: 24,
                child: Text('$quantity', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ],
            IconButton(
              icon: Icon(
                quantity > 0 ? Icons.add_circle : Icons.add_circle_outline, 
                color: quantity > 0 ? Colors.yellow : Colors.green
              ),
              onPressed: onAdd,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER BARRE INFÉRIEURE ---
  Widget _buildBottomBar(int totalCards) {
    final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.yellow.shade800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$totalCards cartes", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${_selectedQuantities.length} noms uniques", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow.shade800,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            icon: const Icon(Icons.check),
            label: Text("AJOUTER", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
  
  // --- HELPER INPUT DECORATION ---
  InputDecoration _buildInputDecoration(String hint, {bool isActive = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(Icons.search, color: isActive ? Colors.yellow : Colors.white70),
      filled: true, fillColor: Colors.black54,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  // --- HELPER SORT POPUP ---
  Widget _buildSortPopup({required String currentValue, required Function(String) onSelected, required Map<String, String> options}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, color: Colors.white70),
      color: const Color(0xFF1A1A1A),
      onSelected: onSelected,
      itemBuilder: (context) => options.entries.map((e) => PopupMenuItem(
        value: e.key,
        child: Row(
          children: [
            Icon(currentValue == e.key ? Icons.radio_button_checked : Icons.radio_button_unchecked, 
                 color: currentValue == e.key ? Colors.yellow : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(e.value, style: const TextStyle(color: Colors.white)),
          ],
        ),
      )).toList(),
    );
  }
}

class _ManaDisplay extends StatelessWidget {
  final String manaCost;
  const _ManaDisplay({required this.manaCost});

  @override
  Widget build(BuildContext context) {
    final RegExp regex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');
    final matches = regex.allMatches(manaCost);
    if (matches.isEmpty) return const SizedBox();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: matches.map((m) {
        final symbol = m.group(1)?.replaceAll('/', '') ?? ''; 
        final cleanSymbol = symbol.toUpperCase();
        return Padding(
          padding: const EdgeInsets.only(right: 1.0),
          child: SvgPicture.network(
            'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg',
            width: 12, height: 12,
            placeholderBuilder: (_) => Text(symbol, style: const TextStyle(fontSize: 10, color: Colors.white)),
          ),
        );
      }).toList(),
    );
  }
}