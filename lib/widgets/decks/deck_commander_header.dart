// Fichier : lib/widgets/decks/deck_commander_header.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../controllers/deck_detail_controller.dart';
import '../../models/edhrec_models.dart';
import 'deck_power_level_badge.dart';

/// Displays the commander banner at the top of the deck detail page.
class DeckCommanderHeader extends StatelessWidget {
  final DeckDetailState deckState;
  final DeckPowerLevel? powerLevel;

  const DeckCommanderHeader({
    super.key,
    required this.deckState,
    required this.powerLevel,
  });

  @override
  Widget build(BuildContext context) {
    final deck = deckState.currentDeck;
    final c1Id = deck.commanderScryfallId;
    final c2Id = deck.commanderSecondaryScryfallId;

    if (c1Id == null && c2Id == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: AppColors.overlayDark,
        child: const Text('Aucun Commandant defini',
            style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary,
        border: Border(bottom: BorderSide(color: AppColors.primaryShade900, width: 2)),
        image: const DecorationImage(
            image: AssetImage('assets/images/background_texture_black.png'),
            fit: BoxFit.cover,
            opacity: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (c1Id != null) _buildSingleCommander(c1Id, 'Commander'),
              if (c1Id != null && c2Id != null)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.add, color: AppColors.primaryShade700)),
              if (c2Id != null) _buildSingleCommander(c2Id, 'Partenaire'),
            ],
          ),
          if (powerLevel != null) ...[
            const SizedBox(height: 8),
            DeckPowerLevelBadge(powerLevel: powerLevel!),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleCommander(String id, String label) {
    String? imageUrl;
    String name = 'Chargement...';
    try {
      final card = deckState.fullCardData.firstWhere((c) => c.id == id);
      imageUrl = card.artCropUrl ?? card.imageUrl;
      name = card.name;
    } catch (e) {
      /* card not loaded yet */
    }

    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.accentOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 60,
              width: double.infinity,
              color: AppColors.greyShade900,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Image.network(imageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (c, e, s) => const SizedBox()),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.transparent, AppColors.overlayVeryDark]),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Text(name,
                        style: AppTextStyles.bold(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
