// Fichier : lib/services/edhrec_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class EdhrecService {
  
  // Correction de la génération du Slug pour EDHRec
  String _formatSlug(String name) {
    // 1. Minuscule
    String slug = name.toLowerCase();
    
    // 2. Gestion des cartes doubles (ex: "Jace // Jace") -> On garde la face avant
    if (slug.contains('//')) {
      slug = slug.split('//')[0];
    }

    // 3. Enlever tout ce qui n'est pas lettre, chiffre, espace ou tiret
    // Cela enlève les apostrophes ('), virgules (,), points (.) etc.
    // Ex: "Niv-Mizzet, Parun" -> "niv-mizzet parun"
    slug = slug.replaceAll(RegExp(r"[^a-z0-9\s\-]"), ""); 
    
    // 4. Nettoyer les espaces (Trim + Remplacement par tirets)
    // Ex: "niv-mizzet parun" -> "niv-mizzet-parun"
    slug = slug.trim().replaceAll(RegExp(r"\s+"), "-");
    
    return slug;
  }

  // Retourne maintenant une Map organisée par catégories
  Future<Map<String, List<String>>> getRecommendations(String commanderName) async {
    final slug = _formatSlug(commanderName);
    final url = Uri.parse("https://json.edhrec.com/pages/commanders/$slug.json");

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        if (!data.containsKey('container') || !data['container'].containsKey('json_dict')) {
          return {};
        }

        final cardLists = data['container']['json_dict']['cardlists'] as List<dynamic>;
        Map<String, List<String>> categorizedSuggestions = {};

        // Mapping des sections EDHRec vers nos titres
        final sectionsMap = {
          "High Synergy Cards": "🔥 Haute Synergie",
          "Top Cards": "🏆 Top Cartes",
          "Creatures": "🐉 Créatures",
          "Instants": "⚡ Éphémères",
          "Sorceries": "📜 Rituels",
          "Artifacts": "💎 Artefacts",
          "Enchantments": "✨ Enchantements",
          "Lands": "🏔️ Terrains",
          "Planeswalkers": "🧙 Planeswalkers",
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
        print("Erreur EDHRec ($slug): ${response.statusCode}");
        return {};
      }
    } catch (e) {
      print("Exception EDHRec: $e");
      return {};
    }
  }
}