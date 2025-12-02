// Fichier : lib/services/edhrec_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class EdhrecService {
  // L'API EDHRec utilise des "slugs" (noms formatés)
  // Ex: "Atraxa, Praetors' Voice" -> "atraxa-praetors-voice"
  
  String _formatSlug(String name) {
    String slug = name.toLowerCase();
    // slug = slug.replaceAll(RegExp(r"['\",\.]"), ")); // Enlever ponctuation
    slug = slug.replaceAll(RegExp(r"\s+"), "-"); // Espaces -> tirets
    slug = slug.replaceAll(RegExp(r"//.*"), ""); // Gérer les cartes doubles (garder 1ère face)
    if (slug.endsWith("-")) slug = slug.substring(0, slug.length - 1);
    return slug;
  }

  Future<List<String>> getRecommendations(String commanderName) async {
    final slug = _formatSlug(commanderName);
    final url = Uri.parse("https://json.edhrec.com/pages/commanders/$slug.json");

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        // Structure EDHRec : container -> json_dict -> cardlists -> [ {header: "High Synergy", cardviews: [...] } ]
        if (!data.containsKey('container') || !data['container'].containsKey('json_dict')) {
          return [];
        }

        final cardLists = data['container']['json_dict']['cardlists'] as List<dynamic>;
        List<String> suggestedCardNames = [];

        // On cible les sections pertinentes
        final sectionsOfInterest = ["High Synergy Cards", "Top Cards", "Creatures", "Instants", "Sorceries"];

        for (var section in cardLists) {
          if (sectionsOfInterest.contains(section['header'])) {
            final cards = section['cardviews'] as List<dynamic>;
            for (var card in cards) {
              // EDHRec donne le nom de la carte
              suggestedCardNames.add(card['name']);
            }
          }
        }
        
        // On dédoublonne
        return suggestedCardNames.toSet().toList();
      } else {
        print("Erreur EDHRec: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Exception EDHRec: $e");
      return [];
    }
  }
}