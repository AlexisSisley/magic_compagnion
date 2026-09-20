// lib/widgets/life_counter/snapshot_writer.dart
// Écriture différée du snapshot de partie.
//
// Rassemble ce qui vivait en trois champs de LifeCounterPage :
//   - le Timer de débounce (les mutations arrivent par rafales, un tap = une
//     mutation, et sérialiser la session à chaque fois coûte une I/O par tap) ;
//   - la session capturée à l'ordonnancement, pour que le démontage n'ait pas
//     à relire un provider (interdit dans dispose sur un ConsumerState) ;
//   - le Future de l'écriture déjà partie, que Timer.cancel() ne peut plus
//     rattraper et qu'un effacement de fin de partie doit attendre, sans quoi
//     une écriture retardataire ressusciterait la partie terminée.

import 'dart:async';

import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/services/game_session_service.dart';

class SnapshotWriter {
  SnapshotWriter(
    this._service, {
    this.debounce = const Duration(milliseconds: 500),
    this.onWritten,
  });

  final GameSessionService _service;
  final Duration debounce;

  /// Appele APRES chaque ecriture reellement partie.
  ///
  /// Sert a invalider `activeGameProvider`, qui ne surveille pas
  /// SharedPreferences. Le brancher ici plutot que sur `schedule()` est le
  /// point : l'ecriture est debouncee, donc invalider a l'ordonnancement
  /// ferait relire l'ANCIEN snapshot. Et le brancher ici plutot que sur
  /// chacun des 23 sites d'appel de `_saveSnapshot` evite qu'un 24e site
  /// oublie de le faire.
  final void Function()? onWritten;

  Timer? _timer;
  GameSession? _pending;
  Future<void>? _inFlight;

  /// Programme une écriture. Seule la dernière d'une rafale part.
  void schedule(GameSession session) {
    _pending = session;
    _timer?.cancel();
    _timer = Timer(debounce, _flush);
  }

  /// Écrit tout de suite ce qui est en attente, sans attendre le débounce.
  Future<void> flushNow() async {
    _timer?.cancel();
    _timer = null;
    _flush();
    await _inFlight;
  }

  /// Annule ce qui est programmé **et** attend ce qui est déjà parti.
  ///
  /// L'attente est le point important : sans elle, un effacement de fin de
  /// partie pourrait précéder une écriture en vol, qui ressusciterait alors
  /// la partie terminée au prochain lancement.
  Future<void> cancelPending() async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    await _inFlight;
  }

  /// À appeler depuis `dispose()` : synchrone, l'écriture part sans être
  /// attendue. Ne touche à aucun provider.
  void disposeAndFlush() {
    _timer?.cancel();
    _timer = null;
    _flush();
  }

  void _flush() {
    final session = _pending;
    _pending = null;
    if (session == null) return;

    // Le champ est renseigné avant tout point de suspension : en Dart, l'appel
    // d'une fonction async ne suspend pas l'appelant avant son premier await
    // interne, donc personne ne peut observer _inFlight à null entre les deux.
    final write = _service.saveSnapshot(session);
    _inFlight = write;
    write.whenComplete(() {
      if (identical(_inFlight, write)) _inFlight = null;
      onWritten?.call();
    });
  }
}
