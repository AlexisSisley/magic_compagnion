// Fichier : lib/services/local_card_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Nécessaire pour compute
import 'package:flutter/services.dart' show rootBundle;
import '../models/scryfall_card_model.dart';
import '../models/search_filters.dart'; // Assure-toi d'avoir cet import pour les filtres

// --- CLASSE D'ARGUMENTS POUR L'ISOLATE ---
class SearchArguments {
  final List<ScryfallCard> cards;
  final String query;
  final SearchFilters? filters;

  SearchArguments(this.cards, this.query, this.filters);
}

// --- FONCTION TOP-LEVEL (HORS DE LA CLASSE) ---
List<ScryfallCard> _executeSearch(SearchArguments args) {
  final lowerQuery = args.query.toLowerCase().trim();
  final filters = args.filters;
  
  final lowerType = filters?.cardType?.toLowerCase();
  final lowerSet = filters?.setCode?.toLowerCase();
  final colors = filters?.colors ?? {};
  final rarity = filters?.rarity;
  final minCmc = filters?.minCmc;
  final maxCmc = filters?.maxCmc;
  final lowerKeyword = filters?.keyword?.toLowerCase(); // <--- NOUVEAU
  
  return args.cards.where((card) {
    // 1. Filtre Texte (Nom)
    if (lowerQuery.isNotEmpty) {
      bool matchName = card.name.toLowerCase().contains(lowerQuery);
      bool matchPrinted = card.printedName?.toLowerCase().contains(lowerQuery) ?? false;
      if (!matchName && !matchPrinted) return false;
    }

    // 2. Filtres Avancés
    if (lowerType != null && !card.typeLine.toLowerCase().contains(lowerType)) return false;
    if (lowerSet != null && card.setCode.toLowerCase() != lowerSet) return false;
    if (rarity != null && card.rarity != rarity) return false;
    
    if (minCmc != null && (card.cmc ?? 0) < minCmc) return false;
    if (maxCmc != null && (card.cmc ?? 0) > maxCmc) return false;

    if (colors.isNotEmpty) {
      final cardColors = card.colorIdentity.toSet();
      // "Doit contenir toutes les couleurs sélectionnées" (Logique restrictive)
      if (!colors.every((c) => cardColors.contains(c))) return false;
    }
    
    // --- AJOUT FILTRE KEYWORD ---
    if (lowerKeyword != null && lowerKeyword.isNotEmpty) {
      if (!card.rulesText.toLowerCase().contains(lowerKeyword)) return false;
    }
    
    return true;
  }).toList();
}

class LocalCardService {
  static final LocalCardService _instance = LocalCardService._internal();
  factory LocalCardService() => _instance;
  LocalCardService._internal();

  List<ScryfallCard> _cachedCards = [];
  final Map<String, ScryfallCard> _idMap = {};
  final Map<String, ScryfallCard> _nameMap = {};
  
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadLocalData() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    try {
      final String jsonString = await rootBundle.loadString('assets/json/oracle-cards.json');
      // On utilise compute ici aussi pour le parsing initial
      final List<ScryfallCard> parsedCards = await compute(_parseCards, jsonString);

      _cachedCards = parsedCards;
      for (var card in _cachedCards) {
        _idMap[card.id] = card;
        String lowerName = card.name.toLowerCase();
        _nameMap[lowerName] = card;
        if (lowerName.contains(' // ')) {
          final parts = lowerName.split(' // ');
          if (parts.isNotEmpty) {
            // On fait pointer "fire" vers la carte complète "Fire // Ice"
            _nameMap[parts[0].trim()] = card;
          }
        }
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

  ScryfallCard? getCardById(String id) => _idMap[id];
  ScryfallCard? getCardByName(String name) => _nameMap[name.toLowerCase().trim()]; // Ajout du trim() par sécurité

  // --- RECHERCHE ASYNCHRONE OPTIMISÉE ---
  Future<List<ScryfallCard>> searchCards({
    required String query,
    SearchFilters? filters, // J'ai regroupé les paramètres optionnels dans l'objet existant
  }) async {
    if (!_isLoaded) return [];

    // On lance le calcul sur un autre thread
    return await compute(
      _executeSearch, 
      SearchArguments(_cachedCards, query, filters)
    );
  }

  // Version simplifiée pour le smart match (peut rester synchrone si petite liste, ou passer en compute aussi)
  List<ScryfallCard> findSmartMatch(String query, {int limit = 5}) {
    if (!_isLoaded || query.trim().isEmpty) return [];
    
    // (Garder ta logique de tokens ici...)
    final List<String> tokens = query.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();
    if (tokens.isEmpty) return [];

    final List<Map<String, dynamic>> scoredCards = [];
    for (final card in _cachedCards) {
      int score = 0;
      final String name = card.name.toLowerCase();
      final String printed = card.printedName?.toLowerCase() ?? '';
      for (final token in tokens) {
        if (name.contains(token) || printed.contains(token)) score++;
      }
      if (score > 0) scoredCards.add({'card': card, 'score': score});
    }
    scoredCards.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scoredCards.take(limit).map((item) => item['card'] as ScryfallCard).toList();
  }
}