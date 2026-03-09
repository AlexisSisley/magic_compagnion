// Fichier : lib/services/collection_service.dart

import 'dart:convert';
import 'dart:developer';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import '../models/deck_model.dart';
import 'scryfall_api_service.dart';
import '../utils/card_list_upsert_mixin.dart';

class CollectionService with CardListUpsertMixin {
  static const _collectionKey = 'user_collection';
  final AppDatabase? _db;
  final ScryfallApiService? _api;

  CollectionService({AppDatabase? database, ScryfallApiService? api})
      : _db = database,
        _api = api;

  Future<List<DeckCard>> loadCollection() async {
    if (_db != null) {
      final cards = await _db.getAllCollectionCards();
      return cards.map((c) => DeckCard(
        scryfallId: c.scryfallId,
        name: c.name,
        quantity: c.quantity,
        proxyQuantity: c.proxyQuantity,
        isFoil: c.isFoil,
        tags: AppDatabase.decodeTags(c.tags),
      )).toList();
    }
    // Fallback SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final String? collectionJson = prefs.getString(_collectionKey);
    if (collectionJson == null) return [];
    final List<dynamic> decodedList = json.decode(collectionJson) as List;
    return decodedList.map((jsonItem) => DeckCard.fromJson(jsonItem)).toList();
  }

  Future<void> _saveCollection(List<DeckCard> collection) async {
    if (_db != null) return; // Pas besoin avec drift, les ops sont atomiques
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = collection.map((card) => card.toJson()).toList();
    await prefs.setString(_collectionKey, json.encode(jsonList));
  }

  /// Ajoute ou modifie une carte dans la collection.
  /// Supporte la distinction Foil / Non-Foil.
  Future<List<DeckCard>> upsertCardInCollection({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool isFoil = false,
    List<String>? newTags,
  }) async {
    if (_db != null) {
      await _db.upsertCollectionCard(
        scryfallId: scryfallId,
        cardName: cardName,
        quantityToAdd: quantityToAdd,
        absoluteQuantity: absoluteQuantity,
        isFoil: isFoil,
        newTags: newTags,
      );
      return loadCollection();
    }
    // Fallback SharedPreferences
    final collection = await loadCollection();
    upsertCardInList(
      collection,
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: quantityToAdd,
      absoluteQuantity: absoluteQuantity,
      matchByFoil: true,
      isFoil: isFoil,
      newTags: newTags,
    );
    await _saveCollection(collection);
    return collection;
  }

   Future<void> addCard(ScryfallCard card, int quantity, {bool isFoil = false}) async {
      await upsertCardInCollection(
        scryfallId: card.id,
        cardName: card.name,
        quantityToAdd: quantity,
        isFoil: isFoil
      );
   }

   // --- IMPORTATION DE MASSE ---
   Future<Map<String, int>> importBatchCards(List<String> rawNames) async {
     final collection = await loadCollection();
     int addedCount = 0;
     int errorCount = 0;

     final RegExp regex = RegExp(r'^(\d+)?\s?x?\s?(.*)$');
     Map<String, int> cardsToFetch = {};

     for (String line in rawNames) {
       final match = regex.firstMatch(line.trim());
       if (match != null) {
         int q = int.tryParse(match.group(1) ?? '1') ?? 1;
         String name = match.group(2)?.trim() ?? line;
         if (name.isNotEmpty) {
           cardsToFetch[name] = (cardsToFetch[name] ?? 0) + q;
         }
       }
     }

     final List<String> uniqueNames = cardsToFetch.keys.toList();

     // Chunking (Paquets de 75)
     const int chunkSize = 75;
     for (var i = 0; i < uniqueNames.length; i += chunkSize) {
       final end = (i + chunkSize < uniqueNames.length) ? i + chunkSize : uniqueNames.length;
       final batchNames = uniqueNames.sublist(i, end);

       final identifiers = batchNames.map((name) => {'name': name}).toList();

       try {
         final apiService = _api ?? ScryfallApiService();
         final data = await apiService.fetchCollection(identifiers);
         {
           final List<dynamic> foundCards = data['data'] ?? [];

           for (var cardJson in foundCards) {
             final scCard = ScryfallCard.fromJson(cardJson);
             String originalKey = cardsToFetch.keys.firstWhere(
               (k) => scCard.name.toLowerCase().contains(k.toLowerCase()) || k.toLowerCase().contains(scCard.name.toLowerCase()),
               orElse: () => scCard.name
             );

             int qtyToAdd = cardsToFetch[originalKey] ?? 1;

             if (_db != null) {
               await _db.upsertCollectionCard(
                 scryfallId: scCard.id,
                 cardName: scCard.name,
                 quantityToAdd: qtyToAdd,
                 isFoil: false,
               );
             } else {
               upsertCardInList(collection, scryfallId: scCard.id, cardName: scCard.name, quantityToAdd: qtyToAdd, matchByFoil: true, isFoil: false);
             }
             addedCount += qtyToAdd;
           }
         }
       } catch (e) {
         log('Erreur batch import: $e');
         errorCount += batchNames.length;
       }

       await Future.delayed(const Duration(milliseconds: 100));
     }

     if (_db == null) {
       await _saveCollection(collection);
     }
     return {'added': addedCount, 'errors': errorCount};
   }

