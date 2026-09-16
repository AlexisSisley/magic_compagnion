// lib/widgets/life_counter/zone/damage_attribution_row.dart
//
// Rangee d'avatars adverses (spec S2.6), affichee sous le chiffre de vie
// pendant que le buffer de degats (life_counter_page._pendingDamage) tourne.
// Un tap sur un avatar convertit le degat en cours en commander damage de
// CET adversaire -- consommation du montant en attente, jamais addition
// (voir life_counter_page._attributeCommanderDamage, seul appelant reel).
// Aucun tap : le buffer expire normalement en degat generique.
//
// Ne reutilise PAS `CommanderDamageOpponent` (tache 2, commander_damage_grid.dart) :
// son champ `damage` est requis et n'a aucun sens ici (cette rangee ne montre
// aucun total, seulement des cibles possibles). Decision prise pour cette
// tache -- voir le rapport de tache 3.
import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Un adversaire tel qu'affiche par la rangee d'attribution : de quoi
/// dessiner un avatar et transmettre l'identifiant tape, rien de plus.
typedef DamageAttributionOpponent = ({
  int playerId,
  String name,
  int colorValue,
});

class DamageAttributionRow extends StatelessWidget {
  const DamageAttributionRow({
    super.key,
    required this.opponents,
    required this.onAttribute,
  });

  /// Adversaires proposes comme cibles d'attribution. Le widget ne filtre
  /// rien (elimination, tri...) : c'est l'appelant qui decide qui figure ici.
  final List<DamageAttributionOpponent> opponents;

  /// `sourcePlayerId` est l'identifiant de l'avatar tape -- celui de
  /// l'adversaire a qui attribuer le degat en attente.
  final void Function(int sourcePlayerId) onAttribute;

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final opponent in opponents) _avatar(opponent)],
      ),
    );
  }

  Widget _avatar(DamageAttributionOpponent opponent) {
    final initial = opponent.name.isNotEmpty
        ? opponent.name[0].toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        key: ValueKey('damage-attribution-${opponent.playerId}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onAttribute(opponent.playerId),
        child: CircleAvatar(
          radius: 13,
          backgroundColor: Color(opponent.colorValue),
          child: Text(
            initial,
            style: AppTextStyles.label(color: AppColors.textPrimary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
