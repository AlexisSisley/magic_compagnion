// test/providers/game_session_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/providers/counter_catalog_provider.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';

void main() {
  late ProviderContainer container;

  final commanderFormat =
      GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
  final configs = [
    const PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
    const PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
    const PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
    const PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  GameSessionNotifier getNotifier() =>
      container.read(gameSessionNotifierProvider.notifier);

  test('build() démarre sans session', () {
    expect(container.read(gameSessionNotifierProvider), isNull);
  });

  test('startNewGame place une session dans le state', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    final session = container.read(gameSessionNotifierProvider);
    expect(session, isNotNull);
    expect(session!.players, hasLength(4));
    expect(session.players[0].life, 40);
  });

  test('updateLife notifie les écoutants', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);

    final seen = <int?>[];
    container.listen(
      gameSessionNotifierProvider,
      (_, next) => seen.add(next?.players[0].life),
      fireImmediately: false,
    );

    getNotifier().updateLife(0, -6, gameDuration: const Duration(minutes: 1));

    expect(seen, [34]);
    expect(container.read(gameSessionNotifierProvider)!.players[0].lifeHistory,
        hasLength(1));
  });

  test('addCommanderDamage retire les PV et journalise la source', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().addCommanderDamage(
      targetPlayerId: 0,
      sourcePlayerId: 2,
      damage: 7,
      gameDuration: const Duration(minutes: 3),
    );

    final target = container.read(gameSessionNotifierProvider)!.players[0];
    expect(target.life, 33);
    expect(target.commanderDamageReceived[2], 7);
    expect(target.lifeHistory.last.source, 'Commander: Sarah');
  });

  // Ronde de correction 1 (tâche 2) : le plancher à 0 de
  // commanderDamageReceived vit dans le notifier (seul chemin d'écriture),
  // pas côté page — comme updateCounter le fait déjà pour les compteurs.
  // Retirer temporairement le `.clamp(0, ...)` dans addCommanderDamage fait
  // échouer ces deux tests : le premier verrait life passer à 41 (un point
  // rendu gratuitement) et commanderDamageReceived[2] à -1 ; le second
  // resterait vert par coïncidence (aucun plancher atteint), ce qui
  // confirme qu'il ne teste que le chemin nominal.
  test(
      'décrémenter un total de commander damage déjà à zéro ne change ni la '
      'carte des dégâts ni les points de vie', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);

    getNotifier().addCommanderDamage(
      targetPlayerId: 0,
      sourcePlayerId: 2,
      damage: -1,
      gameDuration: const Duration(minutes: 1),
    );

    final target = container.read(gameSessionNotifierProvider)!.players[0];
    expect(target.life, 40,
        reason: 'aucun dégât n\'a été annulé : aucun point de vie ne doit '
            'être rendu');
    expect(target.commanderDamageReceived[2] ?? 0, 0,
        reason: 'le total ne doit jamais devenir négatif');
    expect(target.lifeHistory, isEmpty,
        reason: 'un delta sans effet réel ne doit pas non plus journaliser '
            'un faux événement');
  });

  test(
      'décrémenter un total de commander damage de 1 le ramène à zéro et '
      'rend exactement un point de vie', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().addCommanderDamage(
      targetPlayerId: 0,
      sourcePlayerId: 2,
      damage: 1,
      gameDuration: const Duration(minutes: 1),
    );
    // Précondition : 1 dégât reçu, 1 PV perdu.
    var target = container.read(gameSessionNotifierProvider)!.players[0];
    expect(target.life, 39);
    expect(target.commanderDamageReceived[2], 1);

    getNotifier().addCommanderDamage(
      targetPlayerId: 0,
      sourcePlayerId: 2,
      damage: -1,
      gameDuration: const Duration(minutes: 2),
    );

    target = container.read(gameSessionNotifierProvider)!.players[0];
    expect(target.commanderDamageReceived[2], 0);
    expect(target.life, 40,
        reason: 'annuler l\'unique dégât reçu doit rendre exactement le '
            'point de vie qu\'il avait coûté, ni plus ni moins');
  });

  test('toggleMonarch est exclusif', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().toggleMonarch(1);
    getNotifier().toggleMonarch(3);

    final players = container.read(gameSessionNotifierProvider)!.players;
    expect(players.where((p) => p.isMonarch).map((p) => p.playerId), [3]);
  });

  test('les mutations sans session sont sans effet', () {
    getNotifier().updateLife(0, -5, gameDuration: Duration.zero);
    expect(container.read(gameSessionNotifierProvider), isNull);
  });

  test('reorderPlayers ne modifie que playerOrder, jamais la liste canonique',
      () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().reorderPlayers([3, 1, 2, 0]);

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.playerOrder, [3, 1, 2, 0]);
    expect(session.players.map((p) => p.playerId).toList(), [0, 1, 2, 3]);
  });

  test('startTimer initialise la durée et marque la partie active', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().startTimer();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.isActive, isTrue);
    expect(session.duration, Duration.zero);
    expect(session.startedAt, isNotNull);
  });

  test('tick incrémente la durée portée par la session', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().startTimer();
    getNotifier().tick();
    getNotifier().tick();
    getNotifier().tick();

    expect(container.read(gameSessionNotifierProvider)!.duration,
        const Duration(seconds: 3));
  });

  test('la durée survit à un aller-retour JSON', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().startTimer();
    getNotifier().tick();
    getNotifier().tick();

    final json = container.read(gameSessionNotifierProvider)!.toJson();
    final restored = GameSession.fromJson(json);

    expect(restored.duration, const Duration(seconds: 2));
    expect(restored.isActive, isTrue);
  });

  test('stopTimer conserve la durée accumulée', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().startTimer();
    getNotifier().tick();
    getNotifier().stopTimer();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.isActive, isFalse);
    expect(session.duration, const Duration(seconds: 1));
  });

  test('tick sur session nulle ne lève pas et ne crée pas de session', () {
    getNotifier().tick();
    expect(container.read(gameSessionNotifierProvider), isNull);
  });

  test('tick après stopTimer ne fait plus avancer la durée', () {
    getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
    getNotifier().startTimer();
    getNotifier().tick();
    getNotifier().stopTimer();
    getNotifier().tick(); // tick tardif : la partie n'est plus active

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.isActive, isFalse);
    expect(session.duration, const Duration(seconds: 1),
        reason: 'un tick reçu après stopTimer ne doit pas incrémenter la '
            "durée d'une partie déjà arrêtée");
  });

  // --- Cas de couverture migrés depuis GameSessionController ---

  group('updateCounter', () {
    test('sets counter value', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'poison', 3);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['poison'], 3);
    });

    test('increments existing counter', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'poison', 2);
      getNotifier().updateCounter(0, 'poison', 3);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['poison'], 3);
    });

    test('clamps une valeur négative à 0', () {
      // Le tiroir (showPlayerDrawer) ne clampe que sa copie locale
      // d'affichage et émet le delta brut quand même : un tap "−" sur un
      // compteur déjà à 0 appellerait updateCounter(playerId, id, -1) sans
      // ce clamp côté notifier.
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'poison', -1);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['poison'], 0);
    });

    // Lot 5, tâche 3a : le plafond vient désormais de `CounterType.maxValue`
    // (résolu via `counterTypeByIdProvider`), pas d'une constante 99 écrite
    // dans le notifier. `poison` porte `maxValue: 10`
    // (`CounterType.builtInCounters`) : il sature à 10, plus à 99.
    test('poison (maxValue: 10) clampe à 10, pas à 99', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'poison', 150);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['poison'], 10);
    });

    // Test DISCRIMINANT (brief tâche 3) : sans lui, remplacer le plafond de
    // `updateCounter` par une constante 10 (au lieu de lire
    // `CounterType.maxValue`) passerait inaperçu -- seul ce cas, sur un
    // compteur SANS `maxValue`, distingue "le plafond suit la définition du
    // compteur" de "le plafond est une constante 10 écrite ailleurs".
    // `energy` (`CounterType.builtInCounters`) n'a pas de `maxValue` :
    // illimité, donc replié sur 99.
    test(
        'un compteur sans maxValue (energy) sature toujours à 99 -- test '
        'discriminant du cas poison ci-dessus', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'energy', 150);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['energy'], 99);
    });

    test(
        'un compteur personnalisé avec maxValue: 3 sature à 3 (ni 10, ni 99)',
        () async {
      const custom = CounterType(
        id: 'custom_rage',
        name: 'Rage',
        emoji: '🔥',
        color: 0xFF8B0000,
        maxValue: 3,
      );
      await container.read(counterTypeServiceProvider).saveCustomType(custom);
      await container.read(counterCatalogProvider.notifier).load();

      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'custom_rage', 150);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['custom_rage'], 3);
    });

    // Le plancher à 0 tient dans les trois cas ci-dessus (avec maxValue 10,
    // sans maxValue, et avec un maxValue personnalisé à 3) : un plafond
    // différent ne doit jamais faire dériver le plancher, qui reste
    // indépendant de `CounterType.maxValue`.
    test('le plancher à 0 tient aussi pour un compteur sans maxValue', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'energy', -5);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['energy'], 0);
    });

    test(
        'le plancher à 0 tient aussi pour un compteur personnalisé avec '
        'maxValue: 3', () async {
      const custom = CounterType(
        id: 'custom_rage',
        name: 'Rage',
        emoji: '🔥',
        color: 0xFF8B0000,
        maxValue: 3,
      );
      await container.read(counterTypeServiceProvider).saveCustomType(custom);
      await container.read(counterCatalogProvider.notifier).load();

      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateCounter(0, 'custom_rage', -1);

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.counters['custom_rage'], 0);
    });
  });

  group('eliminatePlayer', () {
    test('marks player as eliminated', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().eliminatePlayer(2, atDuration: const Duration(minutes: 15));

      final session = container.read(gameSessionNotifierProvider)!;
      expect(session.players[2].isEliminated, isTrue);
      expect(session.eliminationOrder, [2]);
    });
  });

  group('updateLife - couverture complète', () {
    test('decreases life', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateLife(0, -3, gameDuration: const Duration(minutes: 2));

      final player = container.read(gameSessionNotifierProvider)!.players[0];
      expect(player.life, 37);
    });

    test('does not affect other players', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().updateLife(0, -10, gameDuration: Duration.zero);

      final session = container.read(gameSessionNotifierProvider)!;
      expect(session.players[1].life, 40);
      expect(session.players[2].life, 40);
      expect(session.players[3].life, 40);
    });
  });

  group('toggleMonarch - couverture complète', () {
    test('toggles off if same player', () {
      getNotifier().startNewGame(format: commanderFormat, playerConfigs: configs);
      getNotifier().toggleMonarch(1);
      expect(
          container
              .read(gameSessionNotifierProvider)!
              .players[1]
              .isMonarch,
          isTrue);

      getNotifier().toggleMonarch(1);
      expect(
          container
              .read(gameSessionNotifierProvider)!
              .players[1]
              .isMonarch,
          isFalse);
    });
  });
}