    // Gestion de l'historique financier
    Future<void> recordDailyValue(double totalValue) async {
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';

      if (_db != null) {
        await _db.recordDailyValue(todayKey, totalValue);
        return;
      }
      // Fallback SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? jsonHistory = prefs.getString('collection_value_history');
      Map<String, dynamic> history = jsonHistory != null ? json.decode(jsonHistory) : {};

      history[todayKey] = totalValue;

      // Nettoyage > 30 jours
      final sortedKeys = history.keys.toList()..sort();
      if (sortedKeys.length > 30) {
        for (int i = 0; i < sortedKeys.length - 30; i++) {
          history.remove(sortedKeys[i]);
        }
      }

      await prefs.setString('collection_value_history', json.encode(history));
    }

    Future<Map<String, double>?> getEvolutionSince(int daysAgo) async {
      if (_db != null) {
        return _db.getCollectionEvolution(daysAgo);
      }
      // Fallback SharedPreferences
       final prefs = await SharedPreferences.getInstance();
       String? jsonHistory = prefs.getString('collection_value_history');
       if (jsonHistory == null) return null;

       Map<String, dynamic> history = json.decode(jsonHistory);
       if (history.isEmpty) return null;

       final sortedKeys = history.keys.toList()..sort();
       final String todayKey = sortedKeys.last;
       final double currentValue = (history[todayKey] as num).toDouble();

       int targetIndex = sortedKeys.length - 1 - daysAgo;
       if (targetIndex < 0) targetIndex = 0;

       final String pastKey = sortedKeys[targetIndex];
       final double pastValue = (history[pastKey] as num).toDouble();

       double diffValue = currentValue - pastValue;
       double diffPercentage = pastValue > 0 ? (diffValue / pastValue) * 100 : 0.0;

       return {
         'currentValue': currentValue,
         'pastValue': pastValue,
         'diffValue': diffValue,
         'diffPercentage': diffPercentage
       };
    }

    /// Retourne la liste des (dateKey, totalValue) tries par date,
    /// pour alimenter le graphique d'evolution (US-14.7).
    Future<List<({String dateKey, double value})>> getValueHistory() async {
      if (_db != null) {
        final entries = await _db.getCollectionValueHistory();
        return entries
            .map((e) => (dateKey: e.dateKey, value: e.totalValue))
            .toList();
      }
      // Fallback SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonHistory = prefs.getString('collection_value_history');
      if (jsonHistory == null) return [];
      final Map<String, dynamic> history = json.decode(jsonHistory);
      final sortedKeys = history.keys.toList()..sort();
      return sortedKeys
          .map((k) => (dateKey: k, value: (history[k] as num).toDouble()))
          .toList();
    }

    Future<void> clearCollection() async {
      if (_db != null) {
        await _db.clearCollection();
        return;
      }
      await _saveCollection([]);
    }

    Future<List<String>> getAllUniqueTags() async {
      if (_db != null) {
        return _db.getAllUniqueCollectionTags();
      }
      final col = await loadCollection();
      final Set<String> tags = {};
      for(var card in col) {
        tags.addAll(card.tags);
      }
      return tags.toList()..sort();
    }
}
