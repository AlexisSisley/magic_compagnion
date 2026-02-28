import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:magic_companion/main.dart';

void main() {
  testWidgets('MagicCompanionApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MagicCompanionApp(),
      ),
    );

    // Verify the app title is present
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
