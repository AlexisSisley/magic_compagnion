// Fichier : lib/widgets/collection/collection_sets_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_set_model.dart';
import '../../services/set_service.dart';
import '../../services/local_card_service.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../pages/collections/set_detail_page.dart';

class CollectionSetsTab extends StatefulWidget {
  final List<DeckCard> collection;
  final Future<void> Function()? onRefresh; 

  const CollectionSetsTab({
    super.key, 
    required this.collection,
    this.onRefresh, 
  });

  @override
  State<CollectionSetsTab> createState() => _CollectionSetsTabState();
}

class _CollectionSetsTabState extends State<CollectionSetsTab> {
  final SetService _setService = SetService();
  final LocalCardService _localCardService = LocalCardService();
  final WishlistService _wishlistService = WishlistService(); // Service Wishlist
  
  List<ScryfallSet> _sets = [];
  Map<String, int> _ownedCounts = {};
  Map<String, int> _wishlistCounts = {}; // Compteur Wishlist par set
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CollectionSetsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.length != widget.collection.length) {
      _calculate();
    }
  }

  Future<void> _load() async {
    if (!_localCardService.isLoaded) {
      await _localCardService.loadLocalData();
    }

    final sets = await _setService.getAllSets();
    final validSets = sets.where((s) => s.cardCount > 0).toList();
    validSets.sort((a, b) => (b.releaseDate ?? DateTime(1900)).compareTo(a.releaseDate ?? DateTime(1900)));
    
    if (mounted) {
      setState(() { _sets = validSets; _isLoading = false; });
      _calculate();
    }
  }

  Future<void> _calculate() async {
    // 1. Calcul des cartes possédées (Synchrone car venant du widget parent)
    Map<String, int> owned = {};
    for (var card in widget.collection) {
      final local = _localCardService.getCardById(card.scryfallId);
      if (local != null) {
        owned[local.setCode] = (owned[local.setCode] ?? 0) + 1;
      }
    }

    // 2. Calcul des cartes en Wishlist (Asynchrone)
    Map<String, int> wished = {};
    final wishlists = await _wishlistService.loadWishlists();
    
    // On parcourt toutes les cartes de toutes les wishlists
    // (On utilise un Set d'IDs par set pour ne pas compter les doublons si une carte est dans 2 wishlists différentes)
    for (var list in wishlists) {
      for (var card in list.cards) {
        final local = _localCardService.getCardById(card.scryfallId);
        if (local != null) {
          // On incrémente le compteur pour ce set
          wished[local.setCode] = (wished[local.setCode] ?? 0) + 1;
        }
      }
    }

    if (mounted) {
      setState(() {
        _ownedCounts = owned;
        _wishlistCounts = wished;
      });
    }
  }

  Future<void> _handleRefresh() async {
    final setsFuture = _load();
    final parentFuture = widget.onRefresh?.call() ?? Future.value();
    await Future.wait([setsFuture, parentFuture]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.yellow.shade800,
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(), 
        itemCount: _sets.length,
        padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 80),
        itemBuilder: (context, index) {
          final set = _sets[index];
          
          final int owned = _ownedCounts[set.code] ?? 0;
          final int wished = _wishlistCounts[set.code] ?? 0;
          final int total = set.cardCount > 0 ? set.cardCount : 1; // Évite division par 0

          return Card(
            color: Colors.white.withOpacity(0.05),
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SetDetailPage(
                    set: set, 
                    collectionService: CollectionService(), 
                    wishlistService: WishlistService()
                  )
                ));
              },
              child: Column(
                children: [
                  ListTile(
                    leading: SizedBox(width: 40, child: SvgPicture.network(set.iconSvgUri ?? '', colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                    title: Text(set.name, style: GoogleFonts.cinzel(color: Colors.white)),
                    // Sous-titre avec détail : Possédés + Wishlist / Total
                    subtitle: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        children: [
                          TextSpan(text: "$owned", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                          const TextSpan(text: " + "),
                          TextSpan(text: "$wished", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          TextSpan(text: " / $total cartes"),
                        ]
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  ),
                  
                  // --- BARRE DE PROGRESSION DUO (Orange + Bleu) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildMultiProgressBar(total, owned, wished),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMultiProgressBar(int total, int owned, int wished) {
    // Calcul des proportions pour les Flex
    // On s'assure que owned + wished ne dépasse pas total (visuellement)
    int displayOwned = owned;
    int displayWished = wished;
    
    if (displayOwned > total) {
      displayOwned = total;
      displayWished = 0;
    } else if (displayOwned + displayWished > total) {
      displayWished = total - displayOwned;
    }
    
    int empty = total - displayOwned - displayWished;
    if (empty < 0) empty = 0;

    // Si total est 0 (bug API ou autre), on affiche une barre vide
    if (total == 0) return const SizedBox(height: 4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 4,
        color: Colors.white10, // Couleur de fond (partie vide)
        child: Row(
          children: [
            // Partie 1 : Cartes Possédées (Orange)
            if (displayOwned > 0)
              Expanded(
                flex: displayOwned,
                child: Container(color: Colors.orangeAccent),
              ),
            
            // Partie 2 : Cartes Wishlist (Bleu) - À la suite
            if (displayWished > 0)
              Expanded(
                flex: displayWished,
                child: Container(color: Colors.blueAccent),
              ),
            
            // Partie 3 : Vide (Remplissage)
            if (empty > 0)
              Expanded(
                flex: empty,
                child: Container(color: Colors.transparent),
              ),
          ],
        ),
      ),
    );
  }
}