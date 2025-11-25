// Fichier : lib/pages/card_search_page.dart
// VERSION MISE À JOUR : Fallback Local sur Erreur API

import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/widgets/search/search_filter_modal.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../services/collection_service.dart'; 
import '../services/wishlist_service.dart';
import 'set_list_page.dart'; 
import '../models/scryfall_set_model.dart';
import '../models/scryfall_card_model.dart';
import '../services/local_card_service.dart';
import 'card_detail_page.dart';

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({super.key});

  @override
  State<CardSearchPage> createState() => _CardSearchPageState();
}

class _CardSearchPageState extends State<CardSearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final LocalCardService _localCardService = LocalCardService();
  
  final ScrollController _scrollController = ScrollController();
  
  List<ScryfallCard> _fullLocalResults = []; 
  List<ScryfallCard> _searchResults = [];    
  static const int _localPageSize = 30;      
  
  String? _nextPageUrl; 
  bool _isApiLoadingMore = false; 
  
  SearchFilters _activeFilters = SearchFilters();
  bool _isLoading = false;
  String _statusMessage = 'Entrez un nom ou utilisez les filtres.';
  
  bool _isGridView = false; 
  Timer? _debounce; 
  String _sortBy = 'name'; // 'name', 'cmc', 'type', 'eur'

  final CollectionService _collectionService = CollectionService();
  final WishlistService _wishlistService = WishlistService();
  List<DeckCard> _collection = [];
  List<DeckCard> _wishlist = [];
  
  // ignore: unused_field
  final RegExp _manaRegex = RegExp(r'\{([^}]+)\}');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll); 
    _loadLocalData();
    _initLocalDatabase();
  }

  Future<void> _initLocalDatabase() async {
    await _localCardService.loadLocalData();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_nextPageUrl != null) {
        _loadMoreApiResults();
      } else if (_fullLocalResults.isNotEmpty) {
        _loadMoreLocalResults();
      }
    }
  }

  void _loadMoreLocalResults() {
    if (_searchResults.length >= _fullLocalResults.length) return;
    setState(() {
      final int nextCount = (_searchResults.length + _localPageSize).clamp(0, _fullLocalResults.length);
      _searchResults = _fullLocalResults.sublist(0, nextCount);
    });
  }

  Future<void> _loadMoreApiResults() async {
    if (_isApiLoadingMore || _nextPageUrl == null) return;
    setState(() { _isApiLoadingMore = true; });

    try {
      final response = await http.get(Uri.parse(_nextPageUrl!));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final String? nextUri = data['next_page']; 
        final List<dynamic> rawList = data['data'] ?? [];
        List<ScryfallCard> newCards = rawList.map((json) => ScryfallCard.fromJson(json)).toList();

        if (_sortBy == 'type') newCards.sort((a, b) => a.typeLine.compareTo(b.typeLine));

        if (mounted) {
          setState(() {
            _searchResults.addAll(newCards);
            _nextPageUrl = nextUri; 
            _isApiLoadingMore = false;
          });
        }
      } else {
        setState(() { _isApiLoadingMore = false; });
      }
    } catch (e) {
      setState(() { _isApiLoadingMore = false; });
    }
  }

  Future<void> _loadLocalData() async {
    final collection = await _collectionService.loadCollection();
    final wishlist = await _wishlistService.loadWishlist();
    if (mounted) {
      setState(() { _collection = collection; _wishlist = wishlist; });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty || _hasActiveFilters()) {
        _searchCards();
      }
    });
  }
  
  bool _hasActiveFilters() {
    return _activeFilters.setCode != null || 
           _activeFilters.cardType != null || 
           _activeFilters.colors.isNotEmpty ||
           _activeFilters.minCmc != null || 
           _activeFilters.maxCmc != null ||
           _activeFilters.rarity != null;
  }

  void _applySort(List<ScryfallCard> list) {
    switch (_sortBy) {
      case 'cmc':
        list.sort((a, b) => (a.cmc ?? 0).compareTo(b.cmc ?? 0));
        break;
      case 'type':
        list.sort((a, b) => a.typeLine.compareTo(b.typeLine));
        break;
      case 'eur':
        list.sort((a, b) => (double.tryParse(b.prices['eur']??'0')??0).compareTo(double.tryParse(a.prices['eur']??'0')??0));
        break;
      case 'name':
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }

  // --- NOUVELLE MÉTHODE DE RECHERCHE PRINCIPALE ---
  Future<void> _searchCards() async {
    if (_tabController.index != 0) _tabController.animateTo(0);
    final String query = _searchController.text.trim();
    
    if (query.isEmpty && !_hasActiveFilters()) {
      if (mounted) setState(() { _searchResults = []; _fullLocalResults = []; _nextPageUrl = null; _statusMessage = "Veuillez entrer un critère."; });
      return;
    }

    setState(() { _isLoading = true; _searchResults = []; _fullLocalResults = []; _nextPageUrl = null; _statusMessage = 'Recherche...'; });

    // 1. PRIORITÉ LOCALE : Si on n'a pas de filtre d'édition, on commence par le local (plus rapide)
    if (_localCardService.isLoaded && _activeFilters.setCode == null) {
      bool localSuccess = await _performLocalSearch(query);
      // Si on a trouvé des résultats en local, on s'arrête là pour l'instant
      if (localSuccess) return;
    }

    // 2. APPEL API : Si filtre d'édition OU pas de résultat local
    bool apiSuccess = await _searchCardsApi(query);

    // 3. FALLBACK : Si l'API échoue (404 ou Erreur) ET qu'on a la base locale chargée
    if (!apiSuccess && _localCardService.isLoaded) {
       // On relance une recherche locale en IGNORANT le filtre d'édition
       // (car c'est souvent lui qui bloque si la base locale n'a pas l'extension demandée)
       setState(() { _statusMessage = "Erreur API. Recherche locale de secours..."; });
       
       await _performLocalSearch(query, ignoreSetFilter: true);
       
       if (mounted && _searchResults.isNotEmpty) {
         setState(() {
           _statusMessage = "${_searchResults.length} résultats (Mode Hors-Ligne / Fallback)";
         });
       }
    }
  }

  // --- MÉTHODE DE RECHERCHE LOCALE EXTRAITE ---
  Future<bool> _performLocalSearch(String query, {bool ignoreSetFilter = false}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    
    // On ignore le setCode si demandé (pour le fallback)
    String? setCodeFilter = ignoreSetFilter ? null : _activeFilters.setCode;

    List<ScryfallCard> results = _localCardService.searchCards(
      query: query,
      setCode: setCodeFilter,
      cardType: _activeFilters.cardType,
      colors: _activeFilters.colors,
    );
    
    // Filtrage manuel des nouveaux champs (CMC/Rareté) sur les résultats locaux
    if (_activeFilters.minCmc != null || _activeFilters.maxCmc != null || _activeFilters.rarity != null) {
       results = results.where((c) {
         if (_activeFilters.minCmc != null && (c.cmc ?? 0) < _activeFilters.minCmc!) return false;
         if (_activeFilters.maxCmc != null && (c.cmc ?? 0) > _activeFilters.maxCmc!) return false;
         if (_activeFilters.rarity != null && c.rarity != _activeFilters.rarity) return false;
         return true;
       }).toList();
    }

    if (results.isNotEmpty) {
      _applySort(results);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fullLocalResults = results;
          final int initialCount = (results.length < _localPageSize) ? results.length : _localPageSize;
          _searchResults = results.sublist(0, initialCount);
          _statusMessage = '${results.length} cartes trouvées (Local)';
        });
      }
      return true; // Succès
    }
    return false; // Pas de résultat
  }

  // --- MÉTHODE API MODIFIÉE (Retourne bool) ---
  Future<bool> _searchCardsApi(String query) async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) { 
      // Pas de connexion = Echec immédiat pour déclencher le fallback
      return false;
    }

    List<String> queryParts = [];
    if (query.isNotEmpty) queryParts.add(query);
    
    if (_activeFilters.setCode != null) queryParts.add('e:${_activeFilters.setCode}');
    if (_activeFilters.colors.isNotEmpty) queryParts.add('c:${_activeFilters.colors.join()}');
    if (_activeFilters.cardType != null) queryParts.add('t:${_activeFilters.cardType}');
    if (_activeFilters.rarity != null) queryParts.add('r:${_activeFilters.rarity}');
    
    if (_activeFilters.minCmc != null) queryParts.add('cmc>=${_activeFilters.minCmc!.toInt()}');
    if (_activeFilters.maxCmc != null) queryParts.add('cmc<=${_activeFilters.maxCmc!.toInt()}');
    
    final String finalQuery = queryParts.join(' ');
    final prefs = await SharedPreferences.getInstance();
    final String lang = prefs.getString('glossaryLang') ?? 'fr';

    try {
      String uniqueParam = _activeFilters.setCode != null ? '&unique=prints' : '&unique=cards';
      String sortParam = '&order=name';
      if (_sortBy == 'cmc') sortParam = '&order=cmc';
      if (_sortBy == 'eur') sortParam = '&order=eur';
      
      final encodedQuery = Uri.encodeComponent(finalQuery);
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/search?q=$encodedQuery&lang=$lang$uniqueParam$sortParam'));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (data.containsKey('has_more') && data['has_more'] == true) {
           _nextPageUrl = data['next_page'];
        }

        final List<dynamic> rawList = data['data'] ?? [];
        List<ScryfallCard> apiResults = rawList.map((json) => ScryfallCard.fromJson(json)).toList();

        if (_sortBy == 'type') apiResults.sort((a, b) => a.typeLine.compareTo(b.typeLine));
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _searchResults = apiResults;
            if (_searchResults.isEmpty) { _statusMessage = 'Aucune carte trouvée (API).'; }
          });
        }
        return true; // Succès API
      } else {
        // Erreur API (404, 500...)
        if (mounted) setState(() { _isLoading = false; _statusMessage = 'Erreur API (${response.statusCode}).'; });
        return false; // Echec API -> Déclenchera le fallback
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _statusMessage = 'Erreur réseau'; });
      return false; // Echec Réseau -> Déclenchera le fallback
    }
  }

  void _onSetSelected(ScryfallSet set) {
    setState(() {
      _activeFilters = _activeFilters.copyWith(setCode: set.code);
      _searchController.clear();
    });
    _tabController.animateTo(0);
    _searchCards();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Édition : ${set.name}"),
      backgroundColor: Colors.yellow.shade800,
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _openFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) { return SearchFilterModal(initialFilters: _activeFilters); },
    );
    if (newFilters != null) { 
      setState(() { _activeFilters = newFilters; });
      _searchCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.yellow.shade800,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Cartes", icon: Icon(Icons.search)),
              Tab(text: "Éditions", icon: Icon(Icons.layers)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Column(
                children: [
                  _buildSearchBar(),
                  
                  if (_searchResults.isNotEmpty && !_isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: Colors.black26,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fullLocalResults.isNotEmpty 
                                ? "${_searchResults.length}/${_fullLocalResults.length}"
                                : "${_searchResults.length} cartes",
                            style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
                          ),
                          Row(
                            children: [
                              PopupMenuButton<String>(
                                icon: Icon(Icons.sort, color: Colors.yellow.shade700, size: 20),
                                color: const Color(0xFF1A1A1A),
                                tooltip: "Trier par...",
                                onSelected: (val) {
                                  if (_sortBy != val) {
                                    setState(() => _sortBy = val);
                                    _searchCards();
                                  }
                                },
                                itemBuilder: (context) => [
                                  _buildSortMenuItem('name', 'Nom'),
                                  _buildSortMenuItem('cmc', 'Mana (CMC)'),
                                  _buildSortMenuItem('type', 'Type'),
                                  _buildSortMenuItem('eur', 'Prix (€)'),
                                ],
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(() => _isGridView = !_isGridView),
                                child: Icon(_isGridView ? Icons.grid_view : Icons.view_list, color: Colors.white70, size: 20),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  
                  Expanded(
                    child: _isGridView 
                        ? _buildResultsGrid(key: const ValueKey('Grid')) 
                        : _buildResultsList(key: const ValueKey('List')),
                  ),
                ],
              ),
              SetListTab(onSetSelected: _onSetSelected),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            _sortBy == value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: _sortBy == value ? Colors.yellow.shade800 : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final bool hasFilters = _hasActiveFilters();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: _activeFilters.setCode != null ? 'Dans: ${_activeFilters.setCode!.toUpperCase()}...' : 'Nom de la carte...',
          hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14),
          prefixIcon: IconButton(
            icon: Icon(Icons.filter_list, color: hasFilters ? Colors.yellow.shade700 : Colors.white70),
            onPressed: _openFilterModal,
            tooltip: "Filtres avancés",
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (hasFilters)
                IconButton(
                  icon: const Icon(Icons.highlight_off, color: Colors.red),
                  tooltip: "Réinitialiser filtres",
                  onPressed: () {
                    setState(() {
                      _activeFilters = SearchFilters();
                      _searchController.clear();
                      _searchResults = []; _fullLocalResults = []; _nextPageUrl = null;
                      _statusMessage = "Entrez un nom ou choisissez une édition.";
                    });
                  },
                )
               else if (_searchController.text.isNotEmpty)
                 IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                       _searchController.clear();
                       setState(() { _searchResults = []; _fullLocalResults = []; _nextPageUrl = null; }); 
                    },
                 ),
              
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white70),
                onPressed: _searchCards,
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.55),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onSubmitted: (_) => _searchCards(),
      ),
    );
  }

  Widget _buildResultsList({Key? key}) {
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    if (_searchResults.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center)));
    }

    return ListView.builder(
      key: key,
      controller: _scrollController,
      itemCount: _searchResults.length + 1,
      padding: const EdgeInsets.only(bottom: 80), 
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          bool showLoader = false;
          if (_fullLocalResults.isNotEmpty && _searchResults.length < _fullLocalResults.length) showLoader = true;
          if (_nextPageUrl != null) showLoader = true;
          return showLoader ? const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())) : const SizedBox(height: 20);
        }
        return _buildListTile(_searchResults[index]);
      },
    );
  }

  Widget _buildListTile(ScryfallCard card) {
    final String cardName = card.name;
    final String? imageUrl = card.smallImageUrl ?? card.imageUrl;
    final String price = card.prices['eur'] ?? '--';
    final bool inWishlist = _wishlist.any((c) => c.scryfallId == card.id);
    final bool inCollection = _collection.any((c) => c.scryfallId == card.id);

    return Card(
      color: Colors.black.withValues(alpha: 0.45),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.white10, width: 1)),
      child: InkWell(
        onTap: () => _navigateToDetail(cardName),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, width: 60, height: 84, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 84, color: Colors.grey.shade800))
                    : Container(width: 60, height: 84, color: Colors.grey.shade800, child: const Icon(Icons.image, color: Colors.white30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cardName, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(card.typeLine, style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
                          child: Text(card.setCode.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text("${card.cmc?.toInt() ?? 0} CMC", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        const SizedBox(width: 8),
                        _buildRarityBadge(card.rarity),
                        const Spacer(),
                        Text('$price €', style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildActionButton(icon: inWishlist ? Icons.star : Icons.star_border, color: inWishlist ? Colors.blue : Colors.white30, onTap: () => _toggleWishlist(card.id, cardName, inWishlist)),
                  _buildActionButton(icon: inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, color: inCollection ? Colors.green : Colors.white30, onTap: () => _toggleCollection(card.id, cardName, inCollection)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsGrid({Key? key}) {
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    if (_searchResults.isEmpty) {
      return Center(child: Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.white70)));
    }

    return GridView.builder(
      key: key,
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: _searchResults.length + 1, 
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
           bool showLoader = false;
           if (_fullLocalResults.isNotEmpty && _searchResults.length < _fullLocalResults.length) showLoader = true;
           if (_nextPageUrl != null) showLoader = true;
           return showLoader ? const Center(child: CircularProgressIndicator()) : const SizedBox();
        }
        final card = _searchResults[index];
        final String imageUrl = card.imageUrl.isNotEmpty ? card.imageUrl : (card.smallImageUrl ?? '');
        
        return GestureDetector(
          onTap: () => _navigateToDetail(card.name),
          child: Card(
            clipBehavior: Clip.antiAlias, color: Colors.black, elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white12, width: 1)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade900, child: Center(child: Text(card.name, textAlign: TextAlign.center, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 10)))),
                Positioned(bottom: 0, left: 0, right: 0, height: 40, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent])))),
                Positioned(
                  bottom: 4, left: 4, right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${card.prices['eur'] ?? '-'}€", style: TextStyle(color: Colors.yellow.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      _buildRarityBadge(card.rarity, small: true),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildRarityBadge(String rarity, {bool small = false}) {
    Color c;
    switch(rarity) {
      case 'common': c = Colors.white; break;
      case 'uncommon': c = Colors.blue.shade300; break;
      case 'rare': c = Colors.amber; break;
      case 'mythic': c = Colors.orange.shade800; break;
      default: c = Colors.grey;
    }
    return Container(
      width: small ? 8 : 12, height: small ? 8 : 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1)),
    );
  }

  void _navigateToDetail(String cardName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: cardName))).then((_) => _loadLocalData()); 
  }

  Future<void> _toggleWishlist(String id, String name, bool currentState) async {
    // 1. Mise à jour Optimiste (visuel immédiat)
    setState(() {
      if (currentState) {
        _wishlist.removeWhere((c) => c.scryfallId == id);
      } else {
        _wishlist.add(DeckCard(scryfallId: id, name: name, quantity: 1));
      }
    });

    // 2. Sauvegarde réelle (attendre la fin)
    if (currentState) {
      await _wishlistService.upsertCardInWishlist(scryfallId: id, cardName: name, absoluteQuantity: 0);
      _showFeedback('Retiré de la Wishlist', Colors.red.shade700);
    } else {
      await _wishlistService.upsertCardInWishlist(scryfallId: id, cardName: name, quantityToAdd: 1);
      _showFeedback('Ajouté à la Wishlist', Colors.blue.shade700);
    }
    
    // 3. Resynchro (optionnel si la logique optimiste est fiable, mais utile pour être sûr)
    await _loadLocalData(); 
  }

  Future<void> _toggleCollection(String id, String name, bool currentState) async {
    // 1. Mise à jour Optimiste
    setState(() {
      if (currentState) {
        _collection.removeWhere((c) => c.scryfallId == id);
      } else {
        _collection.add(DeckCard(scryfallId: id, name: name, quantity: 1));
      }
    });

    // 2. Sauvegarde réelle
    if (currentState) {
      await _collectionService.upsertCardInCollection(scryfallId: id, cardName: name, absoluteQuantity: 0);
      _showFeedback('Retiré de la collection', Colors.red.shade700);
    } else {
      await _collectionService.upsertCardInCollection(scryfallId: id, cardName: name, quantityToAdd: 1);
      _showFeedback('Ajouté à la collection', Colors.green.shade700);
    }
    
    // 3. Resynchro
    await _loadLocalData(); 
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, color: color, size: 22)),
    );
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      duration: const Duration(seconds: 1),
    ));
  }
}