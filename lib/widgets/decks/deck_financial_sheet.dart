// Fichier : lib/widgets/decks/deck_financial_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';

class DeckFinancialSheet extends StatelessWidget {
  final Deck deck;
  final List<ScryfallCard> fullCardData;
  final List<DeckCard> collection;

  const DeckFinancialSheet({
    super.key,
    required this.deck,
    required this.fullCardData,
    required this.collection,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculs
    double totalMissingCost = 0.0;
    double totalOwnedValue = 0.0;
    double totalProxySaving = 0.0; // Pour info
    int missingCardsCount = 0;
    List<Map<String, dynamic>> cardPrices = [];

    final allDeckCards = [...deck.mainboard, ...deck.sideboard];

    for (final deckCard in allDeckCards) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;

      ScryfallCard? scryfallCard;
      try {
        scryfallCard = fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) { continue; }

      final double unitPrice = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
      
      // On vérifie la collection
      final collectionEntry = collection.firstWhere(
        (c) => c.scryfallId == deckCard.scryfallId,
        orElse: () => DeckCard(scryfallId: '', name: '', quantity: 0),
      );

      // LOGIQUE PROXY :
      // On a besoin de 'neededQty' cartes.
      // 'proxyQuantity' sont des proxies, donc on n'a pas besoin de les acheter.
      // 'ownedQty' sont déjà possédées.
      
      final int totalNeeded = deckCard.quantity;
      final int proxies = deckCard.proxyQuantity;
      final int realCardsNeeded = (totalNeeded - proxies).clamp(0, totalNeeded); // Ce qu'il faut vraiment avoir en carte physique
      
      final int ownedQty = collectionEntry.quantity;
      
      // Combien il en manque PHYSIQUEMENT à acheter
      final int missingQty = (realCardsNeeded - ownedQty).clamp(0, realCardsNeeded);
      
      // Valeur du stock utilisé (on utilise nos vraies cartes pour couvrir le besoin 'realCardsNeeded')
      final int usedOwnedQty = (ownedQty > realCardsNeeded) ? realCardsNeeded : ownedQty;

      totalMissingCost += (missingQty * unitPrice);
      totalOwnedValue += (usedOwnedQty * unitPrice);
      totalProxySaving += (proxies * unitPrice); // L'argent économisé grâce aux proxies
      missingCardsCount += missingQty;

      if (unitPrice > 0) {
        cardPrices.add({
          'name': scryfallCard.name,
          'price': unitPrice,
          'image': scryfallCard.smallImageUrl,
          'isOwned': ownedQty >= realCardsNeeded, // On a tout ce qu'il faut (hors proxies) ?
          'isProxy': proxies > 0
        });
      }
    }

    cardPrices.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
    final top10 = cardPrices.take(10).toList();

    // 2. UI
    return DraggableScrollableSheet(
      initialChildSize: 0.65, // Un peu plus grand
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
              Text('Estimation Financière', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: _buildFinanceCard(
                      title: 'Reste à acheter',
                      amount: totalMissingCost,
                      subtitle: '$missingCardsCount cartes',
                      color: Colors.red.shade400,
                      icon: Icons.shopping_cart_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinanceCard(
                      title: 'Économie (Proxies)',
                      amount: totalProxySaving,
                      subtitle: 'Non comptabilisé',
                      color: Colors.blueGrey.shade300,
                      icon: Icons.print,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFinanceCard(
                title: 'Valeur du stock utilisé',
                amount: totalOwnedValue,
                subtitle: 'Basé sur votre collection',
                color: Colors.green.shade400,
                icon: Icons.savings_outlined,
              ),
              
              const SizedBox(height: 24),
              Text('Top 10 - Les plus chères', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: top10.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final card = top10[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: card['image'] != null 
                        ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(card['image'], width: 30))
                        : const Icon(Icons.image, color: Colors.white24),
                      title: Row(
                        children: [
                          Expanded(child: Text(card['name'], style: GoogleFonts.cinzel(color: Colors.white), overflow: TextOverflow.ellipsis)),
                          if (card['isProxy']) 
                            Padding(padding: const EdgeInsets.only(left:8), child: Icon(Icons.print, size: 16, color: Colors.blueGrey.shade200))
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (card['isOwned']) const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.check_circle, color: Colors.green, size: 14)),
                          Text('${(card['price'] as double).toStringAsFixed(2)} €', style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold)),
                        ],
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
  }

  Widget _buildFinanceCard({required String title, required double amount, required String subtitle, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${amount.toStringAsFixed(2)} €', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]
      ),
    );
  }
}