import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:magic_companion/main.dart';
import 'package:magic_companion/services/drive_lifecycle_observer.dart';

void main() {
  testWidgets('MagicCompanionApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MagicCompanionApp(),
      ),
    );

    // Verify the app title is present
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets("l'observer de sauvegarde Drive est monte au-dessus du routeur",
      (WidgetTester tester) async {
    // Le piege recurrent de ce depot : un composant correct, teste, et jamais
    // branche. drive_lifecycle_observer_test.dart prouve que l'observer
    // fonctionne ; celui-ci prouve que l'app le monte -- sans quoi la
    // sauvegarde automatique ne s'executerait jamais, en silence.
    await tester.pumpWidget(
      ProviderScope(
        child: MagicCompanionApp(),
      ),
    );

    final observer =
        tester.widget<DriveLifecycleObserver>(find.byType(DriveLifecycleObserver));
    expect(observer.navigatorKey, isNotNull,
        reason: 'sans cle de Navigator, le dialogue de restauration ne peut '
            "pas s'afficher : le contexte de l'observer est au-dessus de "
            'MaterialApp');
  });
}
