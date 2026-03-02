// Fichier : lib/widgets/decks/deck_tokens_tab.dart
// Sprint 9 : Onglet affichant les tokens requis par le deck.

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../controllers/deck_detail_controller.dart';

class DeckTokensTab extends StatelessWidget {
  final List<TokenInfo> tokens;

  const DeckTokensTab({super.key, required this.tokens});

  @override
  Widget build(BuildContext context) {
    if (tokens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.token, color: AppColors.borderMedium, size: 64),
              const SizedBox(height: 16),
              Text(
                'Ce deck ne necessite aucun token',
                style: AppTextStyles.cinzel(color: AppColors.textMuted, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tokens.length,
      itemBuilder: (context, index) {
        final token = tokens[index];
        return Card(
          color: AppColors.textOnPrimary.withValues(alpha: 0.45),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: token.imageUrl != null && token.imageUrl!.isNotEmpty
                      ? Image.network(
                          token.imageUrl!,
                          width: 60,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 60,
                            height: 84,
                            color: AppColors.greyShade800,
                            child: const Icon(Icons.token, color: AppColors.textDisabled),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 84,
                          color: AppColors.greyShade800,
                          child: const Icon(Icons.token, color: AppColors.textDisabled),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.name,
                        style: AppTextStyles.bold(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        token.typeLine,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
