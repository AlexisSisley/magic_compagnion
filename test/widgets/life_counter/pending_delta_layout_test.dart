// test/widgets/life_counter/pending_delta_layout_test.dart
//
// Spec §1.8 : le delta en attente fait au moins la moitié du total et se
// pose CONTRE lui, sans le recouvrir. Mesuré à la vraie hauteur de cadran du
// Fold replié à 4 joueurs : une zone de 195×390 à l'écran, tournée d'un
// quart de tour, soit 390×195 dans le repère du joueur (cran confort). Là,
// le cadran ne fait qu'une centaine de pixels de haut : un delta de taille
// nominale posé par-dessus le total réduit chevauchait le chiffre d'environ
// 30 px.
//
// La zone est tournée : la hauteur dans le repère du joueur est donc la
// LARGEUR à l'écran.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

const _delta = -7;

Future<ProviderContainer> _pumpFoldZone(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 195,
              height: 390,
              child: PlayerZone(
                player: Player(
                  id: 0,
                  name: 'Alexis',
                  life: 40,
                  colorValue: 0xFF880000,
                  commanderDamageReceived: const {},
                  quarterTurns: 1,
                ),
                onLifeChanged: (_) {},
                onColorChanged: (_) {},
                pendingDelta: _delta,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _inDial(Finder f) =>
    find.descendant(of: find.byType(LifeDial), matching: f);

void main() {
  testWidgets(
      'Fold replié, 4 joueurs : le delta ne recouvre pas le total et fait au '
      'moins la moitié de sa hauteur', (tester) async {
    await _pumpFoldZone(tester);

    final dial = tester.getRect(find.byType(LifeDial));
    expect(dial.width, lessThan(110),
        reason: 'précondition : cadran d\'une centaine de pixels de haut '
            'dans le repère du joueur');

    final total = tester.getRect(_inDial(find.text('40')));
    final delta = tester.getRect(find.text('$_delta'));
    expect(total.overlaps(delta), isFalse,
        reason: 'total $total, delta $delta');
    // Hauteur dans le repère du joueur = largeur à l'écran (quart de tour).
    // Tolérance : le rapport vaut exactement 1/2, au bruit flottant près.
    expect(delta.width, greaterThanOrEqualTo(total.width / 2 - 0.01),
        reason: 'spec §1.8 : au moins la moitié du total');
    // Axe horizontal du joueur = vertical à l'écran (quart de tour).
    expect(total.center.dy, moreOrLessEquals(dial.center.dy, epsilon: 0.5),
        reason: 'le total reste centré quand le delta apparaît : il ne '
            'glisse pas sur le côté à chaque salve');
  });

  testWidgets(
      'en mode ajustement, le delta ne recouvre pas la rangée de paliers',
      (tester) async {
    final container = await _pumpFoldZone(tester);
    container.read(playerZoneNotifierProvider(0).notifier).enterAdjustMode();
    await tester.pumpAndSettle();

    final steps = tester.getRect(find.byKey(const ValueKey('life_step_row')));
    final delta = tester.getRect(find.text('$_delta'));
    expect(steps.overlaps(delta), isFalse,
        reason: 'paliers $steps, delta $delta');
  });
}
