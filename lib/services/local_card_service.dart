// Fichier : lib/services/local_card_service.dart
// VERSION MISE À JOUR : Recherche "Smart" par mots-clés

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/scryfall_card_model.dart';

class LocalCardService {
  static final LocalCardService _instance = LocalCardService._internal();
  factory LocalCardService() => _instance;
  LocalCardService._internal();

  List<ScryfallCard> _cachedCards = [];
  final Map<String, ScryfallCard> _idMap = {}; 
  
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  Future<void> loadLocalData() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    try {
      final String jsonString = await rootBundle.loadString('assets/json/oracle-cards.json');
      final List<ScryfallCard> parsedCards = await compute(_parseCards, jsonString);

      _cachedCards = parsedCards;
      
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

  ScryfallCard? getCardById(String id) {
    return _idMap[id];
  }

  // Recherche standard (Filtres + Contient)
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
      // Nom ou Nom Imprimé (FR)
      bool matchName = card.name.toLowerCase().contains(lowerQuery);
      bool matchPrinted = card.printedName?.toLowerCase().contains(lowerQuery) ?? false;

      if (lowerQuery.isNotEmpty && !matchName && !matchPrinted) {
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

  // --- NOUVEAU : RECHERCHE INTELLIGENTE (Score par mots-clés) ---
  /// Découpe la query en mots et cherche les cartes qui contiennent le plus de mots communs.
  /// Utile pour l'OCR imparfait (ex: "L'Ange de Serra 4/4" -> trouve "Ange de Serra")
  List<ScryfallCard> findSmartMatch(String query, {int limit = 5}) {
    if (!_isLoaded || query.trim().isEmpty) return [];

    // 1. Nettoyage et découpage ("Tokenization")
    final List<String> tokens = query.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Enlève ponctuation
        .split(RegExp(r'\s+')) // Coupe par espace
        .where((t) => t.length > 2) // Ignore les mots courts (le, de, un...)
        .toList();

    if (tokens.isEmpty) return [];

    // 2. Calcul des scores
    final List<Map<String, dynamic>> scoredCards = [];

    for (final card in _cachedCards) {
      int score = 0;
      final String name = card.name.toLowerCase();
      final String printed = card.printedName?.toLowerCase() ?? '';

      for (final token in tokens) {
        if (name.contains(token) || printed.contains(token)) {
          score++;
        }
      }

      // On ne garde que si au moins un mot pertinent est trouvé
      if (score > 0) {
        scoredCards.add({'card': card, 'score': score});
      }
    }

    // 3. Tri par score décroissant (le meilleur match en premier)
    scoredCards.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    // 4. Retourne les meilleurs résultats
    return scoredCards.take(limit).map((item) => item['card'] as ScryfallCard).toList();
  }
}