// Fichier : lib/services/backup_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BackupService {
  // Liste des clés SharedPreferences utilisées dans l'app
  static const List<String> _dataKeys = [
    'user_collection', // CollectionService
    'user_decks',      // DeckService
    'user_wishlist',   // WishlistService
    'scan_history',    // ScanHistoryService
    // On peut ajouter les préférences simples si besoin
    'glossaryLang',
    'playerCount',
    'startingLife'
  ];

  /// Génère un fichier JSON contenant toutes les données et lance le partage
  Future<void> exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> backupData = {};

    // 1. Récupération des données
    for (String key in _dataKeys) {
      final String? value = prefs.getString(key);
      if (value != null) {
        // On essaie de décoder pour vérifier que c'est du JSON valide, ou on sauvegarde brut
        try {
          backupData[key] = json.decode(value);
        } catch (e) {
          // Si c'est une primitive (int, bool stocké en string...), on garde tel quel
          backupData[key] = value;
        }
      }
      // Gestion des entiers (ex: playerCount)
      else if (prefs.getInt(key) != null) {
        backupData[key] = prefs.getInt(key);
      }
    }

    // Ajout de métadonnées
    backupData['backup_date'] = DateTime.now().toIso8601String();
    backupData['app_version'] = '1.0.0';

    // 2. Création du fichier
    final String jsonString = json.encode(backupData);
    final Directory tempDir = await getTemporaryDirectory();
    final String dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final File file = File('${tempDir.path}/magic_companion_backup_$dateStr.json');
    
    await file.writeAsString(jsonString);

    // 3. Partage du fichier (Drive, Email, Local...)
    await Share.shareXFiles([XFile(file.path)], text: 'Ma sauvegarde Magic Companion');
  }

  /// Ouvre un sélecteur de fichier et restaure les données
  Future<bool> importData() async {
    try {
      // 1. Sélection du fichier
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return false; // Annulé par l'utilisateur
      }

      final File file = File(result.files.single.path!);
      final String content = await file.readAsString();
      final Map<String, dynamic> data = json.decode(content);

      // 2. Restauration
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
      return true;
    } catch (e) {
      print("Erreur import: $e");
      throw Exception("Fichier invalide ou corrompu.");
    }
  }
}