// test/pages/life_counter/play_setup_seeds_rotations_test.dart
//
// Le parcours RÉEL de démarrage d'une partie passe par
// `PlaySetupPage._demarrer` (via la feuille `GameSetupModal` qu'il ouvre),
// PAS par la modale accessible depuis `LifeCounterPage` elle-même.
// `_demarrer` ÉCRIT le snapshot de la nouvelle partie PUIS navigue : au
// montage, `LifeCounterPage._loadGame()` prend donc la branche de
// restauration, comme une reprise. Le semis doit s'y produire quand même :
// la session neuve porte `manualRotation == false` partout, et c'est ce
// marqueur, persisté, qui ouvre le semis -- pas la provenance de la page.
//
// Défaut historique reproduit ici : une partie à 4 joueurs démarrée par ce
// chemin restait figée à `quarterTurns == [0, 0, 0, 0]` -- les deux joueurs
// d'en face lisaient leur total à l'envers.
//
// Ce test monte un GoRouter RÉEL construit avec les VRAIES routes de
// `playRoutes()` (pas une reconstitution partielle), une `PlaySetupPage`
// réelle, sa `GameSetupModal` réelle (bouton "LANCER LA PARTIE" tapé pour de
// vrai, pas un appel direct à `_demarrer`), jusqu'à une `LifeCounterPage`
// réelle -- le seul moyen de prouver que le câblage bout en bout fonctionne,
// pas seulement la logique de chaque écran pris isolément.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:magic_companion/router/play_routes.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'une partie demarree via PlaySetupPage seme ses '
      'rotations (4 joueurs, 900x700 -> [2,2,0,0]), pas [0,0,0,0]',
      (tester) async {
    final originalSize = tester.view.physicalSize;
    final originalDpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
    });

    // Aucune partie en cours : `PlaySetupPage` ouvre sa feuille de
    // configuration d'elle-meme au montage.
    SharedPreferences.setMockInitialValues({});

    // `ProfileService` (feuille de configuration) et `GameHistoryService`
    // (LifeCounterPage) passent par `appDatabaseProvider` : une base en
    // memoire, comme `play_setup_page_test.dart`, pour ne pas toucher le
    // disque et eviter l'avertissement drift sur une base par defaut.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // Les VRAIES routes du mode Jeu -- celles que `createAppRouter()`
    // greffe en production (`...playRoutes()`) -- pas une liste refaite a la
    // main qui pourrait diverger du cablage reel.
    final router = GoRouter(
      initialLocation: AppRoutes.playSetup,
      routes: playRoutes(),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La feuille de configuration s'est ouverte d'elle-meme : 4 joueurs par
    // defaut (`GameSetupModal._selectedProfiles`, `List.filled(4, null)`),
    // format deja preselectionne (40 PV -> Commander). Tape directement
    // "LANCER LA PARTIE", sans rien reconfigurer -- c'est le geste le plus
    // frequent, et celui que le defaut touchait.
    expect(find.text('LANCER LA PARTIE'), findsOneWidget,
        reason: 'precondition : la feuille doit etre ouverte');
    await tester.tap(find.text('LANCER LA PARTIE'));
    await tester.pumpAndSettle();

    // Navigation reelle effectuee jusqu'a LifeCounterPage (pas restee sur
    // PlaySetupPage, pas une exception avalee par pumpAndSettle).
    expect(find.byType(LifeCounterPage), findsOneWidget);

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.players, hasLength(4));
    expect(
      session.players.map((p) => p.quarterTurns),
      [2, 2, 0, 0],
      reason: 'une partie neuve demarree via PlaySetupPage doit '
          'semer ses rotations comme n\'importe quelle autre partie neuve -- '
          'pas rester a [0,0,0,0] parce que LifeCounterPage l\'a vue comme '
          'une restauration',
    );
  });
}
