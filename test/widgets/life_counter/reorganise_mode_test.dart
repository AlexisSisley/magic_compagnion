// test/widgets/life_counter/reorganise_mode_test.dart
//
// Tâche 8a (spec §1.7, §1.9) : le mode réorganisation, au niveau des
// widgets. `DraggablePlayerZone` n'arme le glisser-déposer QUE dans ce mode,
// y pose le sélecteur d'orientation et voile la zone ; `OrientationPicker`
// atteint chaque orientation en une touche ; `ReorganiseBar` porte les
// presets et la sortie. Les tests au niveau de la page (geste de vie,
// adressage par `playerId`, presets réellement appliqués) vivent dans
// test/pages/life_counter/reorganise_mode_page_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/draggable_player_zone.dart';
import 'package:magic_companion/widgets/life_counter/reorganise_bar.dart';
import 'package:magic_companion/widgets/life_counter/zone/orientation_picker.dart';

/// Deux zones côte à côte, pour qu'un glisser ait une cible où se déposer :
/// avec une zone seule, `onReorder` ne serait jamais appelé même en mode
/// réorganisation (une zone refuse son propre index), et le test du mode jeu
/// ne prouverait rien.
Widget _twoZones({
  required bool enabled,
  required void Function(int, int) onReorder,
}) {
  Widget zone(int index) => Expanded(
        child: DraggablePlayerZone(
          index: index,
          enabled: enabled,
          onReorder: onReorder,
          quarterTurns: 0,
          onOrientationChanged: (_) {},
          child: ColoredBox(
            color: Colors.black,
            child: Center(child: Text('Z$index')),
          ),
        ),
      );
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 300,
        child: Row(children: [zone(0), zone(1)]),
      ),
    ),
  );
}

