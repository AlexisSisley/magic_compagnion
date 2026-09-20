// Fichier : test/router/branch_stack_test.dart
// Le gain de StatefulShellRoute : chaque onglet garde sa pile. Invisible aux
// tests d'ecran, et c'est ce qui casse le plus silencieusement.
//
// Deux pieges d'instrumentation, trouves par sonde et qui valent d'etre dits,
// parce que s'y tromper donne un test qui passe sans rien mesurer :
//
// 1. `currentConfiguration.uri` ne reflete PAS un `push` imperatif. Il reste
//    sur la derniere adresse declarative. Assertions sur les WIDGETS visibles,
//    donc, pas sur l'URI.
// 2. Changer de branche par `router.go('/decks')` REMET la branche d'arrivee
//    a cette adresse exacte et jette sa pile. Seul `goBranch` -- ce que fait
//    la barre d'onglets -- preserve les piles. Le test tape donc les onglets
//    au lieu d'appeler `go`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/pages/cards/card_detail_page.dart';
import 'package:magic_companion/pages/onboarding/onboarding_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GoRouter router;
  late AppDatabase db;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({kHasSeenOnboarding: true});
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// Ni `pumpAndSettle` (le shimmer du tableau de bord boucle sans fin) ni
  /// `runAsync` (qui reveillerait le telechargement de polices).
  Future<void> pompe(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    router = createAppRouter();
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    ));
    await pompe(tester);
  }

  /// Tape un onglet comme le ferait un doigt : c'est `goBranch` qui s'execute,
  /// pas `go`.
  Future<void> tapeOnglet(WidgetTester tester, String label) async {
    // Restreint a la barre : "Collection" apparait aussi dans la page, et un
    // `find.text` nu trouverait deux cibles.
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ));
    await pompe(tester);
  }

  bool ficheVisible() =>
      find.byType(RecognitionResultPage).evaluate().isNotEmpty;

  testWidgets('une branche retrouve sa pile apres un aller-retour',
      (tester) async {
    await pumpApp(tester);

    await tapeOnglet(tester, 'Collection');
    router.push('/collection/card',
        extra: <String, dynamic>{'cardName': 'Sol Ring'});
    await pompe(tester);
    expect(ficheVisible(), isTrue,
        reason: 'la fiche doit s\'ouvrir dans la branche Collection');

    await tapeOnglet(tester, 'Decks');
    expect(ficheVisible(), isFalse,
        reason: 'la branche Decks ne montre pas la pile de Collection');

    await tapeOnglet(tester, 'Collection');

    expect(ficheVisible(), isTrue,
        reason: 'revenir sur Collection doit retrouver la fiche ouverte : '
            "c'est tout l'interet de StatefulShellRoute");
  });

  testWidgets("la barre d'onglets reste visible sur un ecran de detail",
      (tester) async {
    await pumpApp(tester);

    await tapeOnglet(tester, 'Decks');
    router.push('/decks/card', extra: <String, dynamic>{
      'cardName': 'Sol Ring',
    });
    await pompe(tester);

    expect(ficheVisible(), isTrue);
    expect(find.byType(BottomNavigationBar), findsOneWidget,
        reason: 'un detail pousse dans une branche garde la barre');
  });

  testWidgets("le mode Jeu, lui, n'a pas la barre d'onglets", (tester) async {
    await pumpApp(tester);

    router.go('/play/setup');
    await pompe(tester);

    expect(find.byType(BottomNavigationBar), findsNothing,
        reason: "le mode Jeu est plein ecran, c'est voulu");
  });

  testWidgets("retaper l'onglet actif remonte a la racine de sa branche",
      (tester) async {
    await pumpApp(tester);

    await tapeOnglet(tester, 'Collection');
    router.push('/collection/card',
        extra: <String, dynamic>{'cardName': 'Sol Ring'});
    await pompe(tester);
    expect(ficheVisible(), isTrue);

    // Deuxieme tape sur l'onglet DEJA actif : le geste "remonter en haut".
    await tapeOnglet(tester, 'Collection');

    expect(ficheVisible(), isFalse,
        reason: "retaper l'onglet actif doit vider sa pile");
  });
}
