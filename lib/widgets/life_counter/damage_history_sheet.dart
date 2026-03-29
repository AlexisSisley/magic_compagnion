// lib/widgets/life_counter/damage_history_sheet.dart
// Global damage log bottom sheet, filterable by player.

import 'package:flutter/material.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// A single entry in the combined damage log: a LifeEvent with its owner.
class _DamageEntry {
  final int playerId;
  final String playerName;
  final Color playerColor;
  final LifeEvent event;

  const _DamageEntry({
    required this.playerId,
    required this.playerName,
    required this.playerColor,
    required this.event,
  });
}

/// Returns a human-readable label for the damage source.
String _sourceLabel(String? source) {
  if (source == null || source.isEmpty) return 'Générique';
  final lower = source.toLowerCase();
  if (lower.contains('commander')) return source; // preserve full "Commander: X"
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

/// Bottom-sheet style widget showing the chronological damage log for a
/// [GameSession], filterable by player via [filterPlayerId].
class DamageHistorySheet extends StatelessWidget {
  final GameSession session;

  /// If non-null, only events for this player are shown.
  final int? filterPlayerId;

  /// Called when the user taps a filter chip.
  /// Passes `null` for "Tous", or the [PlayerState.playerId] for a player chip.
  final void Function(int?) onFilterChanged;

  const DamageHistorySheet({
    super.key,
    required this.session,
    required this.filterPlayerId,
    required this.onFilterChanged,
  });

  List<_DamageEntry> _buildEntries() {
    final entries = <_DamageEntry>[];
    for (final player in session.players) {
      final color = Color(player.config.colorValue);
      for (final event in player.lifeHistory) {
        entries.add(_DamageEntry(
          playerId: player.playerId,
          playerName: player.config.name,
          playerColor: color,
          event: event,
        ));
      }
    }
    // Sort newest first (largest timestamp first)
    entries.sort((a, b) => b.event.timestamp.compareTo(a.event.timestamp));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = _buildEntries();
    final filtered = filterPlayerId == null
        ? allEntries
        : allEntries.where((e) => e.playerId == filterPlayerId).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderMedium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('📜', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Damage Log',
                  style: AppTextStyles.sectionTitle(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 1),
          // Filter chips
          _FilterChipRow(
            players: session.players,
            filterPlayerId: filterPlayerId,
            onFilterChanged: onFilterChanged,
          ),
          const Divider(color: AppColors.borderSubtle, height: 1),
          // Event list
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Aucun événement',
                style: AppTextStyles.body(color: AppColors.textMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.borderSubtle, height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) =>
                    _EventRow(entry: filtered[index]),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  final List<PlayerState> players;
  final int? filterPlayerId;
  final void Function(int?) onFilterChanged;

  const _FilterChipRow({
    required this.players,
    required this.filterPlayerId,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // "Tous" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('Tous', style: AppTextStyles.label()),
              selected: filterPlayerId == null,
              onSelected: (_) => onFilterChanged(null),
              backgroundColor: AppColors.cardBackground,
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              side: BorderSide(
                color: filterPlayerId == null ? AppColors.primary : AppColors.borderMedium,
              ),
              showCheckmark: false,
            ),
          ),
          // One chip per player
          ...players.map((player) {
            final color = Color(player.config.colorValue);
            final selected = filterPlayerId == player.playerId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(player.config.name, style: AppTextStyles.label()),
                selected: selected,
                onSelected: (_) => onFilterChanged(player.playerId),
                backgroundColor: AppColors.cardBackground,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.borderMedium,
                ),
                showCheckmark: false,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChipContainer extends StatelessWidget {
  final bool selected;
  final Widget child;

  const _ChipContainer({required this.selected, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.cardBackground,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderMedium,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _EventRow extends StatelessWidget {
  final _DamageEntry entry;

  const _EventRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final delta = entry.event.delta;
    final isNegative = delta < 0;
    final deltaColor = isNegative ? AppColors.accentRed : AppColors.accentGreen;
    final deltaText = isNegative ? '$delta' : '+$delta';
    final source = _sourceLabel(entry.event.source);
    final timestamp = _formatTimestamp(entry.event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Player color dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: entry.playerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Player name (shown with dot, avoid duplicate finder conflict with chip)
          Expanded(
            flex: 2,
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                text: entry.playerName,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            ),
          ),
          // Delta
          SizedBox(
            width: 48,
            child: Text(
              deltaText,
              style: AppTextStyles.bold(color: deltaColor),
              textAlign: TextAlign.center,
            ),
          ),
          // Source label
          Expanded(
            flex: 3,
            child: Text(
              source,
              style: AppTextStyles.label(color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          // Timestamp
          Text(
            timestamp,
            style: AppTextStyles.label(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
