// Fichier : lib/widgets/decks/deck_list_card.dart

import 'package:flutter/material.dart';

import '../../models/deck_model.dart';
import '../../services/scryfall_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/magic_palette.dart';
import '../cards/scryfall_image.dart';
import 'mana_pips.dart';

/// Paliers du dégradé de pied (exposés pour le test de lisibilité).
const List<double> deckCardGradientStops = [0.0, 0.25, 1.0];
const List<double> deckCardGradientAlphas = [0.0, 0.6, 0.9];

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

  /// Ombre douce : filet de sécurité quand l'art est très clair malgré le
  /// dégradé.
  static final List<Shadow> textShadows = [
    Shadow(
      color: AppColors.textOnPrimary.withValues(alpha: 0.7),
      blurRadius: 4,
    ),
  ];
  static const double _pipSize = 13;

  /// Prix arrondi à l'euro ; « — » quand il est inconnu (0 ou absent), pour
  /// ne pas afficher un « 0 € » qui passerait pour un deck gratuit.
  /// `PriceHelper` ne propose que des formats à deux décimales, d'où ce
  /// formatage local.
  static String formatPrice(double price) =>
      price > 0 ? '${price.round()} €' : '—';

  /// Fond neutre quand l'art manque (pas de commandant, ou image qui ne
  /// charge pas) : mieux qu'une icône d'image cassée sur une tuile de deck.
  static Widget _artFallback(MagicPalette palette) => ColoredBox(
    color: palette.raised,
    child: const Center(
      child: Icon(Icons.style_outlined, color: AppColors.textMuted, size: 48),
    ),
  );

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
          color: Colors.red.shade900,
          borderRadius: borderRadius,
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'USE THE FORCE',
              style: AppTextStyles.bold(
                fontSize: 16,
              ).copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(width: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.back_hand,
                  color: AppColors.textPrimary,
                  size: 30,
                ),
                Icon(
                  Icons.flash_on,
                  color: Colors.blueAccent.shade100,
                  size: 40,
                ),
              ],
            ),
          ],
        ),
      ),
      confirmDismiss: confirmDismiss,
      onDismissed: (_) => onDismissed(),
      // Un seul nœud pour tout le pied de tuile : sans lui, le lecteur d'écran
      // énonce le nom, le compte, le prix et le format en morceaux. Le nom et
      // le compte suffisent pour choisir, le prix reste lisible à l'écran.
      child: Semantics(
        button: true,
        label: '${deck.name}, $cardCount ${cardCount > 1 ? 'cartes' : 'carte'}',
        onLongPressHint: onLongPress == null ? null : 'Dossiers',
        excludeSemantics: true,
        onTap: onTap,
        onLongPress: onLongPress,
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
                // Un commandant importé sans résolution porte « LOCAL:<nom> » :
                // son URL d'art échouerait à coup sûr, on ne la demande pas.
                if (commanderId != null && !commanderId.startsWith('LOCAL:'))
                  ScryfallImage(
                    imageUrl: ScryfallApi.artCropRedirectUrl(commanderId),
                    fit: BoxFit.cover,
                    errorWidget: _artFallback(palette),
                  )
                else
                  _artFallback(palette),
                // Dégradé de pied : le texte reste lisible sur n'importe quel art.
                // Il est étagé et dimensionné par le bloc de texte (hauteur
                // fixe), donc ses paliers tombent au même endroit par rapport au
                // nom quelle que soit la largeur de la tuile : à 25 % de la
                // hauteur, là où commence le nom, le fond est déjà à 60 %.
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
                      padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sectionTitle().copyWith(
                              shadows: textShadows,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ManaPips(colors: deck.colors, size: _pipSize),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '$cardCount ${cardCount > 1 ? 'cartes' : 'carte'} · ',
                                  style: AppTextStyles.text(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ).copyWith(shadows: textShadows),
                                ),
                                TextSpan(
                                  text: formatPrice(totalPrice),
                                  style: AppTextStyles.bold(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ).copyWith(shadows: textShadows),
                                ),
                              ],
                            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      deck.format.toUpperCase(),
                      style: AppTextStyles.bold(
                        color: AppColors.textOnPrimary,
                        fontSize: 10,
                      ),
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
      ),
    );
  }
}
