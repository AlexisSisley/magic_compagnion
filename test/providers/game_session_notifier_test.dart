// test/providers/game_session_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';

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
}
