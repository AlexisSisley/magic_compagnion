// lib/widgets/life_counter/zone/player_drawer.dart
// Le tiroir du joueur (spec §2.7) : tout ce qui n'est pas les points de vie.
//
// Lot 2 — la coquille : compteurs et actions (ces dernières reprises du menu
// radial, qui perd son appui long au profit du mode ajustement, spec §2.5).
// Lot 3 y ajoutera la grille de dégâts de commandant.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

const _counterLabels = <String, String>{
  'poison': 'Poison',
  'energy': 'Énergie',
  'commander_tax': 'Taxe de commandant',
};

const _counterIcons = <String, IconData>{
  'poison': Icons.science,
  'energy': Icons.flash_on,
  'commander_tax': Icons.local_police,
};

Future<void> showPlayerDrawer({
  required BuildContext context,
  required String playerName,
  required Map<String, int> counters,
  required bool isMonarch,
  required bool isEliminated,
  required void Function(String counterId, int delta) onCounterDelta,
  required VoidCallback onToggleMonarch,
  required VoidCallback onEliminate,
  required VoidCallback onResetCounters,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.greyShade800,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetCtx) => _PlayerDrawerBody(
      playerName: playerName,
      counters: counters,
      isMonarch: isMonarch,
      isEliminated: isEliminated,
      onCounterDelta: onCounterDelta,
      onToggleMonarch: () {
        Navigator.of(sheetCtx).pop();
        onToggleMonarch();
      },
      onEliminate: () {
        Navigator.of(sheetCtx).pop();
        onEliminate();
      },
      onResetCounters: () {
        Navigator.of(sheetCtx).pop();
        onResetCounters();
      },
    ),
  );
}

class _PlayerDrawerBody extends StatefulWidget {
  const _PlayerDrawerBody({
    required this.playerName,
    required this.counters,
    required this.isMonarch,
    required this.isEliminated,
    required this.onCounterDelta,
    required this.onToggleMonarch,
    required this.onEliminate,
    required this.onResetCounters,
  });

  final String playerName;
  final Map<String, int> counters;
  final bool isMonarch;
  final bool isEliminated;
  final void Function(String counterId, int delta) onCounterDelta;
  final VoidCallback onToggleMonarch;
  final VoidCallback onEliminate;
  final VoidCallback onResetCounters;

  @override
  State<_PlayerDrawerBody> createState() => _PlayerDrawerBodyState();
}

class _PlayerDrawerBodyState extends State<_PlayerDrawerBody> {
  /// Copie locale : le tiroir reste ouvert pendant qu'on incrémente, et doit
  /// refléter le changement immédiatement sans attendre un rebuild de la page.
  late final Map<String, int> _values = Map<String, int>.from(widget.counters);

  void _bump(String id, int delta) {
    setState(() {
      _values[id] = ((_values[id] ?? 0) + delta).clamp(0, 99);
    });
    widget.onCounterDelta(id, delta);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(widget.playerName, style: AppTextStyles.cardTitle()),
            const SizedBox(height: 14),
            for (final id in _counterLabels.keys) _counterRow(id),
            const Divider(height: 26),
            _action(
              key: const ValueKey('action-monarch'),
              icon: Icons.star,
              label: widget.isMonarch ? 'Retirer le monarque' : 'Monarque',
              color: AppColors.amber,
              onTap: widget.onToggleMonarch,
            ),
            _action(
              key: const ValueKey('action-eliminate'),
              icon: widget.isEliminated ? Icons.undo : Icons.person_off,
              label: widget.isEliminated
                  ? 'Annuler l\'élimination'
                  : 'Éliminer',
              color: AppColors.accentRed,
              onTap: widget.onEliminate,
            ),
            _action(
              key: const ValueKey('action-reset'),
              icon: Icons.restart_alt,
              label: 'Réinitialiser les compteurs',
              color: AppColors.textSecondary,
              onTap: widget.onResetCounters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterRow(String id) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_counterIcons[id], size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_counterLabels[id]!, style: AppTextStyles.body()),
          ),
          IconButton(
            key: ValueKey('counter-$id-minus'),
            icon: const Icon(Icons.remove),
            color: AppColors.textSecondary,
            onPressed: () => _bump(id, -1),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${_values[id] ?? 0}',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle(),
            ),
          ),
          IconButton(
            key: ValueKey('counter-$id-plus'),
            icon: const Icon(Icons.add),
            color: AppColors.textSecondary,
            onPressed: () => _bump(id, 1),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTextStyles.body()),
      onTap: onTap,
    );
  }
}
