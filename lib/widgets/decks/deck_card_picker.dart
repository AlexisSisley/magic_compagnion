// Fichier : lib/widgets/decks/deck_card_picker.dart
// NOUVEAU FICHIER

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/services/local_card_service.dart';
import 'package:magic_companion/widgets/search/search_filter_modal.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/collection_service.dart';

class DeckCardPicker extends StatefulWidget {
  const DeckCardPicker({super.key});

  @override
  State<DeckCardPicker> createState() => _DeckCardPickerState();
}

class _DeckCardPickerState extends State<DeckCardPicker> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Panier de sélection : ID Scryfall -> Quantité
  final Map<String, int> _selectedQuantities = {};
  // Cache pour renvoyer l'objet carte complet à la fin
  final Map<String, ScryfallCard> _cardCache = {};

  // Services
  final CollectionService _collectionService = CollectionService();
  final LocalCardService _localCardService = LocalCardService(); //

  // --- ONGLET 1 : RECHERCHE API ---
  final TextEditingController _searchController = TextEditingController();
  List<ScryfallCard> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  SearchFilters _apiFilters = SearchFilters(); //
  String _apiSort = 'name'; // 'name', 'cmc', 'type'

  // --- ONGLET 2 : COLLECTION ---
  List<DeckCard> _fullCollection = [];
  List<DeckCard> _filteredCollection = [];
  final TextEditingController _collectionSearchController = TextEditingController();
  SearchFilters _collectionFilters = SearchFilters();
  String _collectionSort = 'name'; // 'name', 'price', 'type'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCollection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _collectionSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // LOGIQUE COLLECTION (LOCALE)
  // ===========================================================================

  Future<void> _loadCollection() async {
    // On s'assure que le service local est prêt pour récupérer images/mana
    if (!_localCardService.isLoaded) {
      await _localCardService.loadLocalData();
    }
    
    final col = await _collectionService.loadCollection(); //
    if (mounted) {
      setState(() {
        _fullCollection = col;
        _applyCollectionFilters();
      });
    }
  }

  void _applyCollectionFilters() {
    final query = _collectionSearchController.text.toLowerCase();
    
    setState(() {
      _filteredCollection = _fullCollection.where((deckCard) {
        // 1. Filtre Nom
        if (query.isNotEmpty && !deckCard.name.toLowerCase().contains(query)) {
          return false;
        }

        // 2. Filtres Avancés (via LocalCardService)
        if (_collectionFilters.cardType != null || _collectionFilters.colors.isNotEmpty || _collectionFilters.setCode != null) {
           final scryfallCard = _localCardService.getCardById(deckCard.scryfallId);
           if (scryfallCard == null) return false; // Pas d'info = on exclut par sécurité si filtre actif

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
        }
        return true;
      }).toList();

      // 3. Tri
      _filteredCollection.sort((a, b) {
        final cardA = _localCardService.getCardById(a.scryfallId);
        final cardB = _localCardService.getCardById(b.scryfallId);

        switch (_collectionSort) {
          case 'price':
             double priceA = double.tryParse(cardA?.prices['eur'] ?? '0') ?? 0;
             double priceB = double.tryParse(cardB?.prices['eur'] ?? '0') ?? 0;
             return priceB.compareTo(priceA); // Décroissant
          case 'type':
             return (cardA?.typeLine ?? '').compareTo(cardB?.typeLine ?? '');
          case 'name':
          default:
             return a.name.compareTo(b.name);
        }
      });
    });
  }

  Future<void> _openCollectionFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(initialFilters: _collectionFilters), //
    );
    if (newFilters != null) {
      setState(() => _collectionFilters = newFilters);
      _applyCollectionFilters();
    }
  }

  // ===========================================================================
  // LOGIQUE RECHERCHE (API)
  // ===========================================================================

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // On lance la recherche si on a du texte OU des filtres
      if (query.trim().isNotEmpty || _apiFilters.cardType != null || _apiFilters.colors.isNotEmpty || _apiFilters.setCode != null) {
        _searchScryfall(query);
      }
    });
  }

  Future<void> _searchScryfall(String query) async {
    setState(() { _isSearching = true; });
    try {
      // Construction de la requête Scryfall
      List<String> parts = [];
      if (query.trim().isNotEmpty) parts.add(query.trim());
      if (_apiFilters.setCode != null) parts.add('e:${_apiFilters.setCode}');
      if (_apiFilters.cardType != null) parts.add('t:${_apiFilters.cardType}');
      if (_apiFilters.colors.isNotEmpty) parts.add('c:${_apiFilters.colors.join()}');
      
      String finalQuery = parts.join(' ');
      if (finalQuery.isEmpty) { 
        setState(() { _searchResults = []; _isSearching = false; });
        return; 
      }

      final uri = Uri.parse(
        'https://api.scryfall.com/cards/search?q=${Uri.encodeComponent(finalQuery)}&unique=cards&order=$_apiSort'
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> raw = data['data'] ?? [];
        setState(() {
          _searchResults = raw.map((json) => ScryfallCard.fromJson(json)).toList();
        });
      } else {
        setState(() => _searchResults = []);
      }
    } catch (e) {
       // Erreur silencieuse
    } finally {
      if (mounted) setState(() { _isSearching = false; });
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
  // GESTION DU PANIER
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
        // Barre de recherche + Filtres
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
                    isActive: _apiFilters.setCode != null || _apiFilters.colors.isNotEmpty || _apiFilters.cardType != null
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
                icon: Icon(Icons.filter_list, color: _apiFilters.setCode != null ? Colors.yellow : Colors.white70),
                onPressed: _openApiFilterModal,
              ),
            ],
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(color: Colors.yellow, minHeight: 2),
        
        Expanded(
          child: ListView.separated(
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final card = _searchResults[index];
              final qty = _selectedQuantities[card.id] ?? 0;
              return _buildRichCardTile(
                card: card,
                quantity: qty,
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
                    isActive: _collectionFilters.setCode != null || _collectionFilters.colors.isNotEmpty
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
                icon: Icon(Icons.filter_list, color: _collectionFilters.setCode != null ? Colors.yellow : Colors.white70),
                onPressed: _openCollectionFilterModal,
              ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView.separated(
            itemCount: _filteredCollection.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final deckCard = _filteredCollection[index];
              final qtySelected = _selectedQuantities[deckCard.scryfallId] ?? 0;
              
              // Récupération LOCAL de l'image et du mana via le service
              final scryfallCard = _localCardService.getCardById(deckCard.scryfallId) ?? 
                  // Fallback minimal si pas trouvé en local
                  ScryfallCard(id: deckCard.scryfallId, oracleId: '', name: deckCard.name, imageUrl: '', rulesText: '', typeLine: '', legalities: {}, prices: {}, lang: 'en', colorIdentity: [], setName: '', setCode: '', collectorNumber: '');

              return _buildRichCardTile(
                card: scryfallCard,
                quantity: qtySelected,
                ownedQuantity: deckCard.quantity, // Affiche combien on en a
                onAdd: () {
                   _increment(scryfallCard); // On utilise le ScryfallCard reconstitué/trouvé pour le cache
                },
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
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final imageUrl = card.smallImageUrl ?? card.imageUrl;
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      color: quantity > 0 ? Colors.yellow.shade900.withOpacity(0.2) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: hasImage 
            ? Image.network(imageUrl, width: 40, height: 56, fit: BoxFit.cover)
            : Container(width: 40, height: 56, color: Colors.grey.shade800, child: const Icon(Icons.image, size: 20)),
        ),
        title: Text(
          card.name,
          style: GoogleFonts.cinzel(color: quantity > 0 ? Colors.yellow :Colors.white, fontWeight: quantity > 0 ? FontWeight.bold : FontWeight.normal),
           overflow: TextOverflow.fade
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
                Text(
                  card.typeLine, 
                  style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 10), maxLines: 1, 
                  overflow: TextOverflow.ellipsis
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
    return Container(
      padding: const EdgeInsets.all(16),
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

// =============================================================================
// PETIT WIDGET LOCAL POUR AFFICHER LE MANA
// =============================================================================
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