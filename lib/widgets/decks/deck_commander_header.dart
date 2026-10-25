// Fichier : lib/widgets/decks/deck_commander_header.dart

import 'package:flutter/material.dart';

import '../../models/deck_model.dart';
import '../../models/edhrec_models.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/scryfall_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/magic_palette.dart';
import '../cards/scryfall_image.dart';
import 'deck_list_card.dart';
import 'mana_pips.dart';

/// Bandeau en tête de la page d'un deck : l'art du commandant en plein cadre,
/// le nom du deck et la rangée de stats de jeu sur un dégradé sombre.
///
/// Le bandeau garde la même hauteur avec un commandant, un partenaire ou
/// aucun : une page dont la géométrie bouge selon les données fait sauter les
/// onglets qu'elle porte.
class DeckCommanderHeader extends StatelessWidget {
  final Deck deck;
  final List<ScryfallCard> fullCardData;
  final int cardCount;
  final double averageManaValue;
  final DeckPowerLevel? powerLevel;
  final double totalPrice;

  const DeckCommanderHeader({
    super.key,
    required this.deck,
    required this.fullCardData,
    required this.cardCount,
    required this.averageManaValue,
    required this.powerLevel,
    required this.totalPrice,
  });

  static const double height = 180;

  /// Art d'un commandant : celui de la carte chargée, sinon l'URL de
  /// redirection de Scryfall (la carte peut ne pas être encore résolue).
  String _artUrl(String id) {
    final card = fullCardData.where((c) => c.id == id).firstOrNull;
    final url = card?.artCropUrl ?? card?.imageUrl;
    return (url == null || url.isEmpty)
        ? ScryfallApi.artCropRedirectUrl(id)
        : url;
  }

  Widget _art(String id, MagicPalette palette) {
    final fallback = ColoredBox(color: palette.raised);
    // Un commandant importé sans résolution porte « LOCAL:<nom> » : son URL
    // d'art échouerait à coup sûr, on ne la demande pas.
    if (id.startsWith('LOCAL:')) return fallback;
    return ScryfallImage(
      imageUrl: _artUrl(id),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorWidget: fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MagicPalette.of(context);
    final ids = [
      deck.commanderScryfallId,
      deck.commanderSecondaryScryfallId,
    ].whereType<String>().toList();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ids.isEmpty)
            ColoredBox(
              color: palette.raised,
              child: Align(
                alignment: const Alignment(0, -0.6),
                child: Text(
                  'Aucun commandant défini',
                  style: AppTextStyles.text(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                for (final id in ids) Expanded(child: _art(id, palette)),
              ],
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: deckCardGradientStops,
                  colors: [
                    for (final a in deckCardGradientAlphas)
                      AppColors.textOnPrimary.withValues(alpha: a),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.pageTitle(fontSize: 26),
                    ),
                    const SizedBox(height: 6),
                    _statsRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final muted = AppTextStyles.text(
      color: AppColors.textSecondary,
      fontSize: 13,
    );
    final cmc = averageManaValue.toStringAsFixed(1).replaceAll('.', ',');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Le Wrap passe à la ligne sur petite largeur ; le prix, hors du Wrap,
        // reste en dernier et à droite.
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ManaPips(colors: deck.colors, size: 14),
              Text(
                '$cardCount ${cardCount > 1 ? 'cartes' : 'carte'}',
                style: muted,
              ),
              Text('·', style: muted),
              Text('CMC moyen $cmc', style: muted),
              if (powerLevel != null) ...[
                Text('·', style: muted),
                _powerPill(powerLevel!),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          DeckListCard.formatPrice(totalPrice),
          style: AppTextStyles.text(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  /// Pilule à bordure or. Les couleurs sont explicites : le primaire du thème
  /// est lilas, pas or.
  Widget _powerPill(DeckPowerLevel level) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.primary),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      'Power ${level.score}',
      style: AppTextStyles.bold(color: AppColors.primary, fontSize: 12),
    ),
  );
}
