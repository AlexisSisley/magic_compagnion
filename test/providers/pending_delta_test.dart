// test/providers/pending_delta_test.dart
//
// Le fichier de tâche proposait `PlayerZoneNotifier()` instancié directement,
// sans argument. Les deux hypothèses sont fausses aujourd'hui :
// `PlayerZoneNotifier` exige un `playerId` (`NotifierProvider.family`, voir
// `player_zone_notifier.dart`) et, plus important, un `Notifier` riverpod
// construit hors d'un `ProviderContainer` n'a pas de `ref` attaché -- lire ou
// écrire `state` plante. On reprend donc le patron déjà en vigueur dans
// `test/providers/player_zone_notifier_test.dart` : un `ProviderContainer`
// réel, lu via le provider `.family`.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/widgets/life_counter/tuning.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  PlayerZoneNotifier notifierFor(int playerId) =>
      container.read(playerZoneNotifierProvider(playerId).notifier);

  PlayerZoneState stateFor(int playerId) =>
      container.read(playerZoneNotifierProvider(playerId));

  test('les changements successifs se cumulent', () {
    final notifier = notifierFor(0);
    notifier.accumulate(-3);
    notifier.accumulate(-4);
    expect(stateFor(0).pendingDelta, -7);
  });

  test('un gain et une perte s\'annulent', () {
    final notifier = notifierFor(0);
    notifier.accumulate(5);
    notifier.accumulate(-5);
    expect(stateFor(0).pendingDelta, 0);
  });

  test('le cumul est vidé à la fermeture de la fenêtre', () {
    fakeAsync((async) {
      final notifier = notifierFor(0);
      notifier.accumulate(-3);
      async.elapse(kDamageBufferWindow + const Duration(milliseconds: 50));
      expect(stateFor(0).pendingDelta, 0);
    });
  });

  test('un nouveau changement relance la fenêtre', () {
    fakeAsync((async) {
      final notifier = notifierFor(0);
      notifier.accumulate(-3);
      async.elapse(kDamageBufferWindow ~/ 2);
      notifier.accumulate(-2);
      async.elapse(kDamageBufferWindow ~/ 2 + const Duration(milliseconds: 50));
      expect(stateFor(0).pendingDelta, -5,
          reason: 'la fenêtre doit repartir à chaque changement');
    });
  });

  test(
      'le minuteur ne survit pas à la destruction du provider '
      '(aucune exception après dispose du container)', () {
    fakeAsync((async) {
      // Preuve de la question 2 du rapport de tâche : un minuteur encore
      // armé au moment du `dispose()` du container ne doit ni planter ni
      // continuer à écrire dans un état détruit. On vide la file de
      // micro-tâches/minuteurs avec `async.flushTimers()` APRÈS le dispose :
      // si `ref.onDispose` n'annulait pas `_pendingDeltaTimer`, ce
      // `flushTimers()` exécuterait `clearPendingDelta`, qui écrirait dans
      // `state` sur un notifier détruit et lèverait une exception au lieu de
      // se terminer silencieusement.
      notifierFor(0).accumulate(-3);
      container.dispose();
      expect(() => async.flushTimers(), returnsNormally);
    });
  });
}
