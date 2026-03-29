import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/controllers/game_session_controller.dart';

final gameSessionControllerProvider = Provider<GameSessionController>((ref) {
  return GameSessionController();
});
