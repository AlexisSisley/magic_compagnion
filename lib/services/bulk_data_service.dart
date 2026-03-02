// Fichier : lib/services/bulk_data_service.dart
// Sprint 12, US-12.9 : Service de telechargement Bulk Data Scryfall en background.

import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scryfall_api_service.dart';

/// Metadonnees d'un fichier bulk data Scryfall.
class BulkDataInfo {
  final String type;
  final String name;
  final String description;
  final String downloadUri;
  final DateTime updatedAt;
  final int? compressedSize;

  const BulkDataInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.downloadUri,
    required this.updatedAt,
    this.compressedSize,
  });

  factory BulkDataInfo.fromJson(Map<String, dynamic> json) {
    return BulkDataInfo(
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      downloadUri: json['download_uri'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime(2000),
      compressedSize: json['compressed_size'] as int?,
    );
  }
}

/// Service de gestion du Bulk Data Scryfall (oracle-cards).
/// Permet de verifier les mises a jour et de telecharger en arriere-plan.
class BulkDataService {
  static const String _lastUpdateKey = 'bulk_data_last_update';
  static const String _bulkDataFileName = 'oracle-cards.json';
  static const String _bulkDataType = 'oracle-cards';

  final ScryfallApiService _api;
  final Dio _downloadDio;

  BulkDataService({
    required ScryfallApiService api,
    Dio? downloadDio,
  })  : _api = api,
        _downloadDio = downloadDio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
          headers: {
            'User-Agent': 'MagicCompanion/1.0',
          },
        ));

  /// Verifie si une mise a jour est disponible pour le bulk data.
  /// Compare la date de mise a jour distante avec la date locale.
  Future<bool> isUpdateAvailable() async {
    try {
      final remoteInfo = await getRemoteInfo();
      if (remoteInfo == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      if (lastUpdateStr == null) return true; // Jamais telecharge

      final lastUpdate = DateTime.tryParse(lastUpdateStr);
      if (lastUpdate == null) return true;

      return remoteInfo.updatedAt.isAfter(lastUpdate);
    } catch (e) {
      log('Error checking bulk data update: $e', name: 'BulkDataService');
      return false;
    }
  }

  /// Recupere les metadonnees du bulk data oracle-cards.
  Future<BulkDataInfo?> getRemoteInfo() async {
    try {
      final response = await _api.getBulkDataByType(_bulkDataType);
      return BulkDataInfo.fromJson(response);
    } catch (e) {
      log('Error fetching bulk data info: $e', name: 'BulkDataService');
      return null;
    }
  }

  /// Telecharge le fichier oracle-cards en background.
  /// [onProgress] est appele avec (bytesReceived, totalBytes).
  /// Retourne le chemin du fichier telecharge, ou null en cas d'erreur.
  Future<String?> downloadOracleCards({
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // 1. Obtenir l'URL de telechargement
      final info = await getRemoteInfo();
      if (info == null || info.downloadUri.isEmpty) {
        log('No download URI available', name: 'BulkDataService');
        return null;
      }

      // 2. Preparer le chemin de destination
      final appDir = await getApplicationDocumentsDirectory();
      final tempPath = '${appDir.path}/$_bulkDataFileName.tmp';
      final finalPath = '${appDir.path}/$_bulkDataFileName';

      // 3. Telecharger en streaming vers un fichier temporaire
      await _downloadDio.download(
        info.downloadUri,
        tempPath,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);
        },
      );

      // 4. Verifier l'integrite (taille > 0)
      final tempFile = File(tempPath);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        log('Downloaded file is empty or missing', name: 'BulkDataService');
        return null;
      }

      // 5. Remplacer l'ancien fichier
      final finalFile = File(finalPath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalPath);

      // 6. Enregistrer la date de mise a jour
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateKey, info.updatedAt.toIso8601String());

      log('Bulk data downloaded successfully: ${await File(finalPath).length()} bytes',
          name: 'BulkDataService');
      return finalPath;
    } catch (e) {
      log('Error downloading bulk data: $e', name: 'BulkDataService');
      return null;
    }
  }

  /// Retourne la date de la derniere mise a jour locale, ou null.
  Future<DateTime?> getLastUpdateDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastUpdateKey);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Retourne le chemin du fichier bulk data local, ou null s'il n'existe pas.
  Future<String?> getLocalFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$_bulkDataFileName');
    if (await file.exists()) return file.path;
    return null;
  }
}
