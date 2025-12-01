// Fichier : lib/services/backup_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BackupService {
  static const List<String> _dataKeys = [
    'user_collection',
    'user_decks',
    'user_wishlists_v2', // Mise à jour pour la v2
    'user_wishlist',     // Gardé pour legacy
    'scan_history',
    'glossaryLang',
    'playerCount',
    'startingLife'
  ];

  /// 1. Génère la chaîne JSON de sauvegarde (Utilisé par Export fichier ET Drive)
  Future<String> generateBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> backupData = {};

    for (String key in _dataKeys) {
      final String? value = prefs.getString(key);
      if (value != null) {
        try {
          backupData[key] = json.decode(value);
        } catch (e) {
          backupData[key] = value;
        }
      } else if (prefs.getInt(key) != null) {
        backupData[key] = prefs.getInt(key);
      }
    }

    backupData['backup_date'] = DateTime.now().toIso8601String();
    backupData['app_version'] = '1.0.0';

    return json.encode(backupData);
  }

  /// 2. Restaure les données depuis une chaîne JSON (Utilisé par Import fichier ET Drive)
  Future<void> restoreFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      final prefs = await SharedPreferences.getInstance();
      
      for (String key in _dataKeys) {
        if (data.containsKey(key)) {
          final dynamic value = data[key];
          if (value is Map || value is List) {
            await prefs.setString(key, json.encode(value));
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          }
        }
      }
    } catch (e) {
      print("Erreur restauration JSON: $e");
      throw Exception("Données corrompues.");
    }
  }

  // --- MÉTHODES EXISTANTES (ADAPTÉES) ---

  Future<void> exportData() async {
    final String jsonString = await generateBackupJson();
    
    final Directory tempDir = await getTemporaryDirectory();
    final String dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final File file = File('${tempDir.path}/magic_companion_backup_$dateStr.json');
    
    await file.writeAsString(jsonString);
    await Share.shareXFiles([XFile(file.path)], text: 'Ma sauvegarde Magic Companion');
  }

  Future<bool> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return false;

      final File file = File(result.files.single.path!);
      final String content = await file.readAsString();
      
      await restoreFromJson(content);
      return true;
    } catch (e) {
      print("Erreur import fichier: $e");
      return false;
    }
  }
}