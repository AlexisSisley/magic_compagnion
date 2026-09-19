// Fichier : lib/services/collection_service.dart

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import '../models/card_print.dart';
import '../models/deck_model.dart';
import 'card_resolver.dart';
import 'deck_format_service.dart';
import '../utils/card_list_upsert_mixin.dart';

class CollectionService with CardListUpsertMixin {
  static const _collectionKey = 'user_collection';
  final AppDatabase? _db;
  final CardResolver? _resolver;

  CollectionService({AppDatabase? database, CardResolver? resolver})
      : _db = database,
        _resolver = resolver;

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

   /// Resout les entrees d'une decklist par edition (set + numero de
   /// collection quand ils sont connus, sinon par nom), puis enfile les
   /// traductions manquantes en tache de fond.
   ///
   /// Rend la main des que les editions sont connues : les traductions ne
   /// sont jamais attendues ici (voir TranslationWorker), et aucune n'est
   /// enfilee pour un tirage deja dans la langue preferee.
   ///
   /// Un import partiel n'est jamais silencieux : l'[EditionResolution]
   /// complete est rendue a l'appelant (resolved / notFound / failed /
   /// errors), qui decide quoi en faire.
   Future<EditionResolution> resolveImportedEntries(
     List<DecklistEntry> entries, {
     required String preferredLang,
   }) async {
     final resolver = _resolver;
     final db = _db;
     if (resolver == null || db == null) {
       throw StateError(
         'resolveImportedEntries requiert un CardResolver et un AppDatabase '
         '(injecter via collectionServiceProvider).',
       );
     }

     final requests = entries
         .map((e) => PrintRequest(
               name: e.name,
               setCode: e.setCode,
               collectorNumber: e.collectorNumber,
             ))
         .toList();

     final resolution = await resolver.resolveEditions(requests);

     for (final print in resolution.resolved) {
       if (print.lang == preferredLang) continue;
       await db.enqueueTranslation(
         scryfallId: print.scryfallId,
         setCode: print.setCode,
         collectorNumber: print.collectorNumber,
         lang: preferredLang,
       );
     }

     return resolution;
   }

    // Gestion de l'historique financier
    Future<void> recordDailyValue(double totalValue) async {
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

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
