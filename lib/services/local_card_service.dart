// Fichier : lib/services/local_card_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/scryfall_card_model.dart';

class LocalCardService {
  static final LocalCardService _instance = LocalCardService._internal();
  factory LocalCardService() => _instance;
  LocalCardService._internal();

  List<ScryfallCard> _cachedCards = [];
  // AJOUT : Une Map pour l'accès instantané par ID
  final Map<String, ScryfallCard> _idMap = {}; 
  
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  Future<void> loadLocalData() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    try {
      // Assurez-vous d'avoir oracle-cards.json ou unique-artwork.json
      final String jsonString = await rootBundle.loadString('assets/json/oracle-cards.json');
      
      final List<ScryfallCard> parsedCards = await compute(_parseCards, jsonString);

      _cachedCards = parsedCards;
      
      // AJOUT : Remplissage de la Map pour les recherches par ID rapides
      for (var card in _cachedCards) {
        _idMap[card.id] = card;
      }

      _isLoaded = true;
      debugPrint("Données locales chargées : ${_cachedCards.length} cartes.");
    } catch (e) {
      debugPrint("Erreur chargement données locales : $e");
    } finally {
      _isLoading = false;
    }
  }

  static List<ScryfallCard> _parseCards(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((jsonItem) => ScryfallCard.fromJson(jsonItem)).toList();
  }

  // --- NOUVELLE MÉTHODE ---
  /// Récupère une carte directement par son ID Scryfall (instantané)
  ScryfallCard? getCardById(String id) {
    return _idMap[id];
  }

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
      if (lowerQuery.isNotEmpty && !card.name.toLowerCase().contains(lowerQuery)) {
        return false;
      }
      if (lowerType != null && !card.typeLine.toLowerCase().contains(lowerType)) {
        return false;
      }
      if (lowerSet != null && card.setCode.toLowerCase() != lowerSet) {
        return false;
      }
      if (colors.isNotEmpty) {
        final cardColors = card.colorIdentity.toSet();
        if (!colors.every((c) => cardColors.contains(c))) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}