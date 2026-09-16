// test/widgets/life_counter/zone/player_drawer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/player_drawer.dart';

class _Captured {
  // Un record `(String, int)` plutôt qu'un `MapEntry` : `MapEntry` n'a pas
  // d'égalité structurelle (`==` par défaut est l'identité), donc deux
  // instances distinctes aux mêmes champs ne sont jamais `==` — ce qui fait
  // échouer `expect` même quand le comportement est correct. Les records ont
  // une égalité structurelle native en Dart 3.
  final counterDeltas = <(String, int)>[];
  var monarchToggled = false;
  var eliminated = false;
  var reset = false;
  var commanderDamageOpened = false;
}

Future<_Captured> _openDrawer(
  WidgetTester tester, {
  Map<String, int> counters = const {'poison': 0, 'energy': 0, 'commander_tax': 0},
  bool isMonarch = false,
  bool isEliminated = false,
}) async {
  final captured = _Captured();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPlayerDrawer(
              context: context,
              playerName: 'Alexis',
              counters: counters,
              isMonarch: isMonarch,
              isEliminated: isEliminated,
              onCounterDelta: (id, d) =>
                  captured.counterDeltas.add((id, d)),
              onToggleMonarch: () => captured.monarchToggled = true,
              onEliminate: () => captured.eliminated = true,
              onResetCounters: () => captured.reset = true,
              onCommanderDamage: () => captured.commanderDamageOpened = true,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('affiche le nom du joueur et les trois compteurs',
      (tester) async {
    await _openDrawer(tester);
    expect(find.text('Alexis'), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);
    expect(find.text('Énergie'), findsOneWidget);
    expect(find.text('Taxe de commandant'), findsOneWidget);
  });

  testWidgets('incrémenter un compteur émet son delta', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('counter-poison-plus')));
    await tester.pumpAndSettle();
    expect(captured.counterDeltas, [('poison', 1)]);
  });

  testWidgets('décrémenter un compteur émet son delta', (tester) async {
    final captured = await _openDrawer(tester, counters: {'poison': 2});
    await tester.tap(find.byKey(const ValueKey('counter-poison-minus')));
    await tester.pumpAndSettle();
    expect(captured.counterDeltas, [('poison', -1)]);
  });

  testWidgets('l\'action monarque appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    await tester.pumpAndSettle();
    expect(captured.monarchToggled, isTrue);
    expect(captured.eliminated, isFalse);
    expect(captured.reset, isFalse);
  });

  testWidgets('l\'action éliminer appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-eliminate')));
    await tester.pumpAndSettle();
    expect(captured.eliminated, isTrue);
    expect(captured.monarchToggled, isFalse);
  });

  testWidgets('l\'action réinitialiser appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-reset')));
    await tester.pumpAndSettle();
    expect(captured.reset, isTrue);
    expect(captured.eliminated, isFalse);
  });

  testWidgets(
      "l'action dégâts de commandant appelle son callback (ligne "
      'provisoire lot 2, cf. lot 3)', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-commander-damage')));
    await tester.pumpAndSettle();
    expect(captured.commanderDamageOpened, isTrue);
    expect(captured.monarchToggled, isFalse);
    expect(captured.eliminated, isFalse);
    expect(captured.reset, isFalse);
  });

  testWidgets('une action ferme le tiroir', (tester) async {
    await _openDrawer(tester);
    expect(find.text('Alexis'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    await tester.pumpAndSettle();
    expect(find.text('Alexis'), findsNothing,
        reason: 'le tiroir se referme avant de déclencher l\'action');
  });

  testWidgets('l\'action monarque change de libellé selon l\'état',
      (tester) async {
    await _openDrawer(tester, isMonarch: false);
    expect(find.text('Monarque'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // ferme le sheet
    await tester.pumpAndSettle();

    await _openDrawer(tester, isMonarch: true);
    expect(find.text('Retirer le monarque'), findsOneWidget);
  });

  testWidgets('l\'action éliminer devient annuler pour un joueur éliminé',
      (tester) async {
    await _openDrawer(tester, isEliminated: true);
    expect(find.text('Annuler l\'élimination'), findsOneWidget);
  });
}
