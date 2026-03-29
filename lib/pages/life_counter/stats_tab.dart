// Fichier : lib/pages/life_counter/stats_tab.dart
// Life Counter v2 - Task 19: Stats Tab

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/game_stats.dart';
import 'package:magic_companion/providers/stats_provider.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Tab displaying game statistics: overview, by deck, by opponent, by format.
class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerStats = ref.watch(ownerStatsProvider);
    final deckStats = ref.watch(deckStatsProvider);
    final opponentStats = ref.watch(opponentStatsProvider);
    final formatStats = ref.watch(formatStatsProvider);

    final hasNoStats = ownerStats == null &&
        deckStats.isEmpty &&
        opponentStats.isEmpty &&
        formatStats.isEmpty;

    if (hasNoStats) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Pas encore de statistiques. Jouez des parties pour commencer !',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ----------------------------------------------------------------
        // Section Résumé
        // ----------------------------------------------------------------
        if (ownerStats != null) ...[
          _SectionHeader(title: 'Résumé'),
          _OverviewCard(stats: ownerStats),
          const SizedBox(height: 16),
        ],

        // ----------------------------------------------------------------
        // Section Par Deck
        // ----------------------------------------------------------------
        if (deckStats.isNotEmpty) ...[
          _SectionHeader(title: 'Par Deck'),
          ...deckStats.map(
            (d) => _StatRow(
              label: d.deckName,
              games: d.games,
              wins: d.wins,
              winrate: d.winrate,
              onTap: () => debugPrint('Deck tapped: ${d.deckName}'),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ----------------------------------------------------------------
        // Section Par Adversaire
        // ----------------------------------------------------------------
        if (opponentStats.isNotEmpty) ...[
          _SectionHeader(title: 'Par Adversaire'),
          ...opponentStats.map(
            (o) => _StatRow(
              label: o.opponentName,
              games: o.gamesAgainst,
              wins: o.winsAgainst,
              winrate: o.winrateAgainst,
              onTap: () => debugPrint('Opponent tapped: ${o.opponentName}'),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ----------------------------------------------------------------
        // Section Par Format
        // ----------------------------------------------------------------
        if (formatStats.isNotEmpty) ...[
          _SectionHeader(title: 'Par Format'),
          ...formatStats.map(
            (f) => _StatRow(
              label: f.format,
              games: f.games,
              wins: f.wins,
              winrate: f.winrate,
              onTap: () => debugPrint('Format tapped: ${f.format}'),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: AppTextStyles.sectionTitle()),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview card (Résumé)
// ---------------------------------------------------------------------------

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats});

  final OwnerStats stats;

  @override
  Widget build(BuildContext context) {
    final winratePct = (stats.winrate * 100).round();
    final barColor =
        stats.winrate >= 0.5 ? AppColors.success : AppColors.error;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big numbers row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BigStat(
                label: 'Parties',
                value: '${stats.totalGames}',
              ),
              _BigStat(
                label: 'Victoires',
                value: '${stats.wins}',
              ),
              _BigStat(
                label: 'Win Rate',
                value: '$winratePct%',
                valueColor: barColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Winrate progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.winrate,
              minHeight: 8,
              backgroundColor: AppColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          // Streaks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Série actuelle : ${stats.currentStreak}',
                style: AppTextStyles.label(color: AppColors.textMuted),
              ),
              Text(
                'Meilleure : ${stats.bestStreak}',
                style: AppTextStyles.label(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.pageTitle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 32,
          ),
        ),
        Text(label, style: AppTextStyles.label(color: AppColors.textMuted)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Generic stat row (deck / opponent / format)
// ---------------------------------------------------------------------------

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.games,
    required this.wins,
    required this.winrate,
    required this.onTap,
  });

  final String label;
  final int games;
  final int wins;
  final double winrate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final winratePct = (winrate * 100).round();
    final barColor = winrate >= 0.5 ? AppColors.success : AppColors.error;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.cardTitle(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$winratePct%',
                  style: AppTextStyles.bold(color: barColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: winrate,
                      minHeight: 6,
                      backgroundColor: AppColors.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$wins/$games',
                  style: AppTextStyles.label(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
