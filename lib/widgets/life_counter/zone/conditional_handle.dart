// lib/widgets/life_counter/zone/conditional_handle.dart
// Poignée conditionnelle (spec §2.2).
//
// Trait fin quand tous les compteurs sont à zéro ; bandeau résumé dès que l'un
// bouge. Le changement de forme est lui-même un signal : le joueur voit du coin
// de l'œil qu'il lui est arrivé quelque chose, sans lire un chiffre.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import '../layouts/density_tier.dart';

/// Ce qui menace un joueur, condensé.
class CounterSummary {
  const CounterSummary({
    this.poison = 0,
    this.energy = 0,
    this.commanderTax = 0,
    this.worstCommanderDamage = 0,
  });

  final int poison;
  final int energy;
  final int commanderTax;

  /// Le plus gros total de dégâts de commandant reçu d'une seule source.
  final int worstCommanderDamage;

  bool get isCalm =>
      poison == 0 &&
      energy == 0 &&
      commanderTax == 0 &&
      worstCommanderDamage == 0;
}

class ConditionalHandle extends StatelessWidget {
  const ConditionalHandle({
    super.key,
    required this.summary,
    this.onTap,
    this.height = reservedHeight,
    this.showSummary = true,
  });

  final CounterSummary summary;
  final VoidCallback? onTap;

  /// Hauteur effective de la poignée (tâche 2 : dépend du `DensityTier` de la
  /// zone parente, via `handleHeightFor`). Reste au-dessus de [reservedHeight]
  /// par construction de `handleHeightFor` — voir `density_tier.dart`.
  final double height;

  /// Sous le cran `comfort` (voir `DensityTier`), la zone n'a plus la place
  /// d'afficher le résumé des compteurs secondaires : la poignée reste un
  /// simple trait, tout en restant un point d'entrée tactile vers le tiroir.
  final bool showSummary;

  /// Hauteur minimale, calme ou non, en dessous de laquelle la poignée
  /// devient impossible à attraper. DÉRIVÉE de `density_tier.dart`, jamais
  /// recopiée : c'est le même 30 px que `kZoneHandleHeight`.
  static const double reservedHeight = kZoneHandleHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: (showSummary && !summary.isCalm) ? _band() : _grip(),
      ),
    );
  }

  Widget _grip() {
    return Center(
      child: Container(
        width: 34,
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.greyShade800,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _band() {
    final parts = <Widget>[
      if (summary.poison > 0)
        _chip('☠', summary.poison, AppColors.accentGreen),
      if (summary.worstCommanderDamage > 0)
        _chip('⚔', summary.worstCommanderDamage, AppColors.accentRed),
      if (summary.energy > 0) _chip('⚡', summary.energy, AppColors.accent),
      if (summary.commanderTax > 0)
        _chip('⬆', summary.commanderTax, AppColors.amber),
    ];

    return Container(
      decoration: BoxDecoration(
        // greyShade800 est un getter (app_colors.dart:180), pas une constante :
        // ce BoxDecoration ne peut donc pas etre const.
        border: Border(top: BorderSide(color: AppColors.greyShade800)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: parts,
      ),
    );
  }

  Widget _chip(String glyph, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '$glyph $value',
        style: AppTextStyles.lifeHandleChip(color: color),
      ),
    );
  }
}
