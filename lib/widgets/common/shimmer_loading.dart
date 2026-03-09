// Fichier : lib/widgets/common/shimmer_loading.dart
// Sprint 14, US-14.9 : Shimmer loading placeholders.
// Remplace les CircularProgressIndicator par des placeholders animes.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';

/// Shimmer placeholder pour une carte MTG en liste.
class ShimmerCardTile extends StatelessWidget {
  const ShimmerCardTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cardBackground,
      highlightColor: AppColors.surfaceDark.withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail image
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            // Text lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder pour le Dashboard (resume collection).
class ShimmerDashboardSummary extends StatelessWidget {
  const ShimmerDashboardSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cardBackground,
      highlightColor: AppColors.surfaceDark.withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _box(width: 80, height: 50),
            const SizedBox(width: 16),
            _box(width: 80, height: 50),
            const SizedBox(width: 16),
            Expanded(child: _box(height: 50)),
          ],
        ),
      ),
    );
  }

  Widget _box({double? width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Shimmer placeholder pour une liste de cartes (N items).
class ShimmerCardList extends StatelessWidget {
  final int itemCount;

  const ShimmerCardList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (_) => const ShimmerCardTile(),
      ),
    );
  }
}

/// Shimmer pour un graphique preview.
class ShimmerChartPlaceholder extends StatelessWidget {
  final double height;

  const ShimmerChartPlaceholder({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cardBackground,
      highlightColor: AppColors.surfaceDark.withValues(alpha: 0.8),
      child: Container(
        height: height,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
