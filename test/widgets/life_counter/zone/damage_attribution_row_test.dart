// test/widgets/life_counter/zone/damage_attribution_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/damage_attribution_row.dart';

const _opponents = [
  (playerId: 1, name: 'Sam', colorValue: 0xFFFF0000),
  (playerId: 2, name: 'Mia', colorValue: 0xFF00FF00),
  (playerId: 3, name: 'Leo', colorValue: 0xFF0000FF),
];

Future<void> _pumpRow(
  WidgetTester tester, {
  List<DamageAttributionOpponent> opponents = _opponents,
  required void Function(int) onAttribute,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DamageAttributionRow(
          opponents: opponents,
          onAttribute: onAttribute,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('affiche un avatar par adversaire (trois adversaires distincts)',
      (tester) async {
    await _pumpRow(tester, onAttribute: (_) {});

    expect(find.byKey(const ValueKey('damage-attribution-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('damage-attribution-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('damage-attribution-3')), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(3));
  });

  testWidgets(
      'un tap sur un avatar emet le sourcePlayerId de CET avatar, pas '
      'celui d\'un voisin (identifiants distincts pour detecter une '
      'inversion)', (tester) async {
    final emitted = <int>[];
    await _pumpRow(tester, onAttribute: emitted.add);

    // Mia porte l'id 2, entre Sam (1) et Leo (3) : une inversion qui
    // renverrait l'id du voisin serait detectee ici.
    await tester.tap(find.byKey(const ValueKey('damage-attribution-2')));
    await tester.pump();

    expect(emitted, [2],
        reason: 'le tap sur l\'avatar de Mia (id 2) ne doit emettre ni '
            'l\'id de Sam (1) ni celui de Leo (3)');
  });

  testWidgets('un tap sur chaque avatar emet bien son propre id',
      (tester) async {
    final emitted = <int>[];
    await _pumpRow(tester, onAttribute: emitted.add);

    await tester.tap(find.byKey(const ValueKey('damage-attribution-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('damage-attribution-3')));
    await tester.pump();

    expect(emitted, [1, 3]);
  });

  testWidgets('aucun adversaire : la rangee ne rend rien', (tester) async {
    await _pumpRow(tester, opponents: const [], onAttribute: (_) {});

    expect(find.byType(CircleAvatar), findsNothing);
  });
}
