// test/widgets/life_counter/zone/seated_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/seated_sheet.dart';

void main() {
  testWidgets('la feuille porte la rotation de son siège', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      }),
    ));

    showSeatedSheet<void>(
      context: ctx,
      quarterTurns: 2,
      builder: (_) => const Text('contenu'),
    );
    await tester.pumpAndSettle();

    final rotated = tester.widget<RotatedBox>(find.ancestor(
      of: find.text('contenu'),
      matching: find.byType(RotatedBox),
    ));
    expect(rotated.quarterTurns, 2);
  });

  testWidgets('un siège du bas se comporte comme une feuille ordinaire',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      }),
    ));

    showSeatedSheet<void>(
      context: ctx,
      quarterTurns: 0,
      builder: (_) => const Text('contenu'),
    );
    await tester.pumpAndSettle();

    final rotated = tester.widget<RotatedBox>(find.ancestor(
      of: find.text('contenu'),
      matching: find.byType(RotatedBox),
    ));
    expect(rotated.quarterTurns, 0);
  });
}
