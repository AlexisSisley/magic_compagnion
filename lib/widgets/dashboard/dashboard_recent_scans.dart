// Fichier : lib/widgets/dashboard/dashboard_recent_scans.dart
// Liste des 5 derniers scans sur le dashboard.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/scan_history_model.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cards/scryfall_image.dart';
import 'dashboard_empty_state.dart';
import 'dashboard_section_header.dart';

class DashboardRecentScans extends StatelessWidget {
  final List<ScanHistoryItem> recentScans;

  const DashboardRecentScans({
    super.key,
    required this.recentScans,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Derniers Scans',
          icon: Icons.camera_alt,
          onSeeAll: recentScans.isNotEmpty
              ? () => context.push(AppRoutes.scanHistory)
              : null,
        ),
        if (recentScans.isEmpty)
          DashboardEmptyState(
            icon: Icons.camera_alt,
            message: 'Scannez une carte pour commencer',
            actionLabel: 'Scanner',
            onAction: () => context.go(AppRoutes.scanner),
          )
        else
          ...recentScans.map((scan) => _RecentScanTile(
                cardName: scan.cardName,
                scryfallId: scan.scryfallId,
                timestamp: scan.timestamp,
                onTap: () => context.push(
                  AppRoutes.cardDetail,
                  extra: <String, dynamic>{'cardName': scan.cardName},
                ),
              )),
      ],
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  final String cardName;
  final String scryfallId;
  final DateTime timestamp;
  final VoidCallback onTap;

  const _RecentScanTile({
    required this.cardName,
    required this.scryfallId,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        'https://api.scryfall.com/cards/$scryfallId?format=image&version=small';
    final timeAgo = _formatTimeAgo(timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                ScryfallImage(
                  imageUrl: imageUrl,
                  width: 36,
                  height: 50,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardName,
                        style: AppTextStyles.cardTitle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo,
                        style: AppTextStyles.label(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return '${date.day}/${date.month}/${date.year}';
  }
}
