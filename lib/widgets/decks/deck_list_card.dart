// Fichier : lib/widgets/decks/deck_list_card.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/deck_model.dart';
import '../../services/scryfall_api.dart';
import '../cards/scryfall_image.dart';

/// A single deck card in the deck list, with dismissible swipe-to-delete.
class DeckListCard extends StatelessWidget {
  final Deck deck;
  final double totalPrice;
  final VoidCallback onTap;
  final Future<bool?> Function(DismissDirection) confirmDismiss;
  final VoidCallback onDismissed;

  const DeckListCard({
    super.key,
    required this.deck,
    required this.totalPrice,
    required this.onTap,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCommander = deck.commanderScryfallId != null;
    final int cardCount = deck.mainboard.fold(0, (s, c) => s + c.quantity);

    return Dismissible(
      key: Key(deck.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red.shade900, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('USE THE FORCE',
              style: AppTextStyles.bold(fontSize: 16).copyWith(letterSpacing: 1.5)),
          const SizedBox(width: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.back_hand, color: AppColors.textPrimary, size: 30),
              Icon(Icons.flash_on, color: Colors.blueAccent.shade100, size: 40),
            ],
          ),
        ]),
      ),
      confirmDismiss: confirmDismiss,
      onDismissed: (_) => onDismissed(),
      child: Card(
        color: AppColors.textOnPrimary.withValues(alpha: 0.8),
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isCommander
                ? AppColors.primaryShade800.withValues(alpha: 0.6)
                : AppColors.borderSubtle,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isCommander)
                      ScryfallImage(
                        imageUrl: ScryfallApi.artCropRedirectUrl(
                            deck.commanderScryfallId!),
                        width: 50,
                        height: 50,
                        borderRadius: BorderRadius.circular(20),
                        errorWidget: Icon(Icons.shield_outlined,
                            color: AppColors.primaryShade700, size: 28),
                      )
                    else
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: AppColors.borderLight,
                            borderRadius: BorderRadius.circular(25)),
                        child: const Icon(Icons.style,
                            color: AppColors.textMuted, size: 24),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        deck.name,
                        style: AppTextStyles.bold(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (deck.colors.isNotEmpty)
                      Row(
                        children: deck.colors
                            .map((c) => Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _getManaIcon(c, size: 16),
                                ))
                            .toList(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCommander
                            ? AppColors.primaryShade900.withValues(alpha: 0.3)
                            : AppColors.greyShade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCommander ? 'COMMANDER' : 'STANDARD',
                        style: AppTextStyles.bold(color: isCommander ? Colors.yellow.shade200 : AppColors.textSecondary, fontSize: 10),
                      ),
                    ),
                    const Spacer(),
                    Text('$cardCount cartes',
                        style: AppTextStyles.cinzel(color: Colors.amberAccent, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                      ' \u2248 ${totalPrice.toStringAsFixed(0)} \u20AC',
                      style: GoogleFonts.roboto(
                          color: AppColors.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getManaIcon(String symbol, {double size = 20}) {
    final url = 'https://svgs.scryfall.io/card-symbols/$symbol.svg';
    return SvgPicture.network(
      url,
      height: size,
      width: size,
      placeholderBuilder: (_) =>
          Text(symbol, style: TextStyle(color: AppColors.textPrimary, fontSize: size)),
    );
  }
}
