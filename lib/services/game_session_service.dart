// lib/services/game_session_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/last_table.dart';

class GameSessionService {
  static const _snapshotKey = 'active_game_snapshot';
  static const _lastTableKey = 'last_table';

  Future<void> saveSnapshot(GameSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(session.toJson());
    await prefs.setString(_snapshotKey, jsonStr);
  }

  Future<GameSession?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_snapshotKey);
    if (jsonStr == null) return null;
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return GameSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasActiveGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_snapshotKey);
  }

  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
  }

  Future<void> saveLastTable(LastTable table) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(table.toJson());
    await prefs.setString(_lastTableKey, jsonStr);
  }

  Future<LastTable?> loadLastTable() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_lastTableKey);
    if (jsonStr == null) return null;
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return LastTable.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLastTable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastTableKey);
  }
}
