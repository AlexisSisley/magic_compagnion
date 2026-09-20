// Fichier : test/pages/settings/settings_page_test.dart
// L'ecran Reglages absorbe des entrees du Drawer. Ce test verrouille leur
// presence : c'est ce qui autorise le lot E a supprimer le Drawer sans
// rendre un ecran inatteignable.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/pages/settings/settings_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// Surface volontairement haute : la page est une `ListView`, qui ne
  /// construit que ce qui est visible. Sur un gabarit telephone, les
  /// sections du bas n'existent pas encore dans l'arbre et `find.text` ne
  /// les voit pas -- ce qui ferait echouer le test pour une raison qui n'a
  /// rien a voir avec ce qu'il mesure.
  void surfaceHaute(WidgetTester tester) {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget harness() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: buildAppTheme(), home: const SettingsPage()),
      );

  testWidgets('les cinq sections sont presentes', (tester) async {
    surfaceHaute(tester);
    await tester.pumpWidget(harness());
    await tester.pump();

    // Les titres de section sont rendus en capitales par
    // `_buildSectionTitle`. On cherche donc cette forme-la, et pas le mot
    // en casse normale : sinon un test peut passer en tombant sur un texte
    // de corps qui contient le meme mot, sans que la section existe.
    for (final section in ['Sauvegarde', 'Joueurs', 'Apparence', 'A propos']) {
      expect(find.text(section.toUpperCase()), findsOneWidget,
          reason: 'la section $section manque');
    }
  });

  testWidgets("la section Sauvegarde porte l'entree Google Drive",
      (tester) async {
    surfaceHaute(tester);
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.textContaining('Drive', findRichText: true), findsWidgets);
  });

  testWidgets('la section A propos porte les licences Wizards',
      (tester) async {
    surfaceHaute(tester);
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.textContaining('Licences', findRichText: true), findsWidgets);
  });

  testWidgets('la section Joueurs mene a la gestion des profils',
      (tester) async {
    // C'est l'entree "Gestion des Profils" du tiroir. Sans elle ici, le lot E
    // rendrait ProfileManagementPage inatteignable.
    surfaceHaute(tester);
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.textContaining('Profils', findRichText: true), findsWidgets);
  });
}
