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
      
      final collectionEntry = collection.firstWhere(
        (c) => c.scryfallId == deckCard.scryfallId,
        orElse: () => DeckCard(scryfallId: '', name: '', quantity: 0),
      );

      final int ownedQty = collectionEntry.quantity;
      final int neededQty = deckCard.quantity;
      
      final int missingQty = (neededQty - ownedQty).clamp(0, neededQty);
      final int usedOwnedQty = (ownedQty > neededQty) ? neededQty : ownedQty;

      totalMissingCost += (missingQty * unitPrice);
      totalOwnedValue += (usedOwnedQty * unitPrice);
      missingCardsCount += missingQty;

      if (unitPrice > 0) {
        cardPrices.add({
          'name': scryfallCard.name,
          'price': unitPrice,
          'image': scryfallCard.smallImageUrl,
          'isOwned': ownedQty >= neededQty
        });
      }
    }

    cardPrices.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
    final top10 = cardPrices.take(10).toList();

    // 2. UI
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
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
              
              _buildFinanceCard(
                title: 'Reste à acheter',
                amount: totalMissingCost,
                subtitle: '$missingCardsCount cartes manquantes',
                color: Colors.red.shade400,
                icon: Icons.shopping_cart_outlined,
              ),
              const SizedBox(height: 12),
              _buildFinanceCard(
                title: 'Valeur de votre stock',
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
                      title: Text(card['name'], style: GoogleFonts.cinzel(color: Colors.white), overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14)),
              Text('${amount.toStringAsFixed(2)} €', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}