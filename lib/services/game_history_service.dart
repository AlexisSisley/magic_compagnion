import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_history_model.dart';

class GameHistoryService {
  static const _key = 'game_history';

  Future<List<GameHistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((e) => GameHistoryItem.fromJson(e)).toList();
  }

  Future<void> addGame(GameHistoryItem game) async {
    final history = await loadHistory();
    history.insert(0, game); // Plus récent en premier
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
  
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}