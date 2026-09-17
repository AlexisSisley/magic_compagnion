// test/widgets/life_counter/zone/action_hub_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/action_hub.dart';

const _hubButtonKey = ValueKey('action_hub_button');

/// Huit actions distinctes, chacune comptant ses propres déclenchements —
/// jamais un compteur partagé, sinon un test ne pourrait pas distinguer
/// « la bonne action a été appelée » de « une action quelconque l'a été ».
List<GameAction> _buildActions(List<int> calls) {
  return [
    for (var i = 0; i < 8; i++)
      GameAction(
        icon: Icons.circle,
        label: 'Action $i',
        onPressed: () => calls[i]++,
      ),
  ];
}

Future<void> _pumpHub(WidgetTester tester, List<GameAction> actions) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: ActionHub(actions: actions)),
      ),
    ),
  );
}

void main() {
  testWidgets('le hub n\'affiche qu\'un bouton au repos', (tester) async {
    final calls = List.filled(8, 0);
    final actions = _buildActions(calls);
    await _pumpHub(tester, actions);

    expect(find.byKey(_hubButtonKey), findsOneWidget);
    for (final action in actions) {
      expect(find.text(action.label), findsNothing,
          reason: 'aucune étiquette d\'action ne doit être visible avant '
              'ouverture de la feuille');
    }
  });

  testWidgets('taper le hub ouvre les HUIT actions', (tester) async {
    final calls = List.filled(8, 0);
    final actions = _buildActions(calls);
    await _pumpHub(tester, actions);

    await tester.tap(find.byKey(_hubButtonKey));
    await tester.pumpAndSettle();

    // Compte les HUIT libellés, pas seulement que la feuille s'est ouverte :
    // c'est ce qui interdit la dégradation silencieuse (voir brief).
    for (final action in actions) {
      expect(find.text(action.label), findsOneWidget);
    }
  });

  testWidgets('choisir une action la déclenche et ferme la feuille',
      (tester) async {
    final calls = List.filled(8, 0);
    final actions = _buildActions(calls);
    await _pumpHub(tester, actions);

    await tester.tap(find.byKey(_hubButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Action 3'));
    await tester.pumpAndSettle();

    expect(calls[3], 1, reason: 'onPressed de l\'action choisie appelé une '
        'seule fois');
    for (final other in [0, 1, 2, 4, 5, 6, 7]) {
      expect(calls[other], 0,
          reason: 'les autres actions ne doivent pas être déclenchées');
    }
    expect(find.byType(BottomSheet), findsNothing,
        reason: 'la feuille doit être refermée après le choix');
  });

  testWidgets('le bouton du hub fait au moins 48 px', (tester) async {
    final calls = List.filled(8, 0);
    final actions = _buildActions(calls);
    await _pumpHub(tester, actions);

    final size = tester.getSize(find.byKey(_hubButtonKey));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
