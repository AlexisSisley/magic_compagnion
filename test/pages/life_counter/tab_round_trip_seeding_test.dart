// test/pages/life_counter/tab_round_trip_seeding_test.dart
//
// `PlayShell` change d'onglet par `context.go`, sans conserver l'état :
// revenir sur « Vies » remonte une `LifeCounterPage` neuve, qui relit la
// partie depuis le snapshot. Tant que la page décidait elle-même si une
// session pouvait être resemée (selon qu'elle l'avait créée ou non), ce
// remontage coupait le semis pour le reste de la partie : sur le Fold, un
// passage par un autre onglet puis un pliage laissaient les zones à
// `[2,2,0,0]` dans des colonnes.
//
// Le semis lit désormais `PlayerState.manualRotation`, persisté dans le
// snapshot : après le retour, les zones non choisies suivent encore la
// géométrie, et celle que le joueur a réglée à la flèche garde son angle.
//
// Mêmes routes que la production (`playRoutes()`), et vrais taps sur la
// barre d'outils de partie : c'est le remontage réel qui est en cause, pas
// une reconstitution.
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

void _setScreenSize(WidgetTester tester, Size size) {
  final originalSize = tester.view.physicalSize;
  final originalDpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.physicalSize = originalSize;
    tester.view.devicePixelRatio = originalDpr;
  });
}

List<int> _turnsByCanonicalId(ProviderContainer container) {
  final session = container.read(gameSessionNotifierProvider)!;
  return [
    for (int id = 0; id < session.players.length; id++)
      session.players.firstWhere((p) => p.playerId == id).quarterTurns,
  ];
}

void main() {
  testWidgets(
      "après un aller-retour d'onglet, un pliage resème les zones non "
      'manuelles et laisse intacte la zone réglée à la main', (tester) async {
    // Fold déplié : grille 2×2 aux zones plus larges que hautes.
    _setScreenSize(tester, const Size(840, 700));
    // Aucune partie en cours : la page démarre la sienne au montage.
    SharedPreferences.setMockInitialValues({});

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.playCounter,
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
    expect(_turnsByCanonicalId(container), [2, 2, 0, 0],
        reason: 'précondition : semis du démarrage, face-à-face');

    // Le joueur 1 (assis en haut) choisit « bas » à la flèche : un angle
    // manuel, que le snapshot doit emporter.
    await tester.tap(find.byKey(const ValueKey('action-edit-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('player_zone_1')),
      matching: find.byKey(const ValueKey('orientation-arrow-0')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reorganise-done')));
    await tester.pumpAndSettle();
    expect(_turnsByCanonicalId(container), [2, 0, 0, 0],
        reason: 'précondition : le choix manuel est posé');

    // Aller-retour par l'onglet « Règles », par la vraie barre de partie.
    final pageBefore = tester.state(find.byType(LifeCounterPage));
    await tester.tap(find.text('Règles'));
    await tester.pumpAndSettle();
    expect(find.byType(LifeCounterPage), findsNothing,
        reason: 'précondition : quitter l\'onglet démonte la page');
    await tester.tap(find.text('Vies'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(LifeCounterPage)), isNot(pageBefore),
        reason: 'précondition : le retour remonte une page neuve');

    // Pliage : téléphone en portrait, zones plus hautes que larges.
    _setScreenSize(tester, const Size(390, 844));
    await tester.pumpAndSettle();

    expect(
      _turnsByCanonicalId(container),
      [1, 0, 1, 3],
      reason: 'les joueurs 0, 2 et 3 n\'ont rien choisi : ils suivent les '
          'colonnes (gauche 1, droite 3). Le joueur 1 garde son angle '
          'manuel, même remonté depuis le snapshot',
    );
  });
}
