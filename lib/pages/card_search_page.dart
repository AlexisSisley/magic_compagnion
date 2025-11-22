// Fichier : lib/pages/card_search_page.dart

import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  
  // --- ÉTAT DE RECHERCHE ---
  List<ScryfallCard> _fullLocalResults = []; 
  List<ScryfallCard> _searchResults = [];    
  static const int _localPageSize = 30;      
  
  String? _nextPageUrl; 
  bool _isApiLoadingMore = false; 
  
  SearchFilters _activeFilters = SearchFilters();
  bool _isLoading = false;
  String _statusMessage = 'Entrez un nom ou choisissez une édition.';
  
  bool _isGridView = false; 
  Timer? _debounce; 

  // --- TRI (NOUVEAU) ---
  String _sortBy = 'name'; // 'name', 'cmc', 'type'

  final CollectionService _collectionService = CollectionService();
  final WishlistService _wishlistService = WishlistService();
  List<DeckCard> _collection = [];
  List<DeckCard> _wishlist = [];
  
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

        // Si tri par Type (non supporté par API), on trie chaque page reçue (imparfait mais mieux que rien)
        if (_sortBy == 'type') {
           newCards.sort((a, b) => a.typeLine.compareTo(b.typeLine));
        }

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
      debugPrint("Erreur pagination API: $e");
    }
  }

  Future<void> _loadLocalData() async {
    final collection = await _collectionService.loadCollection();
    final wishlist = await _wishlistService.loadWishlist();
    if (mounted) {
      setState(() {
        _collection = collection;
        _wishlist = wishlist;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty || _activeFilters.setCode != null) {
        _searchCards();
      }
    });
  }

  // --- LOGIQUE DE TRI ---
  void _applySort(List<ScryfallCard> list) {
    switch (_sortBy) {
      case 'cmc':
        list.sort((a, b) => (a.cmc ?? 0).compareTo(b.cmc ?? 0));
        break;
      case 'type':
        list.sort((a, b) => a.typeLine.compareTo(b.typeLine));
        break;
      case 'name':
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }

  Future<void> _searchCards() async {
    if (_tabController.index != 0) _tabController.animateTo(0);

    final String query = _searchController.text.trim();
    
    if (query.isEmpty && _activeFilters.setCode == null && _activeFilters.cardType == null && _activeFilters.colors.isEmpty) {
      if (mounted) setState(() { _searchResults = []; _fullLocalResults = []; _nextPageUrl = null; _statusMessage = "Veuillez entrer un critère."; });
      return;
    }

    setState(() { 
      _isLoading = true; 
      _searchResults = []; 
      _fullLocalResults = [];
      _nextPageUrl = null; 
      _statusMessage = 'Recherche...'; 
    });

    // 1. Recherche Locale
    if (_localCardService.isLoaded) {
      await Future.delayed(const Duration(milliseconds: 50));
      final results = _localCardService.searchCards(
        query: query,
        setCode: _activeFilters.setCode,
        cardType: _activeFilters.cardType,
        colors: _activeFilters.colors,
      );
      
      if (results.isNotEmpty) {
        // Appliquer le tri sur TOUT le résultat local
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
        return;
      }
    }

    // 2. Fallback API
    await _searchCardsApi(query);
  }

  Future<void> _searchCardsApi(String query) async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) { 
      if (mounted) setState(() { _isLoading = false; _statusMessage = "Pas de connexion internet."; });
      return;
    }

    List<String> queryParts = [];
    if (query.isNotEmpty) queryParts.add(query);
    if (_activeFilters.setCode != null) queryParts.add('e:${_activeFilters.setCode}');
    if (_activeFilters.colors.isNotEmpty) queryParts.add('c:${_activeFilters.colors.join()}');
    if (_activeFilters.cardType != null) queryParts.add('t:${_activeFilters.cardType}');
    
    final String finalQuery = queryParts.join(' ');
    final prefs = await SharedPreferences.getInstance();
    final String lang = prefs.getString('glossaryLang') ?? 'fr';

    try {
      String uniqueParam = _activeFilters.setCode != null ? '&unique=prints' : '&unique=cards';
      
      // --- GESTION TRI API ---
      // Scryfall supporte 'name', 'cmc'. 'type' n'est pas supporté directement par order=
      String sortParam = '&order=name';
      if (_sortBy == 'cmc') sortParam = '&order=cmc';
      // Pour 'type', on reste sur 'name' par défaut côté API et on triera la page reçue
      
      final encodedQuery = Uri.encodeComponent(finalQuery);
      
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/search?q=$encodedQuery&lang=$lang$uniqueParam$sortParam'));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        if (data.containsKey('has_more') && data['has_more'] == true) {
           _nextPageUrl = data['next_page'];
        }

        final List<dynamic> rawList = data['data'] ?? [];
        List<ScryfallCard> apiResults = rawList.map((json) => ScryfallCard.fromJson(json)).toList();

        // Tri manuel pour le type (puisque l'API ne le fait pas)
        if (_sortBy == 'type') {
           apiResults.sort((a, b) => a.typeLine.compareTo(b.typeLine));
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _searchResults = apiResults;
            if (_searchResults.isEmpty) { _statusMessage = 'Aucune carte trouvée (API).'; }
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _statusMessage = 'Erreur API (${response.statusCode}).'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _statusMessage = 'Erreur réseau: $e'; });
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
          color: Colors.black.withOpacity(0.5),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Plus compact
                      color: Colors.black26,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Info compte
                          Text(
                            _fullLocalResults.isNotEmpty 
                                ? "${_searchResults.length}/${_fullLocalResults.length}"
                                : "${_searchResults.length} cartes",
                            style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
                          ),
                          
                          // Zone Droite : Tri + Vue
                          Row(
                            children: [
                              // --- MENU DE TRI ---
                              PopupMenuButton<String>(
                                icon: Icon(Icons.sort, color: Colors.yellow.shade700, size: 20),
                                color: const Color(0xFF1A1A1A),
                                tooltip: "Trier par...",
                                onSelected: (val) {
                                  if (_sortBy != val) {
                                    setState(() => _sortBy = val);
                                    _searchCards(); // Relancer pour appliquer le tri API ou Local
                                  }
                                },
                                itemBuilder: (context) => [
                                  _buildSortMenuItem('name', 'Nom'),
                                  _buildSortMenuItem('cmc', 'Mana (CMC)'),
                                  _buildSortMenuItem('type', 'Type'),
                                ],
                              ),
                              
                              const SizedBox(width: 8),
                              
                              // Toggle Vue
                              InkWell(
                                onTap: () => setState(() => _isGridView = !_isGridView),
                                child: Icon(
                                  _isGridView ? Icons.grid_view : Icons.view_list,
                                  color: Colors.white70,
                                  size: 20,
                                ),
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
          Text(label, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: _activeFilters.setCode != null 
              ? 'Dans: ${_activeFilters.setCode!.toUpperCase()}...' 
              : 'Nom de la carte...',
          hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14),
          prefixIcon: IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _activeFilters.colors.isNotEmpty || _activeFilters.cardType != null || _activeFilters.setCode != null
                  ? Colors.yellow.shade700 : Colors.white70,
            ),
            onPressed: _openFilterModal,
            tooltip: "Filtres avancés",
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (_activeFilters.setCode != null)
                IconButton(
                  icon: const Icon(Icons.highlight_off, color: Colors.red),
                  tooltip: "Quitter l'édition",
                  onPressed: () {
                    setState(() {
                      _activeFilters = _activeFilters.copyWith(setCode: null);
                      _searchController.clear();
                      _searchResults = [];
                      _fullLocalResults = [];
                      _nextPageUrl = null;
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

              if (_localCardService.isLoaded)
                 const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.offline_pin, color: Colors.green, size: 16)),
              
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white70),
                onPressed: _searchCards,
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.black.withAlpha(140),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onSubmitted: (_) => _searchCards(),
      ),
    );
  }

  // ===========================================================================
  // LISTE & GRILLE (Inchangés mais inclus pour contexte)
  // ===========================================================================
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
        if (index >= _searchResults.length) return const SizedBox();
        return _buildListTile(_searchResults[index]);
      },
    );
  }

  Widget _buildListTile(ScryfallCard card) {
    final String cardName = card.name;
    final String cardType = card.typeLine;
    final String scryfallId = card.id;
    final String? imageUrl = card.smallImageUrl ?? card.imageUrl;
    final String price = card.prices['eur'] ?? '--';
    final String setCode = card.setCode.toUpperCase();
    final bool inWishlist = _wishlist.any((c) => c.scryfallId == scryfallId);
    final bool inCollection = _collection.any((c) => c.scryfallId == scryfallId);

    return Card(
      color: Colors.black.withOpacity(0.45),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.white10, width: 1)),
      child: InkWell(
        onTap: () => _navigateToDetail(cardName),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, width: 70, height: 98, fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(width: 70, height: 98, color: Colors.grey.shade800))
                    : Container(width: 70, height: 98, color: Colors.grey.shade800, child: const Icon(Icons.image, color: Colors.white30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(cardName, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        if (card.manaCost != null) Padding(padding: const EdgeInsets.only(left: 4.0), child: _buildManaCost(card.manaCost!)),
                      ],
                    ),
                    Text(cardType, style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
                          child: Text(setCode, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        Text('$price €', style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildActionButton(
                          icon: inWishlist ? Icons.star : Icons.star_border,
                          color: inWishlist ? Colors.blue.shade400 : Colors.white38,
                          onTap: () => _toggleWishlist(scryfallId, cardName, inWishlist),
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(
                          icon: inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined,
                          color: inCollection ? Colors.green.shade400 : Colors.white38,
                          onTap: () => _toggleCollection(scryfallId, cardName, inCollection),
                        ),
                      ],
                    )
                  ],
                ),
              ),
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
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _searchResults.length + 1, 
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
           bool showLoader = false;
           if (_fullLocalResults.isNotEmpty && _searchResults.length < _fullLocalResults.length) showLoader = true;
           if (_nextPageUrl != null) showLoader = true;
           return showLoader ? const Center(child: CircularProgressIndicator()) : const SizedBox();
        }
        if (index >= _searchResults.length) return const SizedBox();
        return _buildGridTile(_searchResults[index]);
      },
    );
  }

  Widget _buildGridTile(ScryfallCard card) {
    final String imageUrl = card.imageUrl.isNotEmpty ? card.imageUrl : (card.smallImageUrl ?? '');
    final bool inWishlist = _wishlist.any((c) => c.scryfallId == card.id);
    final bool inCollection = _collection.any((c) => c.scryfallId == card.id);

    return GestureDetector(
      onTap: () => _navigateToDetail(card.name),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white12, width: 1)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey.shade900, child: const Icon(Icons.broken_image, color: Colors.white24)))
                : Container(color: Colors.grey.shade900, child: Center(child: Text(card.name, textAlign: TextAlign.center, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 10)))),
            Positioned(
              bottom: 0, left: 0, right: 0, height: 60,
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]))),
            ),
            if (card.prices['eur'] != null)
              Positioned(
                top: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                  child: Text("${card.prices['eur']} €", style: TextStyle(color: Colors.yellow.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    Row(
                      children: [
                        InkWell(onTap: () => _toggleWishlist(card.id, card.name, inWishlist), child: Icon(inWishlist ? Icons.star : Icons.star_border, size: 18, color: inWishlist ? Colors.blue.shade400 : Colors.white70)),
                        const SizedBox(width: 8),
                        InkWell(onTap: () => _toggleCollection(card.id, card.name, inCollection), child: Icon(inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, size: 18, color: inCollection ? Colors.green.shade400 : Colors.white70)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(String cardName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: cardName))).then((_) => _loadLocalData()); 
  }

  void _toggleWishlist(String id, String name, bool currentState) {
    if (currentState) {
      _wishlistService.upsertCardInWishlist(scryfallId: id, cardName: name, absoluteQuantity: 0);
      _showFeedback('Retiré de la Wishlist', Colors.red.shade700);
    } else {
      _wishlistService.upsertCardInWishlist(scryfallId: id, cardName: name, quantityToAdd: 1);
      _showFeedback('Ajouté à la Wishlist', Colors.blue.shade700);
    }
    _loadLocalData(); 
  }

  void _toggleCollection(String id, String name, bool currentState) {
    if (currentState) {
      _collectionService.upsertCardInCollection(scryfallId: id, cardName: name, absoluteQuantity: 0);
      _showFeedback('Retiré de la collection', Colors.red.shade700);
    } else {
      _collectionService.upsertCardInCollection(scryfallId: id, cardName: name, quantityToAdd: 1);
      _showFeedback('Ajouté à la collection', Colors.green.shade700);
    }
    _loadLocalData();
  }

  Widget _buildManaCost(String manaCost) {
    final matches = _manaRegex.allMatches(manaCost);
    if (matches.isEmpty) return const SizedBox();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: matches.map((m) {
        final symbol = m.group(1)?.replaceAll('/', '') ?? ''; 
        final normalizedSymbol = symbol.toUpperCase();
        final url = 'https://svgs.scryfall.io/card-symbols/$normalizedSymbol.svg';
        return Padding(
          padding: const EdgeInsets.only(left: 1.0),
          child: SvgPicture.network(
            url, width: 14, height: 14,
            placeholderBuilder: (_) => Text("{$symbol}", style: const TextStyle(fontSize: 10, color: Colors.white)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(icon, color: color, size: 24)),
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