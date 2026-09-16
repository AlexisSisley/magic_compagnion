// test/widgets/life_counter/zone/commander_damage_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/commander_damage_grid.dart';

const _opponents = [
  CommanderDamageOpponent(
      playerId: 1, name: 'Sam', colorValue: 0xFFFF0000, damage: 4),
  CommanderDamageOpponent(
      playerId: 2, name: 'Mia', colorValue: 0xFF00FF00, damage: 21),
  CommanderDamageOpponent(
      playerId: 3, name: 'Leo', colorValue: 0xFF0000FF, damage: 0),
];

Future<void> _pumpGrid(
  WidgetTester tester, {
  List<CommanderDamageOpponent> opponents = _opponents,
  int lethalThreshold = 21,
  required void Function(int, int) onDelta,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CommanderDamageGrid(
          opponents: opponents,
          lethalThreshold: lethalThreshold,
          onDelta: onDelta,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('affiche une ligne par adversaire avec son nom et son total actuel',
      (tester) async {
    await _pumpGrid(tester, onDelta: (_, _) {});

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Mia'), findsOneWidget);
    expect(find.text('Leo'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets(
      'taper + sur une ligne emet onDelta avec le playerId de CETTE ligne, '
      'et pas celui d\'une autre (3 adversaires aux identifiants distincts)',
      (tester) async {
    final emitted = <(int, int)>[];
    await _pumpGrid(tester, onDelta: (id, delta) => emitted.add((id, delta)));

    // Mia porte l'id 2, entre Sam (1) et Leo (3) : une inversion qui
    // renverrait l'id de la ligne voisine, ou celui d'un joueur fixe,
    // serait detectee ici.
    await tester.tap(find.byKey(const ValueKey('commander-damage-2-plus')));
    await tester.pump();

    expect(emitted, [(2, 1)],
        reason: 'le tap sur la ligne de Mia (id 2) ne doit emettre ni '
            'l\'id de Sam (1) ni celui de Leo (3)');
  });

  testWidgets('taper - sur une ligne emet onDelta(id, -1) pour cette ligne',
      (tester) async {
    final emitted = <(int, int)>[];
    await _pumpGrid(tester, onDelta: (id, delta) => emitted.add((id, delta)));

    await tester.tap(find.byKey(const ValueKey('commander-damage-1-minus')));
    await tester.pump();

    expect(emitted, [(1, -1)]);
  });

  testWidgets(
      'une source ayant atteint le seuil letal est signalee visuellement, '
      'les autres non', (tester) async {
    await _pumpGrid(tester, lethalThreshold: 21, onDelta: (_, _) {});

    // Mia est a 21/21 (seuil letal) : signalee. Sam (4) et Leo (0) non.
    expect(find.byKey(const ValueKey('commander-damage-lethal-2')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('commander-damage-lethal-1')), findsNothing);
    expect(
        find.byKey(const ValueKey('commander-damage-lethal-3')), findsNothing);
  });

  testWidgets('un seuil letal desactive (0) ne signale jamais aucune source',
      (tester) async {
    await _pumpGrid(tester, lethalThreshold: 0, onDelta: (_, _) {});

    expect(
        find.byKey(const ValueKey('commander-damage-lethal-2')), findsNothing);
  });

  testWidgets(
      'un adversaire eliminé apparait quand meme, son total reste '
      'consultable et modifiable', (tester) async {
    // CommanderDamageOpponent ne porte aucune information d'élimination :
    // la grille ne filtre, ne grise et ne désactive aucune ligne sur ce
    // critère -- c'est à l'appelant de décider qui figure dans la liste.
    // Ce test verrouille l'absence de tout filtrage caché dans le widget.
    const eliminatedOpponent = CommanderDamageOpponent(
      playerId: 9,
      name: 'Josh (éliminé)',
      colorValue: 0xFF999999,
      damage: 12,
    );
    final emitted = <(int, int)>[];
    await _pumpGrid(
      tester,
      opponents: const [..._opponents, eliminatedOpponent],
      onDelta: (id, delta) => emitted.add((id, delta)),
    );

    expect(find.text('Josh (éliminé)'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('commander-damage-9-plus')));
    await tester.pump();
    expect(emitted, [(9, 1)],
        reason: 'la ligne d\'un adversaire éliminé reste interactive, comme '
            'toutes les autres');
  });
}
