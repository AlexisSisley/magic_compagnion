import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/controllers/game_session_controller.dart';
import 'package:magic_companion/widgets/life_counter/layouts/layout_strategy.dart';

final gameSessionControllerProvider = Provider<GameSessionController>((ref) {
  return GameSessionController();
});

/// Notifier for layout preference (user can switch between grid/focus).
class LayoutPreferenceNotifier extends Notifier<LayoutType?> {
  @override
  LayoutType? build() => null;

  void setLayout(LayoutType? layout) => state = layout;
}

final layoutPreferenceProvider =
    NotifierProvider<LayoutPreferenceNotifier, LayoutType?>(
  LayoutPreferenceNotifier.new,
);
