// Fichier : lib/services/scan_history_service.dart

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import '../models/scan_history_model.dart';

class ScanHistoryService {
  static const _historyKey = 'scan_history';
  static const _maxHistoryItems = 50;
  final AppDatabase? _db;

  ScanHistoryService({AppDatabase? database}) : _db = database;

  /// Charge la liste des scans, du plus recent au plus ancien
  Future<List<ScanHistoryItem>> loadHistory() async {
    if (_db != null) {
      final items = await _db.getAllScanHistory();
      return items.map((item) => ScanHistoryItem(
        scryfallId: item.scryfallId,
        cardName: item.cardName,
        imagePath: item.imagePath,
        timestamp: item.timestamp,
      )).toList();
    }
    // Fallback SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_historyKey);
    if (historyJson == null) {
      return [];
    }
    final List<dynamic> decodedList = json.decode(historyJson) as List;
    return decodedList.map((jsonItem) => ScanHistoryItem.fromJson(jsonItem)).toList();
  }

  /// Sauvegarde la liste complete (mode SharedPreferences uniquement)
  Future<void> _saveHistory(List<ScanHistoryItem> history) async {
    if (_db != null) return;
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        history.map((item) => item.toJson()).toList();
    final String historyJson = json.encode(jsonList);
    await prefs.setString(_historyKey, historyJson);
  }

  /// Ajoute un nouveau scan en haut de la liste
  Future<void> addScan(ScanHistoryItem newItem) async {
    if (_db != null) {
      await _db.insertScanHistory(ScanHistoryItemsCompanion.insert(
        scryfallId: newItem.scryfallId,
        cardName: newItem.cardName,
        imagePath: Value(newItem.imagePath),
        timestamp: newItem.timestamp,
      ));
      return;
    }
    // Fallback SharedPreferences
    final history = await loadHistory();
    history.insert(0, newItem);
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    await _saveHistory(history);
  }

  /// Vide l'historique complet
  Future<void> clearHistory() async {
    if (_db != null) {
      await _db.clearScanHistory();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
