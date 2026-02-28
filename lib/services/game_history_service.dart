// Fichier : lib/services/game_history_service.dart

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import '../models/game_history_model.dart';

class GameHistoryService {
  static const _key = 'game_history';
  final AppDatabase? _db;

  GameHistoryService({AppDatabase? database}) : _db = database;

  Future<List<GameHistoryItem>> loadHistory() async {
    if (_db != null) {
      final items = await _db.getAllGameHistory();
      return items.map((item) {
        final List<dynamic> statesJson = json.decode(item.playerStates);
        return GameHistoryItem(
          id: item.id,
          date: item.date,
          durationSeconds: item.durationSeconds,
          winnerName: item.winnerName,
          format: item.format,
          winMethod: item.winMethod,
          playerStates: statesJson
              .map((e) => PlayerHistorySnapshot.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }).toList();
    }
    // Fallback SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((e) => GameHistoryItem.fromJson(e)).toList();
  }

  Future<void> addGame(GameHistoryItem game) async {
    if (_db != null) {
      await _db.insertGameHistory(GameHistoryItemsCompanion.insert(
        id: game.id,
        date: game.date,
        durationSeconds: Value(game.durationSeconds),
        winnerName: game.winnerName,
        format: Value(game.format),
        winMethod: Value(game.winMethod),
        playerStates: Value(json.encode(game.playerStates.map((p) => p.toJson()).toList())),
      ));
      return;
    }
    // Fallback SharedPreferences
    final history = await loadHistory();
    history.insert(0, game); // Plus recent en premier
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<void> clearHistory() async {
    if (_db != null) {
      await _db.clearGameHistory();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
