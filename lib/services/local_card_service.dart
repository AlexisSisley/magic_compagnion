// Fichier : lib/services/local_card_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart'; // Pour compute
import 'package:flutter/services.dart' show rootBundle;
import '../models/scryfall_card_model.dart';

class LocalCardService {
  static final LocalCardService _instance = LocalCardService._internal();
  factory LocalCardService() => _instance;
  LocalCardService._internal();

  List<ScryfallCard> _cachedCards = [];
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Charge le fichier JSON (oracle-cards.json est recommandé pour la recherche)
  /// Cette opération est lourde et se fait dans un Isolate.
  Future<void> loadLocalData() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    try {
      // 1. Lire le fichier en string (rapide)
      // Assurez-vous que le fichier est bien dans assets/json/oracle-cards.json
      final String jsonString = await rootBundle.loadString('assets/json/oracle-cards.json');

      // 2. Parser le JSON dans un thread séparé (lourd)
      // On utilise 'compute' pour éviter de geler l'UI
      final List<ScryfallCard> parsedCards = await compute(_parseCards, jsonString);

      _cachedCards = parsedCards;
      _isLoaded = true;
      debugPrint("Données locales chargées : ${_cachedCards.length} cartes.");
    } catch (e) {
      debugPrint("Erreur chargement données locales : $e");
    } finally {
      _isLoading = false;
    }
  }

  /// Fonction statique isolée pour le parsing
  static List<ScryfallCard> _parseCards(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((jsonItem) => ScryfallCard.fromJson(jsonItem)).toList();
  }

  /// Recherche locale optimisée
  List<ScryfallCard> searchCards({
    required String query,
    String? setCode,
    String? cardType,
    Set<String> colors = const {},
  }) {
    if (!_isLoaded) return [];

    final lowerQuery = query.toLowerCase().trim();
    final lowerType = cardType?.toLowerCase();
    final lowerSet = setCode?.toLowerCase();

    return _cachedCards.where((card) {
      // 1. Filtre Nom (Si query vide, on passe, sauf si on a d'autres filtres)
      if (lowerQuery.isNotEmpty && !card.name.toLowerCase().contains(lowerQuery)) {
        return false;
      }

      // 2. Filtre Type
      if (lowerType != null && !card.typeLine.toLowerCase().contains(lowerType)) {
        return false;
      }

      // 3. Filtre Set (Attention: oracle-cards contient 1 seule version par carte)
      // Si tu utilises oracle-cards.json, ce filtre peut ne pas trouver la version précise du set.
      // Si tu utilises unique-artwork.json, ça marchera mieux mais c'est plus lourd.
      if (lowerSet != null && card.setCode.toLowerCase() != lowerSet) {
        return false;
      }

      // 4. Filtre Couleurs (Contient TOUTES les couleurs demandées)
      if (colors.isNotEmpty) {
        final cardColors = card.colorIdentity.toSet();
        if (!colors.every((c) => cardColors.contains(c))) {
          return false;
        }
      }

      return true;
    }).take(50).toList(); // Limite à 50 résultats pour l'affichage
  }
}