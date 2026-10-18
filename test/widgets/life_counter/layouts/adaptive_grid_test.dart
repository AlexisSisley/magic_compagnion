import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

/// Construit une [AdaptiveGrid] de test avec [playerCount] zones, chacune un
/// [Container] sans enfant : sans taille propre, il occupe tout l'espace que
/// son parent lui offre, ce qui rend la géométrie rendue entièrement
/// déterminée par `AdaptiveGrid` — exactement ce que ces tests vérifient.
Widget _buildTestGrid({required int playerCount}) {
  final zones = List.generate(
    playerCount,
    (i) => Container(key: ValueKey('zone_content_$i')),
  );
  return MaterialApp(
    home: Scaffold(
      body: AdaptiveGrid(
        playerZones: zones,
        centralBar: const SizedBox(key: ValueKey('central_bar'), height: 40),
        actionHub: const SizedBox(key: ValueKey('hub_content'), width: 48, height: 48),
      ),
    ),
  );
}

/// Impose la taille d'écran logique pour la durée du test, puis la restaure.
void _setScreenSize(WidgetTester tester, Size size) {
  final originalSize = tester.view.physicalSize;
  final originalDpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.physicalSize = originalSize;
    tester.view.devicePixelRatio = originalDpr;
  });
}

void main() {
  group('AdaptiveGrid', () {
    testWidgets('ne contient aucune RotatedBox', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AdaptiveGrid),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
        reason: 'la rotation appartient à PlayerZone, jamais à AdaptiveGrid',
      );
    });

    testWidgets(
        "à 4 joueurs sur téléphone en portrait, aucune zone n'est en "
        'colonne latérale', (tester) async {
      _setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      await tester.pumpAndSettle();

      final widths = [
        for (int i = 0; i < 4; i++)
          tester.getSize(find.byKey(ValueKey('grid_slot_$i'))).width,
      ];

      // Sans colonne latérale, les 4 zones se répartissent en 2×2 (haut /
      // bas) et partagent donc toutes la même largeur. Une colonne latérale,
      // même étroite, romprait cette égalité pour au moins deux d'entre
      // elles.
      for (final width in widths.skip(1)) {
        expect(width, closeTo(widths.first, 0.5));
      }
    });

    // Garde-fou (tâche 3) : avant la correction de cette grille, les sièges
    // `columnPairs` étaient calculés par `tableLayoutFor` mais jamais posés
    // dans l'arbre -- `useSideColumns` étant `false`, la branche qui pose
    // `left`/`right` était sautée et les 4 joueurs disparaissaient purement
    // et simplement sur un écran replié. Ce test MESURE la présence réelle
    // des 4 zones (même famille de garde que `kActionWidth`/`kHubNeed` dans
    // `table_layout_test.dart` : il aurait attrapé le défaut d'origine).
    testWidgets(
        'à 4 joueurs sur téléphone en portrait, les 4 zones sont bien '
        'rendues (columnPairs, spec §1.4)', (tester) async {
      _setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('grid_slot_$i')), findsOneWidget,
            reason: 'zone $i absente de l\'arbre -- colonnes jetées sans '
                'être posées');
      }
    });

    // Portée à 6 joueurs (spec §1.1, tâche 3) : à 4 joueurs, `arrangementFor`
    // ne passe plus jamais par `around` -- la grille reste toujours égale
    // (deux quadrants ou deux colonnes selon la forme de la zone, jamais des
    // bords + un centre). Les colonnes latérales ne subsistent qu'à 5 et 6
    // joueurs, où une grille égale n'est pas réalisable.
    testWidgets(
        'à 6 joueurs sur tablette en paysage, deux zones occupent les bords',
        (tester) async {
      _setScreenSize(tester, const Size(1180, 820));
      await tester.pumpWidget(_buildTestGrid(playerCount: 6));
      await tester.pumpAndSettle();

      // seatsFor(6) = [top, top, right, bottom, bottom, left] : l'index 5 va
      // à gauche, l'index 2 à droite, les index 0/1 au centre en haut et les
      // index 3/4 au centre en bas.
      final leftDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_5'))).dx;
      final rightDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_2'))).dx;
      final topDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_0'))).dx;
      final bottomDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_3'))).dx;

      expect(leftDx, lessThan(topDx));
      expect(leftDx, lessThan(bottomDx));
      expect(leftDx, lessThan(rightDx));
      expect(rightDx, greaterThan(topDx));
      expect(rightDx, greaterThan(bottomDx));
      expect(rightDx, greaterThan(leftDx));
    });

    // Porté à 6 joueurs (spec §1.1, tâche 3) : à 4 joueurs, `useSideColumns`
    // vaut toujours `false` désormais (voir le groupe « équité des surfaces »
    // de `table_layout_test.dart`) -- ce test ne portait plus sur rien à ce
    // nombre de joueurs. (Le test « bande/hub » qui suivait ce groupe, lui,
    // a été restauré à 4 joueurs -- ruling 21 -- puisqu'il ne portait jamais
    // sur les colonnes, seulement sur la forme de l'écran.)
    //
    // Ronde de correction 1 (Critical #2) : à Size(1180, 820) seul,
    // `layout.sideWidth` (= max(136, min(0.17×1180, 354)) = 200.6) coïncide
    // EXACTEMENT avec la fraction naïve 0.17×largeur — la grille redevenue
    // décisionnaire (régression du lot 6) y produirait le même nombre, donc
    // n'importe quel test contre cette seule taille ne peut pas les
    // distinguer. Size(500, 400) est choisie précisément parce que le
    // plancher y mord : la décision correcte vaut max(136, min(85, 170)) =
    // 136, mais 0.17×500 = 85 < 136 -- une grille qui recalculerait
    // elle-même la fraction rendrait un nombre différent, sous le plancher.
    // (kSideColumnNeed = 136 depuis la tâche 3, dérivé de kCompactShortEdge
    // -- voir sa définition dans table_layout.dart.)
    for (final size in [const Size(1180, 820), const Size(500, 400)]) {
      testWidgets(
          'la largeur de colonne rendue est celle que tableLayoutFor a '
          'décidée (${size.width.toInt()}x${size.height.toInt()}, 6 joueurs)',
          (tester) async {
        _setScreenSize(tester, size);
        await tester.pumpWidget(_buildTestGrid(playerCount: 6));
        await tester.pumpAndSettle();

        final expectedWidth = tableLayoutFor(size, 6).sideWidth;
        final renderedWidth =
            tester.getSize(find.byKey(const ValueKey('grid_slot_5'))).width;

        expect(renderedWidth, closeTo(expectedWidth, 1.0));
      });
    }

    // Ruling 21 : `barKind` ne dépend plus du nombre de joueurs -- restauré à
    // 4 joueurs comme à l'origine (ce test n'a jamais porté sur l'équité des
    // colonnes, seulement sur la forme de l'écran).
    testWidgets(
        'la bande centrale est rendue sur tablette, le hub sur téléphone',
        (tester) async {
      _setScreenSize(tester, const Size(1180, 820));
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('action_band')), findsOneWidget);
      expect(find.byKey(const ValueKey('action_hub')), findsNothing);

      _setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('action_hub')), findsOneWidget);
      expect(find.byKey(const ValueKey('action_band')), findsNothing);
    });

    testWidgets('à 8 joueurs, chaque moitié passe en sous-grille 2×2',
        (tester) async {
      // Grand écran : seatsFor(8) ne demande jamais de colonne latérale
      // (playerCount > 6), donc la forme de l'écran n'influe pas ici — seule
      // compte la sous-grille.
      _setScreenSize(tester, const Size(1200, 900));
      await tester.pumpWidget(_buildTestGrid(playerCount: 8));
      await tester.pumpAndSettle();

      final dy0 = tester.getCenter(find.byKey(const ValueKey('grid_slot_0'))).dy;
      final dy1 = tester.getCenter(find.byKey(const ValueKey('grid_slot_1'))).dy;
      final dy2 = tester.getCenter(find.byKey(const ValueKey('grid_slot_2'))).dy;
      final dy3 = tester.getCenter(find.byKey(const ValueKey('grid_slot_3'))).dy;

      // Sous-grille 2×2 : les indices 0 et 1 partagent une rangée, 2 et 3 une
      // autre, et les deux rangées sont à des hauteurs distinctes.
      expect(dy0, closeTo(dy1, 0.5));
      expect(dy2, closeTo(dy3, 0.5));
      expect(dy0, isNot(closeTo(dy2, 0.5)));
    });
  });
}
