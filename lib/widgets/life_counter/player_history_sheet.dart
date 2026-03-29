// lib/widgets/life_counter/player_history_sheet.dart
// Per-player damage history bottom sheet for the life counter.

import 'package:flutter/material.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Resolves a [LifeEvent.source] string into a short display label.
String _sourceLabel(String? source) {
  if (source == null || source.isEmpty) return 'Générique';
  final lower = source.toLowerCase();
  if (lower.contains('commander')) return 'Commander: ${source.split(':').skip(1).join(':').trim()}';
  if (lower.contains('poison')) return 'Poison';
  if (lower.contains('energy')) return 'Energy';
  return source;
}

/// Formats a [Duration] as MM:SS.
String _formatTimestamp(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// A widget that shows a single player's life history.
///
/// Displays all [LifeEvent]s from [playerState.lifeHistory] in reverse
/// chronological order (newest first), together with a running life total
/// computed from [startingLife].
class PlayerHistorySheet extends StatelessWidget {
  const PlayerHistorySheet({
    super.key,
    required this.playerState,
    required this.startingLife,
  });

  final PlayerState playerState;
  final int startingLife;

  @override
  Widget build(BuildContext context) {
    final history = playerState.lifeHistory;
    final playerColor = Color(playerState.config.colorValue);

    // Pre-compute cumulative totals (oldest-first) so we can display them.
    // history[0] is the oldest event; history[last] is the newest.
    final List<int> runningTotals = [];
    int running = startingLife;
    for (final event in history) {
      running += event.delta;
      runningTotals.add(running);
    }

    // Display newest-first: reverse the list indices.
    final displayIndices = List.generate(history.length, (i) => history.length - 1 - i);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(
              bottom: BorderSide(color: AppColors.borderMedium),
            ),
          ),
          child: Row(
            children: [
              // Player colour dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: playerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  playerState.config.name,
                  style: AppTextStyles.sectionTitle(),
                ),
              ),
              // Current life total
              Text(
                '${playerState.life} PV',
                style: AppTextStyles.bold(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        // ── Event list ──────────────────────────────────────────
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Aucun événement',
                style: AppTextStyles.body(color: AppColors.textMuted),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayIndices.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: AppColors.borderSubtle,
            ),
            itemBuilder: (context, listIndex) {
              final eventIndex = displayIndices[listIndex];
              final event = history[eventIndex];
              final total = runningTotals[eventIndex];
              final isDamage = event.delta < 0;
              final deltaColor =
                  isDamage ? AppColors.accentRed : AppColors.accentGreen;
              final deltaText =
                  event.delta >= 0 ? '+${event.delta}' : '${event.delta}';
              final label = _sourceLabel(event.source);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Delta
                    SizedBox(
                      width: 44,
                      child: Text(
                        deltaText,
                        style: AppTextStyles.bold(
                          color: deltaColor,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Running total
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$total',
                        style: AppTextStyles.body(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Source label
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.body(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Timestamp
                    Text(
                      _formatTimestamp(event.timestamp),
                      style: AppTextStyles.label(
                        color: AppColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
