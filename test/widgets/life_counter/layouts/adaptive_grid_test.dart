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

    testWidgets(
        'à 4 joueurs sur tablette en paysage, deux zones occupent les bords',
        (tester) async {
      _setScreenSize(tester, const Size(1180, 820));
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      await tester.pumpAndSettle();

      // seatsFor(4) place l'index 1 à droite et l'index 3 à gauche (indices
      // 0 et 2 restant au centre, haut et bas).
      final leftDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_3'))).dx;
      final rightDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_1'))).dx;
      final topDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_0'))).dx;
      final bottomDx =
          tester.getCenter(find.byKey(const ValueKey('grid_slot_2'))).dx;

      expect(leftDx, lessThan(topDx));
      expect(leftDx, lessThan(bottomDx));
      expect(leftDx, lessThan(rightDx));
      expect(rightDx, greaterThan(topDx));
      expect(rightDx, greaterThan(bottomDx));
      expect(rightDx, greaterThan(leftDx));
    });

    testWidgets(
        'la largeur de colonne rendue est celle que tableLayoutFor a '
        'décidée', (tester) async {
      const size = Size(1180, 820);
      _setScreenSize(tester, size);
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      await tester.pumpAndSettle();

      final expectedWidth = tableLayoutFor(size, 4).sideWidth;
      final renderedWidth =
          tester.getSize(find.byKey(const ValueKey('grid_slot_3'))).width;

      expect(renderedWidth, closeTo(expectedWidth, 1.0));
    });

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
