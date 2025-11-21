// Fichier : lib/pages/collection_page.dart
// VERSION MISE À JOUR (Avec Estimation Financière + Évolution)

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/pages/card_detail_page.dart';
import 'package:magic_companion/widgets/search/search_filter_modal.dart';
import 'dart:convert';

import '../models/deck_model.dart'; 
import '../services/collection_service.dart';
import '../services/wishlist_service.dart'; 

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> with TickerProviderStateMixin {
  final CollectionService _collectionService = CollectionService();
  final WishlistService _wishlistService = WishlistService();
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController(); 
  SearchFilters _activeFilters = SearchFilters(); 
  
  List<DeckCard> _collection = [];
  List<DeckCard> _wishlist = [];
  List<ScryfallCard> _fullCardData = [];
  bool _isLoading = true;

  // --- Données Financières ---
  double _totalCollectionValue = 0.0;
  double? _evolutionValue;
  double? _evolutionPercent;
  bool _hasCalculatedFinance = false;

  final RegExp _manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });

    await Future.wait([
      _collectionService.loadCollection().then((data) => _collection = data),
      _wishlistService.loadWishlist().then((data) => _wishlist = data),
    ]);
    
    if (!mounted) return;
    await _loadFullCardData(); // Charge les prix Scryfall
    
    // Une fois les prix chargés, on calcule le total et l'évolution
    await _calculateFinancials();

    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadFullCardData() async {
    final allCards = [..._collection, ..._wishlist];
    // Filtre les cartes uniques
    final uniqueCardIdentifiers = allCards
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:'))
        .map((card) => {"id": card.scryfallId})
        .toSet()
        .toList();

    if (uniqueCardIdentifiers.isEmpty) {
      _fullCardData = [];
      return;
    }
    
    // NOTE : L'API collection de Scryfall est limitée à 75 cartes par appel.
    // Pour une vraie prod, il faut faire des chunks. Ici on limite pour l'exemple.
    if (uniqueCardIdentifiers.length > 75) {
      uniqueCardIdentifiers.length = 75; 
    }

    final requestBody = json.encode({'identifiers': uniqueCardIdentifiers});

    try {
      final response = await http.post(
        Uri.parse('https://api.scryfall.com/cards/collection'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        _fullCardData = (data['data'] as List)
            .map((cardJson) => ScryfallCard.fromJson(cardJson))
            .toList();
      }
    } catch (e) {
      log('Erreur chargement Scryfall: $e');
    }
  }

  // --- NOUVEAU : Calculs Financiers ---
  Future<void> _calculateFinancials() async {
    double tempTotal = 0.0;

    for (var deckCard in _collection) {
       // Ignore cartes locales
       if (deckCard.scryfallId.startsWith('LOCAL:')) continue;

       try {
         final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
         final double unitPrice = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
         tempTotal += (unitPrice * deckCard.quantity);
       } catch (e) {
         // Carte pas encore chargée ou pas de prix
       }
    }

    _totalCollectionValue = tempTotal;
    
    // 1. Enregistrer le snapshot d'aujourd'hui
    await _collectionService.recordDailyValue(_totalCollectionValue);

    // 2. Récupérer l'évolution sur 7 jours
    final evo = await _collectionService.getEvolutionSince(7);
    
    if (mounted) {
      setState(() {
        _evolutionValue = evo?['diffValue'];
        _evolutionPercent = evo?['diffPercentage'];
        _hasCalculatedFinance = true;
      });
    }
  }

  Future<void> _updateLocalQuantity(List<DeckCard> list, DeckCard card, int change, Function serviceUpdate) async {
    setState(() {
      card.quantity += change;
      if (card.quantity <= 0) {
        list.remove(card);
      }
    });
    // Recalcule la finance si on touche à la collection
    if (list == _collection) {
      // On lance le recalcul en fond sans bloquer l'UI
      // Note: idéalement il faudrait recharger Scryfall si c'est une nouvelle carte, 
      // mais ici on suppose que les données sont là.
      _calculateFinancials(); 
    }
    serviceUpdate();
  }

  List<DeckCard> _filterList(List<DeckCard> list) {
    final query = _searchController.text.toLowerCase();
    
    return list.where((card) {
      final matchesName = card.name.toLowerCase().contains(query);
      if (!matchesName) return false;

      if (_activeFilters.cardType != null || _activeFilters.colors.isNotEmpty) {
        try {
          final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
          
          if (_activeFilters.cardType != null) {
            if (!scryfallCard.typeLine.toLowerCase().contains(_activeFilters.cardType!.toLowerCase())) {
              return false;
            }
          }
          if (_activeFilters.colors.isNotEmpty) {
             final cardColors = scryfallCard.colorIdentity.toSet();
             if (!_activeFilters.colors.every((c) => cardColors.contains(c))) {
               return false;
             }
          }
        } catch (e) {
          return false; 
        }
      }
      return true;
    }).toList();
  }
  
  Future<void> _openFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(initialFilters: _activeFilters),
    );
    if (newFilters != null) { setState(() => _activeFilters = newFilters); }
  }  

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- En-tête ---
        Container(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
          color: Colors.black.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ma Collection', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              TextField(
                controller: _searchController,
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher une carte...',
                  hintStyle: GoogleFonts.cinzel(color: Colors.white54),
                  prefixIcon: IconButton(
                    icon: Icon(Icons.filter_list, 
                      color: (_activeFilters.cardType != null || _activeFilters.colors.isNotEmpty) 
                          ? Colors.yellow.shade700 : Colors.white70),
                    onPressed: _openFilterModal,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () => _searchController.clear())
                      : const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                onChanged: (val) => setState(() {}),
              ),
              
              TabBar(
                controller: _tabController,
                labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.cinzel(),
                indicatorColor: Colors.yellow.shade800,
                tabs: [
                  Tab(text: 'Collection (${_collection.fold(0, (sum, c) => sum + c.quantity)})'),
                  Tab(text: 'Wishlist (${_wishlist.fold(0, (sum, c) => sum + c.quantity)})'),
                ],
              ),
            ],
          ),
        ),

        // --- Contenu ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // ONGLET COLLECTION : Avec en-tête financier
                    Column(
                      children: [
                        if (_hasCalculatedFinance) _buildFinancialHeader(),
                        Expanded(
                          child: _buildGroupedCardListView(
                            listSource: _collection,
                            isWishlist: false,
                            emptyMessage: "Votre collection est vide."
                          ),
                        ),
                      ],
                    ),
                    // ONGLET WISHLIST
                    _buildGroupedCardListView(
                      listSource: _wishlist,
                      isWishlist: true,
                      emptyMessage: "Votre wishlist est vide."
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // --- WIDGET : En-tête Financier (Nouveau) ---
  Widget _buildFinancialHeader() {
    final isPositive = (_evolutionValue ?? 0) >= 0;
    final color = isPositive ? Colors.green.shade400 : Colors.red.shade400;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final sign = isPositive ? '+' : '';

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.yellow.shade900.withOpacity(0.3), Colors.black.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade800.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bloc Valeur Totale
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimation Totale', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '${_totalCollectionValue.toStringAsFixed(2)} €',
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Bloc Evolution
          if (_evolutionValue != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Sur 7 jours', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$sign${_evolutionValue!.toStringAsFixed(2)} €',
                    style: GoogleFonts.cinzel(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '($sign${_evolutionPercent!.toStringAsFixed(1)}%)',
                style: GoogleFonts.cinzel(color: color.withOpacity(0.8), fontSize: 12),
              ),
            ],
          )
          else
             Text('Données insuffisantes\npour l\'évolution', style: GoogleFonts.cinzel(color: Colors.white38, fontSize: 10), textAlign: TextAlign.right),

          // Bouton Détails
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            tooltip: 'Détail Financier',
            onPressed: _showFinancialDetail,
          ),
        ],
      ),
    );
  }

  // --- MODALE : Détail Financier (Top cartes) ---
  void _showFinancialDetail() {
    // On prépare les données pour le Top 10
    List<Map<String, dynamic>> topCards = [];
    
    for (final deckCard in _collection) {
       if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
       try {
         final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
         final double unitPrice = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
         if (unitPrice > 0) {
           topCards.add({
             'name': scryfallCard.name,
             'unitPrice': unitPrice,
             'quantity': deckCard.quantity,
             'totalPrice': unitPrice * deckCard.quantity,
             'image': scryfallCard.smallImageUrl
           });
         }
       } catch (e) { /* ... */ }
    }

    // Trier par prix total (Quantité * Prix Unitaire) ou unitaire selon préférence
    topCards.sort((a, b) => (b['totalPrice'] as double).compareTo(a['totalPrice'] as double));
    final top10 = topCards.take(15).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Top Valorisation', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Les cartes les plus précieuses de votre collection', style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: top10.length,
                      separatorBuilder: (ctx, i) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        final item = top10[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: item['image'] != null 
                                ? Image.network(item['image'], width: 40, height: 56, fit: BoxFit.cover)
                                : Container(width: 40, height: 56, color: Colors.grey.shade800),
                          ),
                          title: Text(item['name'], style: GoogleFonts.cinzel(color: Colors.white), overflow: TextOverflow.ellipsis),
                          subtitle: Text('${item['quantity']}x  @ ${item['unitPrice']} €', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Text(
                            '${(item['totalPrice'] as double).toStringAsFixed(2)} €',
                            style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ... (Les méthodes _buildGroupedList, _getPrimaryType, _buildGroupedCardListView, etc. restent IDENTIQUES au code précédent) ...

  List<_GroupedCardList> _buildGroupedList(List<DeckCard> cardList) {
    Map<String, List<DeckCard>> groupedMap = {
      'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 
      'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [],
    };
    for (final deckCard in cardList) {
      ScryfallCard? scryfallCard;
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) throw Exception("Carte locale");
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) {
        scryfallCard = ScryfallCard.fromJson({
            'id': deckCard.scryfallId, 'name': deckCard.name, 
            'legalities': {}, 'prices': {}, 'lang': 'fr', 
            'type_line': deckCard.name, 'color_identity': [], 'mana_cost': '', 'cmc': 0.0
        });
      }
      final type = _getPrimaryType(scryfallCard.typeLine);
      groupedMap[type]?.add(deckCard);
    }
    List<_GroupedCardList> groupedList = [];
    groupedMap.forEach((title, cards) {
      if (cards.isNotEmpty) {
        cards.sort((a, b) => a.name.compareTo(b.name));
        groupedList.add(_GroupedCardList(title: title, cards: cards));
      }
    });
    return groupedList;
  }
  
  String _getPrimaryType(String typeLine) {
    String lowerType = typeLine.toLowerCase();
    if (!lowerType.contains(' — ') && (lowerType.contains('swamp') || lowerType.contains('plains') || lowerType.contains('island') || lowerType.contains('mountain') || lowerType.contains('forest'))) {
      return 'Terrains';
    }
    if (lowerType.contains('creature')) return 'Créatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('land')) return 'Terrains';
    if (lowerType.contains('artifact')) return 'Artefacts';
    if (lowerType.contains('enchantment')) return 'Enchantements';
    if (lowerType.contains('instant')) return 'Sorts';
    if (lowerType.contains('sorcery')) return 'Sorts';
    if (typeLine.startsWith('LOCAL:')) return 'Autres';
    return 'Autres';
  }  

  Widget _buildGroupedCardListView({
    required List<DeckCard> listSource,
    required bool isWishlist,
    required String emptyMessage,
  }) {
    // Applique les filtres
    final filteredList = _filterList(listSource);

    if (filteredList.isEmpty) {
      return Center(child: Text(emptyMessage, style: GoogleFonts.cinzel(color: Colors.white70)));
    }

    final groupedList = _buildGroupedList(filteredList);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24.0, top: 8.0, left: 4.0, right: 4.0),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final group = groupedList[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Text('${group.title} (${group.cards.fold(0, (sum, c) => sum + c.quantity)})', 
                  style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...group.cards.map((card) {
              // Récupération des données Scryfall
              ScryfallCard? scryfallCard;
              try {
                 scryfallCard = _fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
              } catch (e) { /* fallback */ }

              final imageUrl = scryfallCard?.smallImageUrl;
              final price = scryfallCard?.prices['eur']; // Récupération du prix

              return Card(
                color: Colors.black.withOpacity(0.4),
                margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  onTap: () {
                    if (scryfallCard != null && !scryfallCard.id.startsWith('LOCAL:')) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: scryfallCard!.name)));
                    }
                  },
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageUrl != null 
                      ? Image.network(imageUrl, width: 40, height: 56, fit: BoxFit.cover)
                      : Container(width: 40, height: 56, color: Colors.grey.shade800, child: const Icon(Icons.image_not_supported, size: 20)),
                  ),
                  title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
                  
                  // Modif Subtitle pour inclure le prix unitaire
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildManaCostRow(scryfallCard?.manaCost),
                       if (price != null)
                         Text('$price €', style: TextStyle(color: Colors.yellow.shade700, fontSize: 12)),
                    ],
                  ),
                  
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                        onPressed: () => _updateLocalQuantity(
                          listSource, card, -1, 
                          () => isWishlist 
                              ? _wishlistService.upsertCardInWishlist(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: -1)
                              : _collectionService.upsertCardInCollection(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: -1)
                        ),
                      ),
                      Text('${card.quantity}', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                        onPressed: () => _updateLocalQuantity(
                          listSource, card, 1,
                          () => isWishlist 
                              ? _wishlistService.upsertCardInWishlist(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: 1)
                              : _collectionService.upsertCardInCollection(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: 1)
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) { return const SizedBox.shrink(); }
    final List<String> symbols = _manaPipRegex.allMatches(manaCost).map((match) => match.group(0)!).toList();
    return Container(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: symbols.map((symbol) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.0),
                  child: _getManaIcon(symbol),
                )).toList(),
      ),
    );
  }
  Widget _getManaIcon(String symbol) {
    final String cleanSymbol = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    final String svgUrl = 'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg';
    return SvgPicture.network(
      svgUrl, height: 14, width: 14, // Un peu plus petit
      placeholderBuilder: (context) => Text(symbol, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14)),
    );
  }
}

class _GroupedCardList {
  final String title;
  final List<DeckCard> cards;
  _GroupedCardList({required this.title, required this.cards});
}