// Fichier : lib/providers/game_history_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_history_model.dart';
import 'service_providers.dart';

class GameHistoryNotifier extends AsyncNotifier<List<GameHistoryItem>> {
  @override
  Future<List<GameHistoryItem>> build() async {
    final service = ref.read(gameHistoryServiceProvider);
    return service.loadHistory();
  }

  Future<void> addGame(GameHistoryItem game) async {
    final service = ref.read(gameHistoryServiceProvider);
    await service.addGame(game);
    ref.invalidateSelf();
  }

  Future<void> clearHistory() async {
    final service = ref.read(gameHistoryServiceProvider);
    await service.clearHistory();
    state = const AsyncData([]);
  }

  Future<void> reload() async {
    ref.invalidateSelf();
  }
}

final gameHistoryProvider = AsyncNotifierProvider<GameHistoryNotifier, List<GameHistoryItem>>(
  GameHistoryNotifier.new,
);
