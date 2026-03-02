// Fichier : lib/widgets/collections/set_detail_stats_header.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/set_detail_controller.dart';

class SetDetailStatsHeader extends StatelessWidget {
  final SetDetailState state;

  const SetDetailStatsHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final int missingCount = state.totalMissing;
    final int totalCount = state.totalSetCount;
    final int ownedCount = totalCount - missingCount;
    final double progress = totalCount > 0 ? ownedCount / totalCount : 0.0;
    final String percentage = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border(
            bottom: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.05))),
        boxShadow: [
          BoxShadow(
              color: AppColors.textOnPrimary.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROGRESSION',
                      style: AppTextStyles.cinzel(color: AppColors.borderFaint, fontSize: 10).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$ownedCount',
                          style: AppTextStyles.bold(color: AppColors.accentGreen, fontSize: 20)),
                      Text(' / $totalCount',
                          style: AppTextStyles.cinzel(color: AppColors.textMuted, fontSize: 14)),
                      const SizedBox(width: 8),
                      Text('$percentage%',
                          style: GoogleFonts.roboto(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildRarityBadge('M', Colors.orange.shade900,
                      state.rarityCounts['mythic'] ?? 0),
                  const SizedBox(width: 6),
                  _buildRarityBadge('R', AppColors.amber,
                      state.rarityCounts['rare'] ?? 0),
                  const SizedBox(width: 6),
                  _buildRarityBadge('U', Colors.blueGrey,
                      state.rarityCounts['uncommon'] ?? 0),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth * progress,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E3A8A),
                          Color(0xFF3B82F6),
                          Color(0xFF10B981)
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accentGreen.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 0,
                            offset: const Offset(0, 0))
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRarityBadge(String letter, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Text(letter,
              style: AppTextStyles.cinzel(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
