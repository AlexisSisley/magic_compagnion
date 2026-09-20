// Fichier : test/pages/play/play_setup_reset_test.dart
// Une partie neuve ne doit rien heriter de la precedente.
//
// `playerZoneNotifierProvider` n'est PAS autoDispose : son etat -- mode
// ajustement, accumulateurs, nombres flottants -- traverse le cycle de vie
// des parties. `LifeCounterPage._startNewGame` le reinitialise explicitement,
// en commentant pourquoi : « une zone pouvait rouvrir une nouvelle partie
// deja en mode ajustement ».
//
// Une partie lancee depuis PlaySetupPage ne passe PAS par `_startNewGame` :
// elle ecrit un snapshot que `_loadGame` restaure, et `restoreSession` ne
// fait que poser la session. Sans reset explicite cote mise en place, le
// defaut revient par ce chemin -- et aucun test du depot ne le voyait.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test("l'etat de zone survit a une partie tant qu'on ne le reinitialise pas",
      () {
    // Le prealable du defaut, affirme plutot que suppose : si ce provider
    // etait autoDispose, le reste de ce fichier n'aurait pas lieu d'etre.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(playerZoneNotifierProvider(0), (_, __) {});
    addTearDown(sub.close);

    container.read(playerZoneNotifierProvider(0).notifier).enterAdjustMode();
    expect(container.read(playerZoneNotifierProvider(0)).isAdjusting, isTrue);

    // Rien entre les deux lectures : c'est bien l'etat qui persiste.
    expect(container.read(playerZoneNotifierProvider(0)).isAdjusting, isTrue,
        reason: 'playerZoneNotifierProvider ne se jette pas tout seul');
  });

  test('resetPlayerZones remet chaque zone a neuf', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final abonnements = [
      for (var i = 0; i < 4; i++)
        container.listen(playerZoneNotifierProvider(i), (_, __) {}),
    ];
    addTearDown(() {
      for (final a in abonnements) {
        a.close();
      }
    });

    for (var i = 0; i < 4; i++) {
      container.read(playerZoneNotifierProvider(i).notifier).enterAdjustMode();
      expect(container.read(playerZoneNotifierProvider(i)).isAdjusting, isTrue);
    }

    resetPlayerZones(container, 4);

    for (var i = 0; i < 4; i++) {
      expect(container.read(playerZoneNotifierProvider(i)).isAdjusting, isFalse,
          reason: 'la zone $i rouvrirait une nouvelle partie en mode '
              'ajustement');
    }
  });
}
