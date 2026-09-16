// lib/widgets/life_counter/zone/conditional_handle.dart
// Poignée conditionnelle (spec §2.2).
//
// Trait fin quand tous les compteurs sont à zéro ; bandeau résumé dès que l'un
// bouge. Le changement de forme est lui-même un signal : le joueur voit du coin
// de l'œil qu'il lui est arrivé quelque chose, sans lire un chiffre.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';

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
    this.tier = DensityTier.compact,
  });

  final CounterSummary summary;
  final VoidCallback? onTap;

  /// Cran de densite de la zone (tache 4 du lot 6) : decide de la hauteur
  /// effective via `handleHeightFor` et, en cran minimal, rend le bandeau
  /// muet (voir `_band` ci-dessous) — jamais l'inverse, la densite ne
  /// masque jamais la cible tactile elle-meme.
  final DensityTier tier;

  /// Plancher historique (lot 2) : la hauteur ne descend jamais en dessous,
  /// quel que soit le cran. Depuis la tache 4, ce n'est plus la hauteur
  /// EFFECTIVE de la poignee -- c'est `handleHeightFor(tier)` -- mais reste
  /// exposee pour d'autres eventuels lecteurs (aucun a ce jour, voir
  /// `grep -rn "reservedHeight" lib/`).
  static const double reservedHeight = 30.0;

  @override
  Widget build(BuildContext context) {
    // En cran minimal, le bandeau de compteurs est muet : seul le grip
    // reste visible, quel que soit `summary.isCalm`. La cible tactile,
    // elle, ne retrecit jamais (contrainte globale 2 : `tester.tap` doit
    // toujours pouvoir l'atteindre).
    final bool showGripOnly = tier == DensityTier.minimal || summary.isCalm;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: handleHeightFor(tier),
        child: showGripOnly ? _grip() : _band(),
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
