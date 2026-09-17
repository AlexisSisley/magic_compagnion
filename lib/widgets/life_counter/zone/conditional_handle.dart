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
  /// Une `List<MapEntry<...>>`, pas une `Map<CounterType, int>` : au moment
  /// où ce choix a été fait, `CounterType` ne redéfinissait ni `==` ni
  /// `hashCode` (identité par défaut), donc une clé de `Map` n'aurait été
  /// fiable que si chaque appelant réutilisait scrupuleusement la même
  /// instance. `CounterType` porte désormais une égalité de valeur fondée
  /// sur `id` (lot 5, tâche 4, AJOUT 2) -- ce qui lèverait cette contrainte
  /// -- mais rien n'imposait de rouvrir cette représentation pour autant :
  /// une `List` énumère des paires sans avoir besoin d'aucune des deux
  /// garanties.
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
  /// disposition de la table en dérive `kZoneShortEdgeFloor`, qui gouverne à
  /// son tour si une zone peut recevoir une colonne latérale.
  ///
  /// Volontairement, ce commentaire ne recopie NI la somme NI le total : ces
  /// valeurs vivent là-bas et y ont déjà bougé une fois (l'en-tête est passé
  /// de 40 à 48, mesuré sur la cible minimale d'un `IconButton` Material,
  /// donc le plancher de 70 à 78). Un nombre recopié ici se périmerait en
  /// silence — c'est exactement le défaut qui a valu au lot 6 de devoir
  /// dériver `kZoneShortEdgeFloor` au lieu de le figer.
  ///
  /// Si le contenu de la poignée manque de place, la réponse est
  /// `maxVisibleChips` ci-dessus, jamais cette constante.
  static const double reservedHeight = 30.0;

  /// Clé du marqueur minimal non textuel (voir `_overflowMarker`) rendu à la
  /// place du "+N" quand même celui-ci ne tient plus dans la largeur
  /// disponible (ronde de correction 2, Critical 1). Publique pour que les
  /// tests puissent le distinguer d'une puce normale sans dépendre d'un type
  /// privé.
  static const overflowMarkerKey = ValueKey('conditional_handle_overflow_marker');

  /// Marge de sécurité entre la mesure isolée d'une puce (`TextPainter`,
  /// posé sans contrainte, voir `_chipTextWidth`) et sa mise en page réelle
  /// (le même `Text`, empaqueté dans un `Padding` puis dans une `Row`
  /// contrainte par la largeur disponible) : les deux ne se posent jamais
  /// tout à fait pareil.
  ///
  /// Ronde de correction 3 : la revue a mesuré un écart d'environ 1,5px
  /// entre les deux, concentré dans une bande étroite de largeurs
  /// (~88,5-90px dans son scénario), où la mesure isolée répondait « ça
  /// tient » alors que le rendu réel débordait de 0,5 à 1,5px -- ni un
  /// problème de police, ni de direction de texte (vérifié dans les deux
  /// sens). `2.0` arrondit cet écart mesuré au pixel logique supérieur :
  /// large marge sur ~1,5px sans retirer une puce plus tôt que nécessaire
  /// dans les cas usuels.
  static const double _layoutSafetyMargin = 2.0;

  /// Résout le compteur intégré 'commander_damage' du catalogue (revue
  /// finale, petite chose 3) : le pire dégât de commandant reste représenté
  /// à part de `summary.counters` (voir le doc-comment de `CounterSummary`
  /// -- ce n'est pas un compteur de `PlayerState.counters`, c'est un
  /// maximum calculé sur `commanderDamageReceived`), mais son GLYPHE et sa
  /// COULEUR n'ont aucune raison de vivre ailleurs que dans le même
  /// catalogue que tous les autres. `CounterType.builtInCounters` est une
  /// liste fixe de 4 entrées connues (poison/energy/commander_tax/
  /// commander_damage) : un `firstWhere` sans `orElse` est sûr ici, même
  /// principe que `player_zone._builtInCounterType`.
  CounterType get _commanderDamageType => CounterType.builtInCounters
      .firstWhere((c) => c.id == 'commander_damage');

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
    // Ronde de correction 1 : `maxVisibleChips` bornait le NOMBRE de puces,
    // mais `Row(mainAxisSize: min)` dans un `Container` sans contrainte de
    // largeur ne protégeait de rien si ce nombre-là ne tenait pas dans la
    // largeur réelle -- un `RenderFlex overflowed`, silencieux en release
    // (clipping), dès qu'une session monte `maxVisibleChips` pour un cran de
    // densité plus dense que ce que `maxVisibleChips` seul anticipait.
    // `LayoutBuilder` donne la largeur réellement disponible à `_fitChips`,
    // qui l'utilise pour réduire encore le nombre de puces RENDUES si
    // besoin (voir son doc-comment) -- jamais pour les faire défiler ni
    // rétrécir sous le seuil lisible.
    //
    // Ronde de correction 2, Critical 2 : `MediaQuery.textScalerOf(context)`
    // -- pas l'échelle 1.0 implicite d'un `TextPainter` par défaut -- est
    // transmis à la mesure, pour qu'un réglage d'accessibilité "grand
    // texte" (parfaitement ordinaire) ne fasse pas mentir la mesure sur ce
    // qui tient réellement à l'écran.
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = _fitChips(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context),
        );
        return Container(
          decoration: BoxDecoration(
            // greyShade800 est un getter (app_colors.dart:180), pas une
            // constante : ce BoxDecoration ne peut donc pas etre const.
            border: Border(top: BorderSide(color: AppColors.greyShade800)),
          ),
          alignment: Alignment.center,
          child: fit.useMarker
              ? _overflowMarker(constraints.maxWidth)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: fit.chips,
                ),
        );
      },
    );
  }

  /// Défaut PROVISOIRE (voir le doc-comment de `maxVisibleChips`) :
  /// priorisation par gravité -- valeur décroissante, le dégât de
  /// commandant inclus dans le même tri -- puis troncature "+N" au-delà de
  /// `maxVisibleChips`. Tri stable : à égalité de valeur, le dégât de
  /// commandant garde la priorité historique (il passait avant l'énergie et
  /// la taxe dans l'ancien ordre fixe), puis l'ordre d'insertion de
  /// `summary.counters`.
  ///
  /// Deux passes de troncature, pas une seule : `maxVisibleChips` borne
  /// d'abord le NOMBRE de puces (comportement historique) ; si ce qui reste
  /// -- puces affichées + `"+N"` le cas échéant -- ne tient toujours pas
  /// dans `maxWidth`, les puces les moins graves cèdent une à une leur
  /// place au `"+N"`, qui recompte alors TOUTES celles qui manquent (pas
  /// seulement celles que `maxVisibleChips` avait écartées). Si même le
  /// `"+N"` seul ne tient plus, un marqueur minimal non textuel
  /// (`_overflowMarker`) prend sa place -- jamais de défilement, jamais de
  /// puce rétrécie sous le seuil lisible.
  ///
  /// **Ce que cette méthode garantit, et ce qu'elle ne garantit PAS**
  /// (ronde de correction 3, après un troisième débordement, sous-pixel
  /// celui-là, trouvé par la revue) : c'est une troncature par largeur
  /// MESURÉE, avec `_layoutSafetyMargin` en coussin -- elle vise l'absence
  /// de débordement VISIBLE, pas une garantie exacte au pixel. La mesure
  /// (`_chipTextWidth`, un `TextPainter` isolé sans contrainte) et la mise
  /// en page réelle (les mêmes `Text` empaquetés dans des `Padding` puis
  /// dans la `Row` contrainte de `_band`) ne se posent jamais tout à fait
  /// pareil ; la marge absorbe cet écart plutôt que de prétendre le
  /// supprimer. Un précédent commentaire ici annonçait « aucun débordement,
  /// à aucune largeur » -- c'était faux (un écart sous-pixel est passé au
  /// travers, voir le rapport de la ronde 3) et c'est cette formulation,
  /// pas le mécanisme, qu'il fallait corriger.
  _ChipsFit _fitChips(double maxWidth, TextScaler textScaler) {
    final entries = <_ChipData>[
      // Revue finale (petite chose 3) : dérivait un glyphe ('⚔', sans le
      // sélecteur de variante emoji) et une couleur (`AppColors.accentRed`,
      // `Colors.redAccent`) écrits en dur ici -- une seconde source pour la
      // même information que `CounterType.builtInCounters` porte déjà pour
      // l'id 'commander_damage' (emoji '⚔️', couleur 0xFFF44336), et
      // divergente de celle-ci. Alignée sur le catalogue.
      if (summary.worstCommanderDamage > 0)
        _ChipData(
          _commanderDamageType.emoji,
          summary.worstCommanderDamage,
          Color(_commanderDamageType.color),
        ),
      for (final entry in summary._nonZeroCounters)
        _ChipData(entry.key.emoji, entry.value, Color(entry.key.color)),
    ]..sort((a, b) => b.value.compareTo(a.value));

    final baseShowCount = entries.length <= maxVisibleChips
        ? entries.length
        : (maxVisibleChips > 0 ? maxVisibleChips - 1 : 0);

    var shown = entries.take(baseShowCount).toList();
    var hiddenCount = entries.length - shown.length;

    if (maxWidth.isFinite) {
      // Le budget retranche `_layoutSafetyMargin` à `maxWidth` : on exige
      // que le contenu tienne dans la largeur disponible MOINS ce coussin,
      // pas exactement dedans (voir le doc-comment de la méthode et de
      // `_layoutSafetyMargin`).
      final budget = maxWidth - _layoutSafetyMargin;

      while (shown.isNotEmpty &&
          _rowWidth(shown, hiddenCount, textScaler) > budget) {
        shown = shown.sublist(0, shown.length - 1);
        hiddenCount = entries.length - shown.length;
      }

      // Le "+N" seul peut encore déborder : la boucle ci-dessus s'arrête
      // dès que `shown` est vide sans jamais vérifier que le "+N" restant,
      // seul, tient dans le budget.
      if (hiddenCount > 0 &&
          _rowWidth(const [], hiddenCount, textScaler) > budget) {
        return const _ChipsFit.marker();
      }
    }

    return _ChipsFit.chips([
      for (final e in shown) _chip(e.glyph, e.value, e.color),
      if (hiddenCount > 0) _overflowChip(hiddenCount),
    ]);
  }

  /// Largeur totale qu'occuperait la bande pour ces puces (padding
  /// horizontal des `Padding` de `_chip`/`_overflowChip` inclus), en comptant
  /// le "+N" s'il y en a un -- c'est cette largeur que `_fitChips` compare
  /// à `maxWidth` pour décider si une puce de plus doit céder sa place.
  double _rowWidth(
    List<_ChipData> shown,
    int hiddenCount,
    TextScaler textScaler,
  ) {
    var total = 0.0;
    for (final e in shown) {
      total += _chipTextWidth('${e.glyph} ${e.value}', textScaler);
    }
    if (hiddenCount > 0) {
      total += _chipTextWidth('+$hiddenCount', textScaler);
    }
    return total;
  }

  /// Largeur mesurée d'un texte de puce avec la même police que
  /// `_chip`/`_overflowChip` (la couleur n'affecte pas la métrique du
  /// texte, donc la couleur par défaut de `lifeHandleChip` suffit ici),
  /// plus les 12px de `Padding` horizontal (6 de chaque côté) qui
  /// l'entourent dans la puce réelle.
  ///
  /// `textScaler` DOIT être celui de `MediaQuery.textScalerOf(context)`,
  /// pas la valeur par défaut (échelle 1.0) d'un `TextPainter` -- sans quoi
  /// cette mesure sous-estime la largeur d'un `Text` réellement rendu sous
  /// un réglage d'accessibilité "grand texte" (ronde de correction 2,
  /// Critical 2), et laisse passer un débordement que la mesure affirmait
  /// pourtant impossible.
  double _chipTextWidth(String text, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: AppTextStyles.lifeHandleChip()),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return painter.width + 12;
  }

  /// Marqueur minimal NON textuel, rendu quand même le "+N" ne tient plus
  /// dans `maxWidth` (ronde de correction 2, Critical 1).
  ///
  /// Décision consignée dans le rapport de cette ronde : à cette largeur,
  /// il n'y a littéralement plus la place de COMPTER -- la règle du lot
  /// (« un contenu qui ne tient pas se compte, il ne se cache pas ») ne
  /// peut plus être tenue à la lettre. Ce point ne prétend dire ni quoi ni
  /// combien ; il signale seulement « il se passe quelque chose ici », ce
  /// qui reste honnête là où un texte tronqué ou un vide silencieux
  /// mentirait par excès ou par omission. Sa taille est explicitement
  /// bornée par `maxWidth` (`clamp`), jamais par sa seule taille
  /// préférée : un `Container`/`Align` ne lève pas l'assertion
  /// `RenderFlex overflowed` comme une `Row`, mais peindrait quand même
  /// hors de ses limites sans ce `clamp` -- la même famille de défaut que
  /// ce que cette ronde corrige.
  Widget _overflowMarker(double maxWidth) {
    final size = maxWidth.isFinite ? maxWidth.clamp(0.0, 8.0) : 8.0;
    return Container(
      key: overflowMarkerKey,
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.accentRed,
        shape: BoxShape.circle,
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

/// Résultat de `_fitChips` : soit une liste de puces (éventuellement suivie
/// du "+N") qui tient dans `maxWidth`, soit -- dernier recours, ronde de
/// correction 2 -- le marqueur minimal non textuel quand même le "+N" seul
/// ne tiendrait pas.
class _ChipsFit {
  const _ChipsFit.chips(this.chips) : useMarker = false;
  const _ChipsFit.marker()
      : chips = const [],
        useMarker = true;

  final List<Widget> chips;
  final bool useMarker;
}
