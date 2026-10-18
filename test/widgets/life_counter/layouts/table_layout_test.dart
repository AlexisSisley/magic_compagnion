import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';
import 'package:magic_companion/widgets/life_counter/zone/action_hub.dart';

const phonePortrait = Size(390, 844);
const phoneLandscape = Size(844, 390);
const tabletPortrait = Size(820, 1180);
const tabletLandscape = Size(1180, 820);

void main() {
  group('condition de forme (spec §3.1)', () {
    test('téléphone en portrait : PAS de colonne latérale, même à 4 joueurs', () {
      expect(tableLayoutFor(phonePortrait, 4).useSideColumns, isFalse);
    });

    // Les trois tests suivants portaient sur 4 joueurs avant la tâche 3.
    // Spec §1.1 : à 4 joueurs, la grille est toujours égale (deux quadrants
    // ou deux colonnes selon la forme de la zone, voir `arrangementFor`) --
    // il n'y a plus JAMAIS de colonne latérale « around » à 4, quel que soit
    // l'écran. Les colonnes latérales ne subsistent qu'à 5 et 6 joueurs, où
    // une grille égale n'est pas réalisable : portés à 5 joueurs ici pour
    // continuer à vérifier la même condition de forme.
    test('téléphone en paysage : colonnes latérales (5 joueurs)', () {
      expect(tableLayoutFor(phoneLandscape, 5).useSideColumns, isTrue);
    });

    test(
        'tablette en portrait : colonnes latérales malgré le portrait '
        '(5 joueurs)', () {
      expect(tableLayoutFor(tabletPortrait, 5).useSideColumns, isTrue);
    });

    test('tablette en paysage : colonnes latérales (5 joueurs)', () {
      expect(tableLayoutFor(tabletLandscape, 5).useSideColumns, isTrue);
    });

    test('à 4 joueurs, aucune colonne latérale sur aucun de ces écrans '
        '(spec §1.1)', () {
      for (final size in [phoneLandscape, tabletPortrait, tabletLandscape]) {
        expect(tableLayoutFor(size, 4).useSideColumns, isFalse,
            reason: '$size');
      }
    });

    test('5 et 6 joueurs ont aussi des colonnes latérales', () {
      expect(tableLayoutFor(tabletLandscape, 5).useSideColumns, isTrue);
      expect(tableLayoutFor(tabletLandscape, 6).useSideColumns, isTrue);
    });
  });

  group('on renonce, on ne rétrécit pas (spec §3.3)', () {
    // Portée à 5 joueurs (spec §1.1) : à 4 joueurs sur cet écran, la zone
    // 195×422 est plus haute que large et la règle du grand côté (§1.4)
    // choisit délibérément `columnPairs` -- un siège `left`/`right` avec un
    // quart de tour y est désormais le comportement VOULU, pas un défaut.
    // Le vrai repli (fallback face-à-face, sans aucun siège latéral) ne
    // s'observe plus qu'au-delà de 4 joueurs, quand `around` est écarté par
    // la condition de forme.
    test('le repli renvoie des sièges face à face, pas des colonnes étroites '
        '(5 joueurs)', () {
      final layout = tableLayoutFor(phonePortrait, 5);
      final sides = layout.seats.map((s) => s.side).toSet();
      expect(sides.contains(TableSide.left), isFalse);
      expect(sides.contains(TableSide.right), isFalse);
      expect(layout.sideWidth, 0.0);
    });

    test('une colonne rendue n\'est JAMAIS sous le plancher', () {
      for (final size in [phoneLandscape, const Size(400, 380), tabletPortrait, tabletLandscape]) {
        for (int n = 2; n <= 8; n++) {
          final layout = tableLayoutFor(size, n);
          if (layout.useSideColumns) {
            expect(layout.sideWidth,
                greaterThanOrEqualTo(kSideColumnNeed),
                reason: '$size à $n joueurs');
          }
        }
      }
    });

    // Portée à 5 joueurs (spec §1.1) : à 4 joueurs, `arrangementFor` ne passe
    // plus jamais par `around`, donc cette condition de budget n'est plus
    // exercée du tout à ce nombre de joueurs -- le test ne prouverait rien.
    test('un écran trop étroit pour le budget renonce aux côtés (5 joueurs)',
        () {
      // 340 de large en paysage (340 > 300) : la forme passe (shapeAllows).
      // Petit côté 300 < 600, donc hub (centreNeed = 160). Budget :
      // 340 - 2×136 = 68 < 160, donc repli par le budget et par lui seul.
      // (kSideColumnNeed = 136 depuis la tâche 3 : dérivé de
      // kCompactShortEdge, pas de kZoneShortEdgeFloor -- voir sa définition.)
      expect(tableLayoutFor(const Size(340, 300), 5).useSideColumns, isFalse);
    });
  });

  group('forme de la barre (spec §4.2)', () {
    test('téléphone : hub', () {
      expect(tableLayoutFor(phonePortrait, 4).barKind, ActionBarKind.hub);
      expect(tableLayoutFor(phoneLandscape, 4).barKind, ActionBarKind.hub);
    });

    // Ruling 21 : `barKind` ne dépend à nouveau que de la forme de l'écran,
    // jamais du nombre de joueurs -- voir le commentaire au-dessus de
    // `barKind` dans `table_layout.dart`. Test original restauré.
    test('tablette : bande', () {
      expect(tableLayoutFor(tabletPortrait, 4).barKind, ActionBarKind.band);
      expect(tableLayoutFor(tabletLandscape, 4).barKind, ActionBarKind.band);
    });

    test('le centre restant loge toujours la bande quand elle est choisie', () {
      for (final size in [tabletPortrait, tabletLandscape]) {
        final layout = tableLayoutFor(size, 4);
        final centre = size.width - 2 * layout.sideWidth;
        expect(centre, greaterThanOrEqualTo(kBandNeed), reason: '$size');
      }
    });

    // Portée à 6 joueurs (spec §1.1) : à 4 joueurs, `arrangementFor` ne
    // passe plus jamais par `around`, donc le seuil de grand écran ne
    // déclenche plus jamais de colonnes latérales à ce nombre de joueurs --
    // le test original ne pouvait plus prouver ce qu'il prétendait prouver.
    test('au seuil exact de grand écran, la bande est choisie et tient '
        '(6 joueurs)', () {
      // Size(600, 600) : petit côté = 600, donc shortEdge >= kLargeScreenShortEdge
      // → barKind = band, quel que soit le nombre de joueurs (ce choix ne
      // dépend jamais du budget des colonnes, voir `tableLayoutFor`).
      //
      // `kBandNeed` = 9 × (48 + 4) + 4 = 472. `kSideColumnNeed` = 136 depuis
      // la tâche 3 (dérivé de `kCompactShortEdge`, plus du plancher absolu).
      // Budget des colonnes latérales : 600 - 2×136 = 328 < 472 -- NE PASSE
      // PAS. `tableLayoutFor` renonce donc aux colonnes (repli), et le
      // centre qui reste à la bande est la largeur ENTIÈRE de l'écran (600),
      // pas un centre réduit par des colonnes : 600 >= 472, la bande tient
      // toujours, mais seule, sans colonnes. C'est la conséquence assumée de
      // la correction : un écran qui ne peut pas payer colonnes ET bande
      // paie la bande d'abord.
      final layout = tableLayoutFor(const Size(600, 600), 6);
      expect(layout.barKind, ActionBarKind.band);
      expect(layout.useSideColumns, isFalse,
          reason: 'à cette largeur, le budget (328px) ne loge plus à la '
              'fois les colonnes latérales ET la bande à 9 actions '
              '(472px) -- les colonnes cèdent, pas la bande');
      final centre = 600.0 - 2 * layout.sideWidth;
      expect(centre, greaterThanOrEqualTo(kBandNeed));
    });
  });

  group('nombres de joueurs sans siège latéral', () {
    for (final n in const [2, 3, 7, 8]) {
      test('$n joueurs : aucune colonne latérale sur aucun écran', () {
        for (final size in [phonePortrait, phoneLandscape, tabletLandscape]) {
          expect(tableLayoutFor(size, n).useSideColumns, isFalse,
              reason: '$size');
        }
      });
    }
  });

  group('kActionWidth reflète la vraie taille rendue (ronde de correction 1)',
      () {
    // Le défaut de cette ronde : `kActionWidth` valait 36.0 alors qu'un
    // `IconButton` Material -- sans style ni contraintes personnalisés,
    // exactement comme `_buildCentralBar` (life_counter_page.dart) construit
    // chaque bouton de la bande -- mesure 48×48 au minimum
    // (`kMinInteractiveDimension`), quoi qu'on lui demande. La constante
    // mentait depuis l'origine de la bande ; `kBandNeed` en dérive et
    // sous-estimait donc sa largeur réelle depuis toujours (marge réelle
    // mesurée à 8 actions : ~10px, jamais vérifiée avant la découverte de ce
    // défaut). Ce test pompe ce MÊME bouton nu et compare sa taille
    // RÉELLEMENT rendue à `kActionWidth` : c'est le seul garde-fou qui
    // aurait attrapé le défaut d'origine, et le seul qui empêche qu'il ne
    // revienne si quelqu'un change un jour le thème global des `IconButton`
    // sans mettre `kActionWidth`/`kBandNeed` à jour en conséquence.
    testWidgets(
        'un IconButton Material par défaut ne mesure jamais moins que kActionWidth',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              key: const ValueKey('measured_action_button'),
              icon: const Icon(Icons.people),
              onPressed: () {},
            ),
          ),
        ),
      );

      final measured = tester.getSize(
        find.byKey(const ValueKey('measured_action_button')),
      );

      expect(measured.width, kActionWidth,
          reason: 'largeur RÉELLEMENT rendue d\'un bouton de bande '
              '(${measured.width}px) vs `kActionWidth` (${kActionWidth}px) '
              '-- si elles divergent, `kBandNeed` sous-estime à nouveau la '
              'largeur réelle de la bande, silencieusement, exactement '
              'comme avant cette ronde de correction');
      expect(measured.height, kActionWidth,
          reason: 'même vérification en hauteur : le bouton mesuré doit '
              'rester carré à la taille que `kActionWidth` affirme');
    });
  });

  // Revue finale (M3) : `kHubNeed` valait 160.0, posé par estimation, sans
  // aucun lien avec le widget qu'il est censé mesurer -- rétrécir le hub
  // n'aurait rien changé à la place qu'on lui réserve. Il dérive désormais de
  // `ActionHub.diameter`, et ce test MESURE le hub rendu, comme le garde-fou
  // de `kActionWidth` mesure un bouton rendu (ruling 16).
  group('kHubNeed reflète la vraie taille rendue du hub (M3)', () {
    testWidgets('le hub rendu tient dans la place que kHubNeed lui réserve',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: ActionHub(actions: [])),
          ),
        ),
      );

      final measured = tester.getSize(find.byType(ActionHub));
      expect(measured.width, ActionHub.diameter,
          reason: 'précondition : le hub mesure bien son diamètre annoncé');
      expect(measured.width, lessThanOrEqualTo(kHubNeed),
          reason: 'largeur RÉELLEMENT rendue du hub (${measured.width}px) vs '
              'la place que kHubNeed lui réserve (${kHubNeed}px) -- si le hub '
              'grandissait au-delà, tableLayoutFor accorderait des colonnes '
              'latérales sur un budget central trop court');
      expect(kHubNeed, greaterThan(ActionHub.diameter),
          reason: 'kHubNeed doit garder une marge autour du hub, pas le '
              'serrer exactement à son diamètre');
    });
  });

  group('règle du grand côté (tâche 3, spec §1.4)', () {
    test('à 4 joueurs sur écran replié, les zones sont en colonnes', () {
      // 390x844 : la zone d'une grille 2x2 fait 195x422, plus haute que large.
      expect(arrangementFor(const Size(390, 844), 4),
          TableArrangement.columnPairs);
    });

    test('à 4 joueurs sur écran déplié, les zones restent en face-à-face', () {
      // 840x700 : la zone fait 420x350, plus large que haute.
      expect(arrangementFor(const Size(840, 700), 4),
          TableArrangement.faceToFace);
    });

    test('columnPairs donne 90° à gauche et 270° à droite', () {
      final seats = seatsForArrangement(4, TableArrangement.columnPairs);
      final left = seats.where((s) => s.side == TableSide.left).toList();
      final right = seats.where((s) => s.side == TableSide.right).toList();
      expect(left, hasLength(2));
      expect(right, hasLength(2));
      expect(left.every((s) => s.quarterTurns == 1), isTrue);
      expect(right.every((s) => s.quarterTurns == 3), isTrue);
    });
  });

  group('équité des surfaces (tâche 3, spec §1.1)', () {
    test('à 4 joueurs, aucune colonne latérale, quel que soit l écran', () {
      for (final size in const [Size(840, 700), Size(390, 844), Size(1280, 800)]) {
        expect(tableLayoutFor(size, 4).useSideColumns, isFalse,
            reason: 'colonnes latérales à 4 joueurs sur $size');
      }
    });

    test('à 3 joueurs, aucune colonne latérale', () {
      expect(tableLayoutFor(const Size(840, 700), 3).useSideColumns, isFalse);
    });

    // Ruling 21 (18/10/2026) : une étape 3bis avait un temps restreint la
    // bande aux dispositions « à frontière pleine largeur » (2 joueurs, et
    // au-delà de 4) -- abandonnée : une fois les zones rendues égales par
    // cette tâche, une bande horizontale entre deux rangées ÉGALES ne lèse
    // plus personne, à 3 et 4 joueurs comme ailleurs. `barKind` ne dépend
    // donc que de la forme de l'écran (voir `tableLayoutFor`), jamais du
    // nombre de joueurs -- le test qui encodait la règle abandonnée a été
    // retiré. La règle ci-dessous, elle, est antérieure à cette erreur et
    // reste vraie : sur petit écran, le hub est la seule forme, quel que
    // soit l'effectif.
    test('sur petit écran, le hub reste la seule forme', () {
      for (int n = 2; n <= 6; n++) {
        expect(tableLayoutFor(const Size(390, 844), n).barKind,
            ActionBarKind.hub);
      }
    });

    test('à 6 joueurs, une colonne doit tenir le cran compact', () {
      final layout = tableLayoutFor(const Size(1280, 800), 6);
      if (layout.useSideColumns) {
        expect(layout.sideWidth, greaterThanOrEqualTo(kSideColumnNeed));
        expect(tierFor(Size(layout.sideWidth, 800)),
            isNot(DensityTier.minimal));
      }
    });
  });
}