/// Rejoue le vrai geste : appui long d'une seconde (le `delay` de
/// `LongPressDraggable`), puis un glissement en incréments jusqu'à [to].
Future<void> _longPressDrag(
    WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('DraggablePlayerZone — enabled', () {
    testWidgets('hors mode réorganisation, la zone ne se glisse pas',
        (tester) async {
      int reorders = 0;
      await tester.pumpWidget(
          _twoZones(enabled: false, onReorder: (_, _) => reorders++));

      expect(find.byType(LongPressDraggable<int>), findsNothing,
          reason: 'en mode jeu, aucun glisser ne doit être armé');
      expect(find.byType(DragTarget<int>), findsNothing);

      await _longPressDrag(tester, tester.getCenter(find.text('Z0')),
          tester.getCenter(find.text('Z1')));
      expect(reorders, 0, reason: 'le glissement doit être inerte en mode jeu');
    });

    testWidgets(
        'en mode réorganisation, le même geste échange les zones '
        '(contrôle du test précédent)', (tester) async {
      final calls = <(int, int)>[];
      await tester.pumpWidget(
          _twoZones(enabled: true, onReorder: (a, b) => calls.add((a, b))));

      // Départ et arrivée hors du sélecteur (centré) : sur le bord gauche de
      // chaque zone, à mi-hauteur.
      final z0 = tester.getRect(find.byType(DraggablePlayerZone).first);
      final z1 = tester.getRect(find.byType(DraggablePlayerZone).last);
      await _longPressDrag(tester, Offset(z0.left + 20, z0.center.dy),
          Offset(z1.left + 20, z1.center.dy));
      expect(calls, [(0, 1)]);
    });

    testWidgets('en mode réorganisation, le sélecteur d orientation apparaît',
        (tester) async {
      await tester.pumpWidget(_twoZones(enabled: true, onReorder: (_, _) {}));
      expect(find.byType(OrientationPicker), findsNWidgets(2));

      await tester.pumpWidget(_twoZones(enabled: false, onReorder: (_, _) {}));
      expect(find.byType(OrientationPicker), findsNothing,
          reason: 'hors mode, la zone est rendue nue');
    });

    testWidgets(
        'en mode réorganisation, une poignée « Déplacer la zone » de 48×48 '
        'au moins', (tester) async {
      await tester.pumpWidget(_twoZones(enabled: true, onReorder: (_, _) {}));
      final handles = find.byKey(const ValueKey('reorganise-handle'));
      expect(handles, findsNWidgets(2));
      final size = tester.getSize(handles.first);
      expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(find.bySemanticsLabel('Déplacer la zone'), findsNWidgets(2));
    });

    testWidgets(
        'en mode réorganisation, le voile absorbe les touches destinées à la '
        'zone ; hors mode, elles passent', (tester) async {
      int taps = 0;
      Widget build(bool enabled) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 300,
                child: DraggablePlayerZone(
                  index: 0,
                  enabled: enabled,
                  onReorder: (_, _) {},
                  quarterTurns: 0,
                  onOrientationChanged: (_) {},
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          );

      // Coin bas-gauche : ni sur le sélecteur (centré), ni sur la poignée
      // (en haut à gauche).
      final zone = Offset.zero & const Size(300, 300);
      final corner = Offset(zone.left + 20, zone.bottom - 20);

      await tester.pumpWidget(build(true));
      await tester.tapAt(corner);
      await tester.pump();
      expect(taps, 0, reason: 'le geste de la zone est suspendu (spec §1.9)');

      await tester.pumpWidget(build(false));
      await tester.tapAt(corner);
      await tester.pump();
      expect(taps, 1, reason: 'hors mode, la zone répond de nouveau');
    });
  });

  group('OrientationPicker', () {
    Future<List<int>> pumpPicker(WidgetTester tester, int quarterTurns) async {
      final emitted = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: OrientationPicker(
              quarterTurns: quarterTurns,
              onChanged: emitted.add,
            ),
          ),
        ),
      ));
      return emitted;
    }

    Finder arrow(int turns) => find.byKey(ValueKey('orientation-arrow-$turns'));

    testWidgets('chaque flèche émet son quart de tour (▼0 ◀1 ▲2 ▶3)',
        (tester) async {
      final emitted = await pumpPicker(tester, 0);
      for (final turns in const [1, 2, 3, 0]) {
        await tester.tap(arrow(turns));
        await tester.pump();
      }
      expect(emitted, [1, 2, 3, 0]);
    });

    testWidgets('la croix suit la maquette : ▲ en haut, ▼ en bas, ◀ à gauche, '
        '▶ à droite', (tester) async {
      await pumpPicker(tester, 0);
      final up = tester.getCenter(arrow(2));
      final down = tester.getCenter(arrow(0));
      final left = tester.getCenter(arrow(1));
      final right = tester.getCenter(arrow(3));
      expect(up.dy, lessThan(left.dy));
      expect(down.dy, greaterThan(left.dy));
      expect(left.dx, lessThan(up.dx));
      expect(right.dx, greaterThan(up.dx));
      expect(left.dy, right.dy);
    });

    bool isSelected(WidgetTester tester, int turns) => tester
        .widget<Semantics>(find
            .ancestor(of: arrow(turns), matching: find.byType(Semantics))
            .first)
        .properties
        .selected!;

    testWidgets('la flèche de quarterTurns % 4 est la seule active',
        (tester) async {
      // 5 % 4 == 1 : la valeur peut arriver hors de 0..3.
      await pumpPicker(tester, 5);
      expect([for (var t = 0; t < 4; t++) isSelected(tester, t)],
          [false, true, false, false]);
      expect(find.text('90°'), findsOneWidget);

      await pumpPicker(tester, 3);
      expect([for (var t = 0; t < 4; t++) isSelected(tester, t)],
          [false, false, false, true]);
      expect(find.text('270°'), findsOneWidget);
    });

    testWidgets('chaque flèche mesure au moins 48×48', (tester) async {
      await pumpPicker(tester, 0);
      for (var t = 0; t < 4; t++) {
        final size = tester.getSize(arrow(t));
        expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension),
            reason: 'flèche $t');
        expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension),
            reason: 'flèche $t');
      }
    });
  });

  group('ReorganiseBar', () {
    testWidgets(
        'un preset appelle SON callback, « Terminé » appelle onDone, et '
        'chaque cible mesure au moins 48 de haut', (tester) async {
      final tapped = <String>[];
      var done = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ReorganiseBar(
              presets: [
                for (final label in const ['Table', 'Même sens'])
                  (label: label, onTap: () => tapped.add(label)),
              ],
              onDone: () => done++,
            ),
          ),
        ),
      ));

      expect(find.text('Réorganisation'), findsOneWidget);
      expect(find.text('le décompte est suspendu'), findsOneWidget);

      await tester.tap(find.text('Même sens'));
      await tester.tap(find.text('Table'));
      expect(tapped, ['Même sens', 'Table']);
      expect(done, 0);

      await tester.tap(find.text('Terminé'));
      expect(done, 1);

      for (final key in const [
        'reorganise-preset-Table',
        'reorganise-preset-Même sens',
        'reorganise-done',
      ]) {
        expect(tester.getSize(find.byKey(ValueKey(key))).height,
            greaterThanOrEqualTo(kMinInteractiveDimension),
            reason: key);
      }
    });
  });
}
