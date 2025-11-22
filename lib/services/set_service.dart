// Fichier : lib/services/set_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scryfall_set_model.dart';

class SetService {
  static const String _baseUrl = 'https://api.scryfall.com/sets';

  Future<List<ScryfallSet>> getAllSets() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> setsJson = data['data'] ?? [];
        
        return setsJson
            .map((json) => ScryfallSet.fromJson(json))
            .toList();
      } else {
        throw Exception('Erreur chargement sets: ${response.statusCode}');
      }
    } catch (e) {
      print("Erreur SetService: $e");
      return [];
    }
  }
}