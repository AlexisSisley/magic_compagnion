// Fichier : lib/widgets/decks/deck_financial_sheet.dart
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // NÉCESSITE LE PLUGIN url_launcher
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../utils/price_helper.dart';

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

  Future<void> _launchURL(String? url) async {
    if (url == null) return;
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Impossible de lancer $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculs
    double totalMissingCost = 0.0;
    double totalOwnedValue = 0.0;
    // ignore: unused_local_variable
    double totalProxySaving = 0.0; 
    int missingCardsCount = 0;
    List<Map<String, dynamic>> cardPrices = [];

    final allDeckCards = [...deck.mainboard, ...deck.sideboard];

    for (final deckCard in allDeckCards) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;

      final scryfallCard = fullCardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
      if (scryfallCard == null) continue;

      // --- LOGIQUE PRIX (FOIL ou NORMAL) ---
      double unitPrice = PriceHelper.bestPrice(scryfallCard.prices, isFoil: deckCard.isFoil);
      
      final collectionEntry = collection.firstWhere(
        (c) => c.scryfallId == deckCard.scryfallId,
        orElse: () => DeckCard(scryfallId: '', name: '', quantity: 0),
      );

      final int totalNeeded = deckCard.quantity;
      final int proxies = deckCard.proxyQuantity;
      final int realCardsNeeded = (totalNeeded - proxies).clamp(0, totalNeeded);
      
      final int ownedQty = collectionEntry.quantity;
      final int missingQty = (realCardsNeeded - ownedQty).clamp(0, realCardsNeeded);
      final int usedOwnedQty = (ownedQty > realCardsNeeded) ? realCardsNeeded : ownedQty;

      totalMissingCost += (missingQty * unitPrice);
      totalOwnedValue += (usedOwnedQty * unitPrice);
      totalProxySaving += (proxies * unitPrice);
      missingCardsCount += missingQty;

      if (unitPrice > 0) {
        cardPrices.add({
          'name': scryfallCard.name,
          'price': unitPrice,
          'image': scryfallCard.smallImageUrl,
          'isOwned': ownedQty >= realCardsNeeded,
          'isProxy': proxies > 0,
          'isFoil': deckCard.isFoil,
          'purchaseUrl': scryfallCard.purchaseUris['cardmarket'] // LIEN CARDMARKET
        });
      }
    }

    cardPrices.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
    final topCards = cardPrices.take(20).toList();

    // 2. UI
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.synergyNeutral, borderRadius: BorderRadius.circular(2)))),
              Text('Estimation Financière', style: AppTextStyles.pageTitle(fontSize: 22)),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: _buildFinanceCard(
                      title: 'À acheter',
                      amount: totalMissingCost,
                      subtitle: '$missingCardsCount cartes',
                      color: Colors.red.shade400,
                      icon: Icons.shopping_cart_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinanceCard(
                      title: 'Valeur Stock',
                      amount: totalOwnedValue,
                      subtitle: 'Déjà possédé',
                      color: Colors.green.shade400,
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              Text('Détail des coûts (Top 20)', style: AppTextStyles.sectionTitle()),
              const SizedBox(height: 10),

              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: topCards.length,
                  separatorBuilder: (ctx, i) => const Divider(color: AppColors.borderLight),
                  itemBuilder: (context, index) {
                    final card = topCards[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: card['image'] != null 
                        ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(card['image'], width: 30))
                        : const Icon(Icons.image, color: AppColors.borderMedium),
                      title: Row(
                        children: [
                          Expanded(child: Text(card['name'], style: AppTextStyles.cinzel(), overflow: TextOverflow.ellipsis)),
                          if (card['isFoil']) 
                             const Padding(padding: EdgeInsets.only(left:6), child: Icon(Icons.star, size: 14, color: AppColors.amber)), // Icône Foil
                          if (card['isProxy']) 
                            Padding(padding: const EdgeInsets.only(left:6), child: Icon(Icons.print, size: 14, color: Colors.blueGrey.shade200))
                        ],
                      ),
                      subtitle: card['isOwned'] 
                          ? const Text('Possédé', style: TextStyle(color: AppColors.success, fontSize: 10))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(card['price'] as double).toStringAsFixed(2)} €', style: AppTextStyles.bold(color: AppColors.primaryShade700)),
                          const SizedBox(width: 12),
                          // BOUTON CARDMARKET
                          if (card['purchaseUrl'] != null)
                            IconButton(
                              icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.accent, size: 20),
                              tooltip: 'Voir sur Cardmarket',
                              onPressed: () => _launchURL(card['purchaseUrl']),
                            ),
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
      decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.label(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${amount.toStringAsFixed(2)} €', style: AppTextStyles.sectionTitle()),
          Text(subtitle, style: const TextStyle(color: AppColors.borderFaint, fontSize: 10)),
        ]
      ),
    );
  }
}
