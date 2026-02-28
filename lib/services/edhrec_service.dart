// Fichier : lib/services/edhrec_service.dart

import 'dart:developer';
import 'package:dio/dio.dart';

class EdhrecService {
  final Dio _dio;

  EdhrecService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://json.edhrec.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': 'MagicCompanion/1.0'},
            ));

  // Correction de la génération du Slug pour EDHRec
  String _formatSlug(String name) {
    // 1. Minuscule
    String slug = name.toLowerCase();

    // 2. Gestion des cartes doubles (ex: "Jace // Jace") -> On garde la face avant
    if (slug.contains('//')) {
      slug = slug.split('//')[0];
    }

    // 3. Enlever tout ce qui n'est pas lettre, chiffre, espace ou tiret
    slug = slug.replaceAll(RegExp(r"[^a-z0-9\s\-]"), "");

    // 4. Nettoyer les espaces
    slug = slug.trim().replaceAll(RegExp(r"\s+"), "-");

    return slug;
  }

  // Retourne une Map organisée par catégories
  Future<Map<String, List<String>>> getRecommendations(String commanderName) async {
    final slug = _formatSlug(commanderName);

    try {
      final response = await _dio.get('/pages/commanders/$slug.json');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {};

        if (!data.containsKey('container') || !data['container'].containsKey('json_dict')) {
          return {};
        }

        final cardLists = data['container']['json_dict']['cardlists'] as List<dynamic>;
        Map<String, List<String>> categorizedSuggestions = {};

        // Mapping des sections EDHRec vers nos titres
        final sectionsMap = {
          'High Synergy Cards': 'Haute Synergie',
          'Top Cards': 'Top Cartes',
          'Creatures': 'Créatures',
          'Instants': 'Éphémères',
          'Sorceries': 'Rituels',
          'Artifacts': 'Artefacts',
          'Enchantments': 'Enchantements',
          'Lands': 'Terrains',
          'Planeswalkers': 'Planeswalkers',
        };

        for (var section in cardLists) {
          final header = section['header'];
          if (sectionsMap.containsKey(header)) {
            final String categoryTitle = sectionsMap[header]!;
            final cards = section['cardviews'] as List<dynamic>;

            List<String> cardNames = [];
            for (var card in cards) {
              cardNames.add(card['name']);
            }

            if (cardNames.isNotEmpty) {
              categorizedSuggestions[categoryTitle] = cardNames;
            }
          }
        }

        return categorizedSuggestions;
      } else {
        log('Erreur EDHRec ($slug): ${response.statusCode}', name: 'EdhrecService');
        return {};
      }
    } catch (e) {
      log('Exception EDHRec: $e', name: 'EdhrecService');
      return {};
    }
  }
}
