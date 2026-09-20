// Fichier : test/router/app_shell_scaffold_test.dart
// Le shell d'onglets, monte sur le vrai routeur.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/pages/onboarding/onboarding_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // L'onboarding se redirige sur le premier lancement : sans ce drapeau,
    // l'app s'ouvrirait sur l'onboarding et non sur l'Accueil.
    SharedPreferences.setMockInitialValues({kHasSeenOnboarding: true});
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// Monte l'app reelle et pompe juste ce qu'il faut pour que le shell
  /// existe.
  ///
  /// Ni `pumpAndSettle` ni `runAsync`, et les deux exclusions ont leur raison.
  /// `pumpAndSettle` expirerait : le tableau de bord de l'Accueil affiche un
  /// shimmer qui boucle sans fin tant que ses donnees chargent. `runAsync`
  /// laisserait l'I/O reelle avancer, google_fonts comprise, qui partirait
  /// chercher ses polices sur le reseau et ferait echouer le montage.
  ///
  /// Des pompes simples suffisent : elles vident les `Future.delayed` de
  /// l'entree en cascade (StaggeredFadeIn), dont un timer encore en vol au
  /// demontage ferait echouer le test. Le tableau de bord reste sur son
  /// shimmer, ce qui n'a aucune importance ici -- ce test mesure la barre
  /// d'onglets, pas son contenu.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: createAppRouter(),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('le shell porte cinq onglets et aucun Drawer', (tester) async {
    await pumpApp(tester);

    final bar =
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.items.length, 5);
    expect(bar.items.map((i) => i.label).toList(),
        ['Accueil', 'Scanner', 'Rechercher', 'Decks', 'Collection']);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawer, isNull,
        reason: 'le Drawer doit avoir disparu : ses entrees ont toutes une '
            'nouvelle adresse');
  });

  testWidgets("l'app s'ouvre sur l'Accueil, pas sur le compteur",
      (tester) async {
    await pumpApp(tester);

    final bar =
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.currentIndex, 0);
    expect(find.text('Accueil'), findsWidgets);
  });
}
