// lib/widgets/life_counter/zone/conditional_handle.dart
// Poignée conditionnelle (spec §2.2).
//
// Trait fin quand tous les compteurs sont à zéro ; bandeau résumé dès que l'un
// bouge. Le changement de forme est lui-même un signal : le joueur voit du coin
// de l'œil qu'il lui est arrivé quelque chose, sans lire un chiffre.
//
// Lot 5, tâche 3b — `CounterSummary` portait quatre champs nommés fixes
// (poison/energy/commanderTax/worstCommanderDamage) : un compteur
// personnalisé ne pouvait donc STRUCTURELLEMENT jamais y apparaître, quel
// que soit ce que la session lui passait. Il porte désormais une collection
// de paires (`CounterType`, valeur) -- plus le pire dégât de commandant, qui
// reste à part : ce n'est pas un compteur de `PlayerState.counters`, mais
// un maximum calculé sur `commanderDamageReceived`.

import 'package:flutter/material.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Ce qui menace un joueur, condensé.
class CounterSummary {
  const CounterSummary({
    this.counters = const [],
    this.worstCommanderDamage = 0,
  });

  /// Compteurs actifs de la session, avec leur valeur -- y compris celles à
  /// zéro : c'est `CounterSummary` qui filtre les non-nulles (pour `isCalm`
  /// et pour l'affichage), pas l'appelant.
  ///
  /// Une `List<MapEntry<...>>`, pas une `Map<CounterType, int>` : `CounterType`
  /// ne redéfinit ni `==` ni `hashCode` (identité par défaut), donc une clé
  /// de `Map` ne serait fiable que si chaque appelant réutilise
  /// scrupuleusement la même instance -- une `List` n'a pas besoin de cette
  /// garantie pour se contenter d'énumérer des paires.
  final List<MapEntry<CounterType, int>> counters;

  /// Le plus gros total de dégâts de commandant reçu d'une seule source.
  final int worstCommanderDamage;

  Iterable<MapEntry<CounterType, int>> get _nonZeroCounters =>
      counters.where((entry) => entry.value != 0);

  bool get isCalm => _nonZeroCounters.isEmpty && worstCommanderDamage == 0;
}

class ConditionalHandle extends StatelessWidget {
  const ConditionalHandle({
    super.key,
    required this.summary,
    this.onTap,
    this.maxVisibleChips = 4,
  });

  final CounterSummary summary;
  final VoidCallback? onTap;

  /// Nombre maximal de puces rendues avant troncature en "+N" (voir
  /// `_visibleChips`).
  ///
  /// PARAMÉTRABLE À DESSEIN, à ne pas figer : la poignée peut désormais
  /// recevoir n'importe quel nombre de compteurs (compteurs personnalisés),
  /// et la largeur disponible varie selon le cran de densité choisi par la
  /// disposition de la table. Ce fichier ne sait que résumer N compteurs ;
  /// combien en montrer à chaque cran est une décision de mise en page qui
  /// revient à la session qui refond cette disposition, sur sa maquette --
  /// pas à ce widget.
  ///
  /// Le défaut ci-dessous (4, la limite historique à quatre champs fixes)
  /// est PROVISOIRE : priorisation par gravité (valeur décroissante) puis
  /// troncature "+N". Ce qui, en revanche, n'est pas provisoire : jamais de
  /// défilement (une bande de 30px qui défile est indécouvrable -- c'est
  /// exactement le mécanisme qui a fait revenir en arrière le lot 6, une
  /// barre d'actions scrollable cachant des icônes sans aucune affordance),
  /// et jamais de puce réduite sous le seuil lisible. Un contenu qui ne
  /// tient pas se compte, il ne se cache pas.
  final int maxVisibleChips;

  /// Hauteur réservée en permanence, calme ou non. Sans réservation, la zone
  /// changerait de hauteur utile en cours de partie et le chiffre de PV
  /// sauterait — visible surtout à 8 joueurs sur petit écran.
  ///
  /// NE PAS CHANGER cette valeur sans concertation : le chantier de
  /// disposition de la table (lot 6) en dérive `kZoneShortEdgeFloor`
  /// (en-tête 40 + poignée 30 = 70), qui gouverne à son tour si une zone
  /// peut recevoir une colonne latérale. Si le contenu de la poignée manque
  /// de place, la réponse est `maxVisibleChips` ci-dessus, jamais cette
  /// constante.
  static const double reservedHeight = 30.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: reservedHeight,
        child: summary.isCalm ? _grip() : _band(),
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
        children: _visibleChips(),
      ),
    );
  }

  /// Défaut PROVISOIRE (voir le doc-comment de `maxVisibleChips`) :
  /// priorisation par gravité -- valeur décroissante, le dégât de
  /// commandant inclus dans le même tri -- puis troncature "+N" au-delà de
  /// `maxVisibleChips`. Tri stable : à égalité de valeur, le dégât de
  /// commandant garde la priorité historique (il passait avant l'énergie et
  /// la taxe dans l'ancien ordre fixe), puis l'ordre d'insertion de
  /// `summary.counters`.
  List<Widget> _visibleChips() {
    final entries = <_ChipData>[
      if (summary.worstCommanderDamage > 0)
        _ChipData('⚔', summary.worstCommanderDamage, AppColors.accentRed),
      for (final entry in summary._nonZeroCounters)
        _ChipData(entry.key.emoji, entry.value, Color(entry.key.color)),
    ]..sort((a, b) => b.value.compareTo(a.value));

    if (entries.length <= maxVisibleChips) {
      return [for (final e in entries) _chip(e.glyph, e.value, e.color)];
    }

    // Jamais de défilement : le surplus qui ne tient pas se compte dans un
    // "+N", il ne se cache pas derrière une bande qui défile.
    final showCount = maxVisibleChips > 0 ? maxVisibleChips - 1 : 0;
    final shown = entries.take(showCount);
    final hiddenCount = entries.length - shown.length;
    return [
      for (final e in shown) _chip(e.glyph, e.value, e.color),
      _overflowChip(hiddenCount),
    ];
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

  Widget _overflowChip(int hiddenCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '+$hiddenCount',
        style: AppTextStyles.lifeHandleChip(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ChipData {
  const _ChipData(this.glyph, this.value, this.color);
  final String glyph;
  final int value;
  final Color color;
}
