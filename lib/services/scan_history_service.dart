// Fichier : lib/services/scan_history_service.dart
// NOUVEAU FICHIER

import 'dart:convert';
import 'package:magic_companion/models/scan_history_model.dart'; // Notre nouveau modèle
import 'package:shared_preferences/shared_preferences.dart';

class ScanHistoryService {
  static const _historyKey = 'scan_history'; // Clé de sauvegarde unique
  static const _maxHistoryItems = 50; // Limite le nombre d'items à 50

  /// Charge la liste des scans, du plus récent au plus ancien
  Future<List<ScanHistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_historyKey);

    if (historyJson == null) {
      return [];
    }

    final List<dynamic> decodedList = json.decode(historyJson) as List;
    return decodedList.map((jsonItem) => ScanHistoryItem.fromJson(jsonItem)).toList();
  }

  /// Sauvegarde la liste complète
  Future<void> _saveHistory(List<ScanHistoryItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        history.map((item) => item.toJson()).toList();
    final String historyJson = json.encode(jsonList);
    await prefs.setString(_historyKey, historyJson);
  }

  /// Ajoute un nouveau scan en haut de la liste
  Future<void> addScan(ScanHistoryItem newItem) async {
    // 1. Charge l'historique actuel
    final history = await loadHistory();

    // 2. Ajoute le nouvel item au DÉBUT de la liste (pour le plus récent en premier)
    history.insert(0, newItem);

    // 3. Limite la taille de l'historique (optionnel)
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    // 4. Sauvegarde la nouvelle liste
    await _saveHistory(history);
  }
  
  /// Vide l'historique complet
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}