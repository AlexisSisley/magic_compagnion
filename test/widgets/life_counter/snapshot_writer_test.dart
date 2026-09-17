// test/widgets/life_counter/snapshot_writer_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/last_table.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/services/game_session_service.dart';
import 'package:magic_companion/widgets/life_counter/snapshot_writer.dart';

class _RecordingService implements GameSessionService {
  final saved = <GameSession>[];
  var cleared = 0;
  Completer<void>? gate;

  @override
  Future<void> saveSnapshot(GameSession session) async {
    saved.add(session);
    if (gate != null) await gate!.future;
  }

  @override
  Future<GameSession?> loadSnapshot() async => null;

  @override
  Future<bool> hasActiveGame() async => false;

  @override
  Future<void> clearSnapshot() async => cleared++;

  // `SnapshotWriter` ne touche jamais a l'enregistrement de derniere table :
  // ces trois membres n'existent que pour satisfaire l'interface.
  @override
  Future<void> saveLastTable(LastTable table) async {}

  @override
  Future<LastTable?> loadLastTable() async => null;

  @override
  Future<void> clearLastTable() async {}
}

GameSession sessionWithLife(int life) {
  final base = GameSession.newGame(
    format: GameFormat.builtInFormats.first,
    playerConfigs: [
      PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
      PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
    ],
  );
  return base.copyWith(
    players: [base.players[0].copyWith(life: life), base.players[1]],
  );
}

void main() {
  test('une rafale ne produit qu\'une écriture, avec le dernier état',
      () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(milliseconds: 20));

    for (var life = 39; life >= 30; life--) {
      writer.schedule(sessionWithLife(life));
    }
    expect(service.saved, isEmpty, reason: 'rien avant expiration du débounce');

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(service.saved, hasLength(1));
    expect(service.saved.single.players[0].life, 30);
  });

  test('flushNow écrit immédiatement sans attendre le débounce', () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(seconds: 10));
    writer.schedule(sessionWithLife(35));
    await writer.flushNow();
    expect(service.saved, hasLength(1));
    expect(service.saved.single.players[0].life, 35);
  });

  test('cancelPending attend une écriture déjà en vol', () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(milliseconds: 10));
    service.gate = Completer<void>();

    writer.schedule(sessionWithLife(33));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.saved, hasLength(1), reason: 'l\'écriture est partie');

    var cancelDone = false;
    final cancel = writer.cancelPending().then((_) => cancelDone = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cancelDone, isFalse,
        reason: 'cancelPending doit attendre l\'écriture en vol, sinon un '
            'effacement pourrait précéder une écriture retardataire');

    service.gate!.complete();
    await cancel;
    expect(cancelDone, isTrue);
  });

  test('cancelPending empêche une écriture programmée non encore partie',
      () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(milliseconds: 50));
    writer.schedule(sessionWithLife(31));
    await writer.cancelPending();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(service.saved, isEmpty);
  });

  test('disposeAndFlush écrit ce qui était en attente', () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(seconds: 10));
    writer.schedule(sessionWithLife(29));
    writer.disposeAndFlush();
    await Future<void>.delayed(Duration.zero);
    expect(service.saved, hasLength(1));
    expect(service.saved.single.players[0].life, 29);
  });
}
