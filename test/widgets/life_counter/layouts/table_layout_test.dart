import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';
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

    test('téléphone en paysage : colonnes latérales', () {
      expect(tableLayoutFor(phoneLandscape, 4).useSideColumns, isTrue);
    });

    test('tablette en portrait : colonnes latérales malgré le portrait', () {
      expect(tableLayoutFor(tabletPortrait, 4).useSideColumns, isTrue);
    });

    test('tablette en paysage : colonnes latérales', () {
      expect(tableLayoutFor(tabletLandscape, 4).useSideColumns, isTrue);
    });

    test('5 et 6 joueurs ont aussi des colonnes latérales', () {
      expect(tableLayoutFor(tabletLandscape, 5).useSideColumns, isTrue);
      expect(tableLayoutFor(tabletLandscape, 6).useSideColumns, isTrue);
    });
  });

  group('on renonce, on ne rétrécit pas (spec §3.3)', () {
    test('le repli renvoie des sièges face à face, pas des colonnes étroites', () {
      final layout = tableLayoutFor(phonePortrait, 4);
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

    test('un écran trop étroit pour le budget renonce aux côtés', () {
      // 340 de large en paysage (340 > 300) : petit côté 300 < 600, donc hub
      // (centreNeed = 160). Budget : 340 - 192 = 148 < 160, donc repli par
      // le budget et par lui seul.
      expect(tableLayoutFor(const Size(340, 300), 4).useSideColumns, isFalse);
    });
  });

  group('forme de la barre (spec §4.2)', () {
    test('téléphone : hub', () {
      expect(tableLayoutFor(phonePortrait, 4).barKind, ActionBarKind.hub);
      expect(tableLayoutFor(phoneLandscape, 4).barKind, ActionBarKind.hub);
    });

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

    test('au seuil exact de grand écran, la bande est choisie et tient', () {
      // Size(600, 600) : petit côté = 600, donc shortEdge >= kLargeScreenShortEdge
      // → barKind = band (ce choix ne dépend jamais du budget des colonnes,
      // voir `tableLayoutFor`).
      //
      // Ronde de correction 1 (option C) : `kActionWidth` est passé de 36 à
      // 48 (la vraie taille minimale d'un `IconButton` Material -- 36 était
      // faux, voir `kActionWidth` dans `table_layout.dart`). `kBandNeed` en
      // dérive : 9 × (48 + 4) + 4 = 472. Budget des colonnes latérales :
      // 600 - 192 = 408 < 472 -- IL NE PASSE PLUS. Ici, `tableLayoutFor`
      // renonce donc aux colonnes (repli), et le centre qui reste à la bande
      // est la largeur ENTIÈRE de l'écran (600), pas un centre réduit par
      // des colonnes : 600 >= 472, la bande tient toujours, mais seule,
      // sans colonnes. C'est la conséquence assumée de la correction : un
      // écran qui ne peut pas payer colonnes ET bande paie la bande d'abord.
      final layout = tableLayoutFor(const Size(600, 600), 4);
      expect(layout.barKind, ActionBarKind.band);
      expect(layout.useSideColumns, isFalse,
          reason: 'à cette largeur, le budget (408px) ne loge plus à la '
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
}
