// Fichier : lib/widgets/decks/deck_list_card.dart

import 'package:flutter/material.dart';

import '../../models/deck_model.dart';
import '../../services/scryfall_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/magic_palette.dart';
import '../cards/scryfall_image.dart';

/// Tuile 16:9 d'un deck : l'art du commandant occupe tout le fond, le pied
/// (nom, couleurs, compte et prix) repose sur un dégradé sombre.
///
/// La tuile garde la même forme quelles que soient les données : sans
/// commandant, l'art est remplacé par un fond uni, et la rangée de pastilles
/// réserve sa hauteur même vide. Une grille de tuiles qui change de hauteur
/// selon le deck serait illisible.
class DeckListCard extends StatelessWidget {
  final Deck deck;
  final double totalPrice;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Future<bool?> Function(DismissDirection) confirmDismiss;
  final VoidCallback onDismissed;

  const DeckListCard({
    super.key,
    required this.deck,
    required this.totalPrice,
    required this.onTap,
    this.onLongPress,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  static const double _radius = 8;
  static const double _pipSize = 13;

  /// Les pastilles utilisent les couleurs de mana de la charte et non les SVG
  /// de Scryfall : la tuile doit rester rendable hors ligne et en test.
  static Color _manaColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'W':
        return AppColors.manaWhite;
      case 'U':
        return AppColors.manaBlue;
      case 'B':
        return AppColors.manaBlack;
      case 'R':
        return AppColors.manaRed;
      case 'G':
        return AppColors.manaGreen;
      default:
        return AppColors.manaColorless;
    }
  }

  /// Prix arrondi à l'euro ; « — » quand il est inconnu (0 ou absent), pour
  /// ne pas afficher un « 0 € » qui passerait pour un deck gratuit.
  /// `PriceHelper` ne propose que des formats à deux décimales, d'où ce
  /// formatage local.
  static String _formatPrice(double price) =>
      price > 0 ? '${price.round()} €' : '—';

  @override
  Widget build(BuildContext context) {
    final commanderId = deck.commanderScryfallId;
    final int cardCount = deck.mainboard.fold(0, (s, c) => s + c.quantity);
    final palette = MagicPalette.of(context);
    final borderRadius = BorderRadius.circular(_radius);

    return Dismissible(
      key: Key(deck.id),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red.shade900, borderRadius: borderRadius),
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
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (commanderId != null)
                ScryfallImage(
                  imageUrl: ScryfallApi.artCropRedirectUrl(commanderId),
                  fit: BoxFit.cover,
                )
              else
                ColoredBox(
                  color: palette.raised,
                  child: const Center(
                    child: Icon(Icons.style_outlined,
                        color: AppColors.textMuted, size: 48),
                  ),
                ),
              // Dégradé de pied : le texte reste lisible sur n'importe quel art.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.textOnPrimary.withValues(alpha: 0),
                        AppColors.textOnPrimary.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sectionTitle(),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: _pipSize,
                          child: Row(
                            children: [
                              for (final (i, c) in deck.colors.indexed)
                                Container(
                                  key: ValueKey('deck-color-pip-$i'),
                                  width: _pipSize,
                                  height: _pipSize,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: _manaColor(c),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.borderSubtle),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text:
                                  '$cardCount ${cardCount > 1 ? 'cartes' : 'carte'} · ',
                              style: AppTextStyles.text(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                            TextSpan(
                              text: _formatPrice(totalPrice),
                              style: AppTextStyles.bold(
                                  color: AppColors.primary, fontSize: 12),
                            ),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deck.format.toUpperCase(),
                    style: AppTextStyles.bold(
                        color: AppColors.textOnPrimary, fontSize: 10),
                  ),
                ),
              ),
              // Dernier enfant : l'éclaboussure d'encre doit passer par-dessus
              // l'art, sinon l'image la masquerait.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap, onLongPress: onLongPress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
