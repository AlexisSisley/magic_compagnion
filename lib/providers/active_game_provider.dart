// Fichier : lib/providers/active_game_provider.dart
// Expose le snapshot de partie en cours a l'UI.
//
// Rien a persister ici : GameSessionService ecrit deja le snapshot dans
// SharedPreferences a chaque modification. Ce provider ne fait que le lire,
// pour que l'Accueil sache s'il doit afficher "Reprendre la partie".
//
// A invalider apres saveSnapshot() et apres clearSnapshot() : le provider ne
// surveille pas SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_session.dart';
import 'service_providers.dart';

final activeGameProvider = FutureProvider<GameSession?>((ref) async {
  return ref.watch(gameSessionServiceProvider).loadSnapshot();
});
