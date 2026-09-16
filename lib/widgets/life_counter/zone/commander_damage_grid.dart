// lib/widgets/life_counter/zone/commander_damage_grid.dart
// Grille de degats de commandant RECUS par le joueur dont le tiroir est
// ouvert (spec S2.7, point 2 : compteurs, puis grille, puis actions).
//
// Le sens compte (dette D2 du plan) : chaque ligne liste un adversaire en
// tant que SOURCE d'un degat que le joueur du tiroir a RECU. `onDelta`
// renvoie l'identifiant de cette source, jamais celui du joueur du tiroir.
// Cote appelant, ca se cable sur
// `addCommanderDamage(targetPlayerId: <joueur du tiroir>, sourcePlayerId:
// <ligne tapee>, damage: delta)` -- l'inverse laisserait la poignee du
// joueur afficher un chiffre que ce tiroir ne peut plus corriger.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Un adversaire, vu comme source de degats de commandant recus par le
/// joueur dont le tiroir est ouvert.
///
/// Reutilise par la tache suivante (rangee d'avatars d'attribution a la
/// volee, spec S2.6) qui n'a besoin que de `playerId`, `name` et
/// `colorValue` -- `damage` reste propre a cette grille.
class CommanderDamageOpponent {
  const CommanderDamageOpponent({
    required this.playerId,
    required this.name,
    required this.colorValue,
    required this.damage,
  });

  final int playerId;
  final String name;
  final int colorValue;
  final int damage;
}

class CommanderDamageGrid extends StatelessWidget {
  const CommanderDamageGrid({
    super.key,
    required this.opponents,
    required this.lethalThreshold,
    required this.onDelta,
  });

  /// Adversaires listés comme sources des dégâts reçus par le joueur du
  /// tiroir. La grille ne filtre rien (élimination, tri...) : c'est
  /// l'appelant qui décide qui figure ici.
  final List<CommanderDamageOpponent> opponents;

  /// Seuil letal d'une source unique (`GameFormat.maxCommanderDamage`).
  /// `0` désactive le signalement (aucune source ne peut être létale).
  final int lethalThreshold;

  /// `sourcePlayerId` est l'identifiant de la ligne tapée -- celui de la
  /// SOURCE du dégât, pas celui du joueur dont le tiroir est ouvert.
  final void Function(int sourcePlayerId, int delta) onDelta;

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final opponent in opponents) _row(opponent)],
    );
  }

  Widget _row(CommanderDamageOpponent opponent) {
    final isLethal =
        lethalThreshold > 0 && opponent.damage >= lethalThreshold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: Color(opponent.colorValue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(opponent.name, style: AppTextStyles.body()),
          ),
          if (isLethal)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.warning_amber_rounded,
                key: ValueKey('commander-damage-lethal-${opponent.playerId}'),
                size: 18,
                color: AppColors.accentRed,
              ),
            ),
          IconButton(
            key: ValueKey('commander-damage-${opponent.playerId}-minus'),
            icon: const Icon(Icons.remove),
            color: AppColors.textSecondary,
            onPressed: () => onDelta(opponent.playerId, -1),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${opponent.damage}',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle(),
            ),
          ),
          IconButton(
            key: ValueKey('commander-damage-${opponent.playerId}-plus'),
            icon: const Icon(Icons.add),
            color: AppColors.textSecondary,
            onPressed: () => onDelta(opponent.playerId, 1),
          ),
        ],
      ),
    );
  }
}
