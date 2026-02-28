// Fichier : lib/services/set_service.dart

import 'dart:developer';
import '../models/scryfall_set_model.dart';
import 'scryfall_api_service.dart';

class SetService {
  final ScryfallApiService? _api;

  SetService({ScryfallApiService? api}) : _api = api;

  Future<List<ScryfallSet>> getAllSets() async {
    try {
      final data = await _getApi().getAllSets();
      final List<dynamic> setsJson = data['data'] ?? [];

      return setsJson
          .map((json) => ScryfallSet.fromJson(json))
          .toList();
    } catch (e) {
      log('Erreur SetService: $e', name: 'SetService');
      return [];
    }
  }

  ScryfallApiService _getApi() => _api ?? ScryfallApiService();
}
