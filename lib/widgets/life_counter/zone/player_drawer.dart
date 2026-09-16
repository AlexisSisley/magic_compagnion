// lib/widgets/life_counter/zone/player_drawer.dart
// Le tiroir du joueur (spec §2.7) : tout ce qui n'est pas les points de vie.
//
// Lot 2 — la coquille : compteurs et actions (ces dernières reprises du menu
// radial, qui perd son appui long au profit du mode ajustement, spec §2.5).
// Lot 3 — la grille de dégâts de commandant reçus (§2.7 point 2), qui
// remplace la ligne provisoire ouvrant le sélecteur plein écran.
// Lot 5, tâche 2 — les lignes de compteurs ne sont plus les trois constantes
// `_counterLabels` / `_counterIcons` (icônes Material figées, disparues) :
// elles suivent `activeCounters`, la liste ordonnée des `CounterType` actifs
// de la session, résolue par l'appelant (`life_counter_page._openPlayerDrawer`)
// à partir de `GameSession.activeCounterIds` et du catalogue (tâche 1). Rendu
// par emoji (`CounterType.emoji`), pas par `IconData` : un `IconData` ne se
// sérialise pas proprement et obligerait à un sélecteur d'icônes pour les
// compteurs personnalisés, alors que l'émoji est déjà une donnée du modèle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'commander_damage_grid.dart';

Future<void> showPlayerDrawer({
  required BuildContext context,
  required String playerName,
  required List<CounterType> activeCounters,
  required Map<String, int> counters,
  required bool isMonarch,
  required bool isEliminated,
  required void Function(String counterId, int delta) onCounterDelta,
  required VoidCallback onToggleMonarch,
  required VoidCallback onEliminate,
  required VoidCallback onResetCounters,
  required List<CommanderDamageOpponent> commanderDamage,
  required void Function(int sourcePlayerId, int delta) onCommanderDamageDelta,
  required int lethalCommanderDamage,
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
      activeCounters: activeCounters,
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
      commanderDamage: commanderDamage,
      // Contrairement aux autres actions, taper ± sur la grille ne ferme
      // pas le tiroir (spec §2.7 : « filet de rattrapage » consulté à
      // chaud, éventuellement plusieurs fois).
      onCommanderDamageDelta: onCommanderDamageDelta,
      lethalCommanderDamage: lethalCommanderDamage,
    ),
  );
}

class _PlayerDrawerBody extends StatefulWidget {
  const _PlayerDrawerBody({
    required this.playerName,
    required this.activeCounters,
    required this.counters,
    required this.isMonarch,
    required this.isEliminated,
    required this.onCounterDelta,
    required this.onToggleMonarch,
    required this.onEliminate,
    required this.onResetCounters,
    required this.commanderDamage,
    required this.onCommanderDamageDelta,
    required this.lethalCommanderDamage,
  });

  final String playerName;

  /// Compteurs actifs de la session, dans l'ordre d'affichage voulu
  /// (`GameSession.activeCounterIds`, résolus en `CounterType` par
  /// l'appelant) — pas l'ordre du catalogue.
  final List<CounterType> activeCounters;
  final Map<String, int> counters;
  final bool isMonarch;
  final bool isEliminated;
  final void Function(String counterId, int delta) onCounterDelta;
  final VoidCallback onToggleMonarch;
  final VoidCallback onEliminate;
  final VoidCallback onResetCounters;
  final List<CommanderDamageOpponent> commanderDamage;
  final void Function(int sourcePlayerId, int delta) onCommanderDamageDelta;
  final int lethalCommanderDamage;

  @override
  State<_PlayerDrawerBody> createState() => _PlayerDrawerBodyState();
}

class _PlayerDrawerBodyState extends State<_PlayerDrawerBody> {
  /// Copie locale : le tiroir reste ouvert pendant qu'on incrémente, et doit
  /// refléter le changement immédiatement sans attendre un rebuild de la page.
  late final Map<String, int> _values = Map<String, int>.from(widget.counters);

  /// Même raison qu'au-dessus, pour les totaux de la grille de dégâts de
  /// commandant reçus.
  late final List<CommanderDamageOpponent> _commanderDamage =
      List<CommanderDamageOpponent>.from(widget.commanderDamage);

  void _bump(String id, int delta) {
    setState(() {
      _values[id] = ((_values[id] ?? 0) + delta).clamp(0, 99);
    });
    widget.onCounterDelta(id, delta);
  }

  void _bumpCommanderDamage(int sourcePlayerId, int delta) {
    setState(() {
      final index = _commanderDamage.indexWhere(
        (o) => o.playerId == sourcePlayerId,
      );
      if (index != -1) {
        final current = _commanderDamage[index];
        _commanderDamage[index] = CommanderDamageOpponent(
          playerId: current.playerId,
          name: current.name,
          colorValue: current.colorValue,
          damage: (current.damage + delta).clamp(0, 999),
        );
      }
    });
    widget.onCommanderDamageDelta(sourcePlayerId, delta);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        // La grille de dégâts de commandant reçus (lot 3) ajoute une ligne
        // par adversaire : à 8 joueurs, compteurs + grille + actions ne
        // tiennent plus dans un tiroir non scrollable. `SingleChildScrollView`
        // laisse le contenu déborder proprement plutôt que de le tronquer.
        child: SingleChildScrollView(
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
              for (final type in widget.activeCounters) _counterRow(type),
              // Ronde de correction 1 (Important, "seconde porte") : la
              // grille n'etait conditionnee par rien -- ni le seuil letal,
              // ni les compteurs actives par le format -- et s'affichait
              // donc meme en Standard. `lethalCommanderDamage <= 0` (0 =
              // desactive, voir GameFormat.maxCommanderDamage) est le meme
              // garde que celui qui protege deja la rangee d'attribution du
              // cadran cote page.
              if (widget.lethalCommanderDamage > 0) ...[
                const Divider(height: 26),
                CommanderDamageGrid(
                  opponents: _commanderDamage,
                  lethalThreshold: widget.lethalCommanderDamage,
                  onDelta: _bumpCommanderDamage,
                ),
              ],
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
      ),
    );
  }

  Widget _counterRow(CounterType type) {
    final id = type.id;
    // Clé posée sur la ligne entière (pas seulement les boutons) : c'est
    // elle que les tests ciblent pour vérifier QUEL compteur a bougé,
    // conformément au brief (ValueKey('counter_row_<id>')) — le même motif
    // que le bug du lot 4 sur le bouton "−" (bon nombre de lignes, mauvais
    // joueur) mais appliqué aux compteurs plutôt qu'aux joueurs.
    return Padding(
      key: ValueKey('counter_row_$id'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(type.name, style: AppTextStyles.body()),
          ),
          IconButton(
            key: ValueKey('counter_row_${id}_minus'),
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
            key: ValueKey('counter_row_${id}_plus'),
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
