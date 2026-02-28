// Fichier : lib/pages/collections/wishlist_tab.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- Import ajouté
import '../../models/scryfall_card_model.dart';
import '../../models/wishlist_model.dart';
import '../../router/app_router.dart';
import '../../services/wishlist_service.dart';

class WishlistTab extends StatefulWidget {
  final List<Wishlist> wishlists;
  final List<ScryfallCard> fullCardData;
  final double totalValue;
  final WishlistService wishlistService;
  final Function() onRefresh;

  const WishlistTab({
    super.key,
    required this.wishlists,
    required this.fullCardData,
    required this.totalValue,
    required this.wishlistService,
    required this.onRefresh,
  });

  @override
  State<WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends State<WishlistTab> {
  
  // --- ACTIONS ---

  Future<void> _showCreateWishlistDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Nouvelle Wishlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller, 
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Nom (ex: Deck Commander)"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.wishlistService.createWishlist(controller.text);
                if (mounted) Navigator.pop(c);
                widget.onRefresh();
              }
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
            child: const Text("Créer")
          )
        ],
      )
    );
  }

  Future<void> _confirmDelete(Wishlist list) async {
    final del = await showDialog<bool>(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Supprimer la liste ?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Non")), 
          TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Oui", style: TextStyle(color: Colors.red)))
        ],
      )
    );
    
    if(del == true) {
      await widget.wishlistService.deleteWishlist(list.id);
      widget.onRefresh();
    }
  }

  // Helper pour lancer l'URL
  Future<void> _launchURL(String? url) async {
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le lien.")));
    }
  }

  // Menu contextuel pour le Top 10
  void _showTopCardOptions(ScryfallCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(card.setName, style: const TextStyle(color: Colors.white54)),
              ),
              const Divider(color: Colors.white24),
              
              if (card.purchaseUris['cardmarket'] != null)
                ListTile(
                  leading: const Icon(Icons.shopping_cart, color: Colors.blueAccent),
                  title: const Text("Voir sur Cardmarket", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _launchURL(card.purchaseUris['cardmarket']);
                  },
                ),
                
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white70),
                title: const Text("Détails complets", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.cardDetail, extra: {'cardName': card.name});
                },
              ),
            ],
          ),
        );
      }
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    // 1. Calcul des Top Cartes (Globales)
    final Map<String, ScryfallCard> uniqueCardsMap = {};
    
    for (var list in widget.wishlists) {
      for (var card in list.cards) {
        try {
          final sc = widget.fullCardData.firstWhere((s) => s.id == card.scryfallId);
          uniqueCardsMap[sc.id] = sc; 
        } catch(e) { /* */ }
      }
    }

    final List<ScryfallCard> sortedCards = uniqueCardsMap.values.toList();
    sortedCards.sort((a, b) {
      final pA = double.tryParse(a.prices['eur'] ?? '0') ?? 0.0;
      final pB = double.tryParse(b.prices['eur'] ?? '0') ?? 0.0;
      return pB.compareTo(pA);
    });

    final top10 = sortedCards.take(10).toList();

    return Column(
      children: [
        // --- HEADER FINANCIER GLOBAL ---
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade900.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Wishlists", style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text("${widget.totalValue.toStringAsFixed(2)} €", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 30),
                tooltip: "Créer une liste",
                onPressed: _showCreateWishlistDialog,
              )
            ],
          ),
        ),
        
        // --- WIDGET TOP CARTES (Horizontal) ---
        if (top10.isNotEmpty) ...[
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
             child: Row(
               children: [
                 const Icon(Icons.trending_up, color: Colors.yellow, size: 16),
                 const SizedBox(width: 8),
                 Text("Top Valeur (Toutes Listes)", style: GoogleFonts.cinzel(color: Colors.white70, fontWeight: FontWeight.bold)),
               ],
             ),
           ),
           SizedBox(
             height: 160,
             child: ListView.builder(
               scrollDirection: Axis.horizontal,
               padding: const EdgeInsets.symmetric(horizontal: 12),
               itemCount: top10.length,
               itemBuilder: (context, index) {
                 final card = top10[index];
                 final price = card.prices['eur'] ?? 'N/A';
                 return GestureDetector(
                   onTap: () {
                      context.push(AppRoutes.cardDetail, extra: {'cardName': card.name});
                   },
                   // NOUVEAU : Appui long pour le menu Cardmarket
                   onLongPress: () => _showTopCardOptions(card),
                   
                   child: Container(
                     width: 100,
                     margin: const EdgeInsets.only(right: 8),
                     child: Column(
                       children: [
                         Expanded(
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: Image.network(
                               card.smallImageUrl ?? card.imageUrl, 
                               fit: BoxFit.cover,
                               errorBuilder: (c,e,s) => Container(color: Colors.grey[800], child: const Icon(Icons.image)),
                             ),
                           ),
                         ),
                         const SizedBox(height: 4),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: Colors.black54,
                             borderRadius: BorderRadius.circular(4),
                             border: Border.all(color: Colors.yellow.shade800.withOpacity(0.5))
                           ),
                           child: Text("$price €", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                         ),
                       ],
                     ),
                   ),
                 );
               },
             ),
           ),
           const Divider(color: Colors.white10, height: 24),
        ],

        // --- LISTE DES WISHLISTS ---
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: Colors.yellow.shade800,
            backgroundColor: const Color(0xFF1A1A1A),
            child: widget.wishlists.isEmpty 
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: Center(child: Text("Aucune wishlist créée.", style: GoogleFonts.cinzel(color: Colors.white38))))]
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: widget.wishlists.length,
                  itemBuilder: (context, index) {
                    final list = widget.wishlists[index];
                    String? coverImageUrl;
                    
                    if (list.iconScryfallId != null) {
                      try {
                        final card = widget.fullCardData.firstWhere((s) => s.id == list.iconScryfallId);
                        coverImageUrl = card.smallImageUrl ?? card.imageUrl;
                      } catch(e) {}
                    }
                    if (coverImageUrl == null && list.cards.isNotEmpty) {
                      try {
                         final cId = list.cards.first.scryfallId;
                         final card = widget.fullCardData.firstWhere((s) => s.id == cId);
                         coverImageUrl = card.smallImageUrl;
                      } catch(e){}
                    }

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: Colors.blue.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                          child: coverImageUrl != null 
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(coverImageUrl, fit: BoxFit.cover))
                            : const Icon(Icons.bookmark, color: Colors.blueAccent),
                        ),
                        title: Text(list.name, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${list.totalCards} cartes", style: const TextStyle(color: Colors.white54)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                        onTap: () async {
                          await context.push(AppRoutes.wishlistDetail, extra: list);
                          widget.onRefresh();
                        },
                        onLongPress: () => _confirmDelete(list),
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }
}