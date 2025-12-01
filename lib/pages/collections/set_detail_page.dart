import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/scryfall_set_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';

class SetDetailPage extends StatefulWidget {
  final ScryfallSet set;
  final CollectionService collectionService;
  final WishlistService wishlistService;

  const SetDetailPage({
    super.key, 
    required this.set, 
    required this.collectionService,
    required this.wishlistService,
  });

  @override
  State<SetDetailPage> createState() => _SetDetailPageState();
}

class _SetDetailPageState extends State<SetDetailPage> {
  List<ScryfallCard> _cards = [];
  bool _isLoading = true;
  Set<String> _ownedIds = {}; // IDs des cartes qu'on a déjà
  
  // --- NOUVEAU : GESTION DE LA SÉLECTION ---
  Set<String> _selectedIds = {}; // IDs des cartes sélectionnées pour action
  
  // Stats Rareté
  Map<String, int> _rarityCounts = {
    'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0
  };

  @override
  void initState() {
    super.initState();
    _loadSetCards();
  }

  Future<void> _loadSetCards() async {
    // 1. Charger la collection actuelle pour savoir ce qu'on a
    final col = await widget.collectionService.loadCollection();
    _ownedIds = col.map((c) => c.scryfallId).toSet();

    // 2. Récupérer les cartes du set via Scryfall Search API
    try {
      // Note: L'API Search est paginée (175 max). Pour un gros set, il faudrait gérer la pagination.
      // Ici on simplifie en chargeant la première page, suffisant pour la plupart des sets récents.
      final uri = Uri.parse('https://api.scryfall.com/cards/search?q=e:${widget.set.code}&unique=prints&order=set');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> raw = data['data'] ?? [];
        
        List<ScryfallCard> loadedCards = raw.map((j) => ScryfallCard.fromJson(j)).toList();
        
        // Calcul des stats de rareté
        Map<String, int> counts = {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0};
        for (var c in loadedCards) {
          final r = c.rarity.toLowerCase();
          if (counts.containsKey(r)) counts[r] = (counts[r] ?? 0) + 1;
        }

        if (mounted) {
          setState(() {
            _cards = loadedCards;
            _rarityCounts = counts;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIQUE SÉLECTION ---

  void _toggleSelection(String cardId) {
    setState(() {
      if (_selectedIds.contains(cardId)) {
        _selectedIds.remove(cardId);
      } else {
        _selectedIds.add(cardId);
      }
    });
  }

  void _selectAllMissing() {
    final missing = _cards.where((c) => !_ownedIds.contains(c.id)).map((c) => c.id).toSet();
    setState(() {
      _selectedIds.addAll(missing);
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  // --- LOGIQUE ACTIONS DE MASSE ---

  Future<void> _addSelectedTo(bool toCollection) async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isLoading = true);
    int count = 0;

    // Récupérer les objets cartes complets basés sur les IDs sélectionnés
    final cardsToAdd = _cards.where((c) => _selectedIds.contains(c.id)).toList();

    for (var card in cardsToAdd) {
      if (toCollection) {
        await widget.collectionService.addCard(card, 1);
      } else {
        await widget.wishlistService.addCard(card, 1);
      }
      count++;
    }
    
    // Rafraichir les infos de possession
    if (toCollection) {
      final col = await widget.collectionService.loadCollection();
      _ownedIds = col.map((c) => c.scryfallId).toSet();
    }

    setState(() {
      _isLoading = false;
      _selectedIds.clear(); // On vide la sélection après ajout
    });

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$count cartes ajoutées à la ${toCollection ? 'Collection' : 'Wishlist'} !"),
        backgroundColor: Colors.green,
      ));
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final int missingCount = _cards.where((c) => !_ownedIds.contains(c.id)).length;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(widget.set.name, style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black,
        actions: [
          if (_selectedIds.isNotEmpty)
             IconButton(
               icon: const Icon(Icons.deselect),
               tooltip: "Tout désélectionner",
               onPressed: _clearSelection,
             )
          else if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: "Sélectionner les manquantes",
              onPressed: _selectAllMissing,
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Column(
            children: [
               // 1. BANDEAU STATS & RARETÉ
               _buildStatsHeader(missingCount),

               // 2. GRILLE DES CARTES
               Expanded(
                 child: GridView.builder(
                   padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100), // Espace pour le BottomBar
                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                     crossAxisCount: 3, 
                     childAspectRatio: 0.7, 
                     crossAxisSpacing: 8, 
                     mainAxisSpacing: 8
                   ),
                   itemCount: _cards.length,
                   itemBuilder: (context, index) => _buildCardTile(_cards[index]),
                 ),
               ),
            ],
          ),
      
      // 3. BARRE D'ACTION FLOTTANTE (Si sélection active)
      bottomNavigationBar: _selectedIds.isNotEmpty ? _buildBottomActionAmount() : null,
    );
  }

  Widget _buildStatsHeader(int missingCount) {
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Ligne Raretés
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRarityBadge('M', _rarityCounts['mythic'] ?? 0, Colors.orange.shade800),
              _buildRarityBadge('R', _rarityCounts['rare'] ?? 0, Colors.amber),
              _buildRarityBadge('U', _rarityCounts['uncommon'] ?? 0, Colors.blueGrey.shade300),
              _buildRarityBadge('C', _rarityCounts['common'] ?? 0, Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          // Ligne Manquantes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pie_chart_outline, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(
                "$missingCount manquantes / ${_cards.length} total", 
                style: const TextStyle(color: Colors.white70, fontSize: 12)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRarityBadge(String letter, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 20, height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1)
          ),
          child: Text(letter, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
        const SizedBox(width: 6),
        Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCardTile(ScryfallCard card) {
    final bool isOwned = _ownedIds.contains(card.id);
    final bool isSelected = _selectedIds.contains(card.id);

    return GestureDetector(
      onTap: () => _toggleSelection(card.id),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Carte
          Opacity(
            // Si sélectionné : Full Opacité
            // Si pas sélectionné : Grisé si pas possédé, Normal si possédé
            opacity: isSelected ? 1.0 : (isOwned ? 1.0 : 0.4),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                // Bordure : Verte si possédé, Jaune si Sélectionné
                side: isSelected 
                    ? BorderSide(color: Colors.yellow.shade700, width: 3)
                    : (isOwned ? BorderSide(color: Colors.green.shade800, width: 2) : BorderSide.none),
              ),
              child: Image.network(
                card.smallImageUrl ?? '', 
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(color: Colors.grey[800], child: const Icon(Icons.image_not_supported)),
              ),
            ),
          ),
          
          // Indicateur de sélection (Overlay)
          if (isSelected)
            Positioned(
              top: 4, right: 4,
              child: Container(
                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: Colors.yellow, size: 24),
              ),
            ),
            
           // Indicateur de possession (si pas sélectionné, pour info)
           if (isOwned && !isSelected)
             Positioned(
              top: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.inventory_2, color: Colors.green, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActionAmount() {
    return Container(
      color: Colors.yellow.shade900,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${_selectedIds.length} sélectionnée(s)",
              style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _addSelectedTo(false), // Wishlist
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                  icon: const Icon(Icons.star, size: 16),
                  label: const Text("Wishlist"),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _addSelectedTo(true), // Collection
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
                  icon: const Icon(Icons.inventory_2, size: 16),
                  label: const Text("Collection"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}