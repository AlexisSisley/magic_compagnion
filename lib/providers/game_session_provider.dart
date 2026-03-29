import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/controllers/game_session_controller.dart';
import 'package:magic_companion/widgets/life_counter/layouts/layout_strategy.dart';

final gameSessionControllerProvider = StateProvider<GameSessionController>((ref) {
  return GameSessionController();
});

final layoutPreferenceProvider = StateProvider<LayoutType?>((ref) => null);
