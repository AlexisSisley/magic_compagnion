// Fichier : lib/services/collection_service.dart

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_model.dart'; 

class CollectionService {
  static const _collectionKey = 'user_collection'; 

  Future<List<DeckCard>> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final String? collectionJson = prefs.getString(_collectionKey);
    if (collectionJson == null) return [];
    final List<dynamic> decodedList = json.decode(collectionJson) as List;
    return decodedList.map((jsonItem) => DeckCard.fromJson(jsonItem)).toList();
  }

  Future<void> _saveCollection(List<DeckCard> collection) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = collection.map((card) => card.toJson()).toList();
    await prefs.setString(_collectionKey, json.encode(jsonList));
  }

  /// Ajoute ou modifie une carte dans la collection.
  /// Supporte maintenant la distinction Foil / Non-Foil.
  Future<List<DeckCard>> upsertCardInCollection({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,     
    int? absoluteQuantity,
    bool isFoil = false, // <--- NOUVEAU PARAMÈTRE
  }) async {
    final collection = await loadCollection();
    _upsertInMemory(collection, scryfallId, cardName, quantityToAdd, absoluteQuantity, isFoil: isFoil);
    await _saveCollection(collection);
    return collection;
  }

  // Helper privé
  void _upsertInMemory(List<DeckCard> collection, String scryfallId, String cardName, int? qtyAdd, int? absQty, {bool isFoil = false}) {
    try {
      // On cherche une carte avec le même ID ET la même finition (Foil/Normal)
      final existingCard = collection.firstWhere(
        (c) => c.scryfallId == scryfallId && c.isFoil == isFoil
      );
      
      int newQuantity = existingCard.quantity;
      if (qtyAdd != null) newQuantity += qtyAdd;
      else if (absQty != null) newQuantity = absQty;

      if (newQuantity <= 0) collection.remove(existingCard); 
      else existingCard.quantity = newQuantity; 
      
    } catch (e) {
      // Pas trouvée, on crée une nouvelle entrée
      int newQuantity = 0;
      if (qtyAdd != null) newQuantity = qtyAdd;
      else if (absQty != null) newQuantity = absQty;
      
      if (newQuantity > 0) {
        collection.add(DeckCard(
          scryfallId: scryfallId, 
          name: cardName, 
          quantity: newQuantity,
          isFoil: isFoil // <--- Stockage de l'info Foil
        ));
      }
    }
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
         final response = await http.post(
           Uri.parse('https://api.scryfall.com/cards/collection'),
           headers: {'Content-Type': 'application/json'},
           body: json.encode({'identifiers': identifiers}),
         );

         if (response.statusCode == 200) {
           final data = json.decode(utf8.decode(response.bodyBytes));
           final List<dynamic> foundCards = data['data'] ?? [];
           
           for (var cardJson in foundCards) {
             final scCard = ScryfallCard.fromJson(cardJson);
             String originalKey = cardsToFetch.keys.firstWhere(
               (k) => scCard.name.toLowerCase().contains(k.toLowerCase()) || k.toLowerCase().contains(scCard.name.toLowerCase()),
               orElse: () => scCard.name
             );
             
             int qtyToAdd = cardsToFetch[originalKey] ?? 1;
             
             // Par défaut, l'import de masse ajoute en Non-Foil
             _upsertInMemory(collection, scCard.id, scCard.name, qtyToAdd, null, isFoil: false);
             addedCount += qtyToAdd;
           }
         } else {
           errorCount += batchNames.length;
         }
       } catch (e) {
         log("Erreur batch import: $e");
         errorCount += batchNames.length;
       }
       
       await Future.delayed(const Duration(milliseconds: 100));
     }

     await _saveCollection(collection);
     return {'added': addedCount, 'errors': errorCount};
   }

    // Gestion de l'historique financier (inchangé)
    Future<void> recordDailyValue(double totalValue) async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = "${now.year}-${now.month}-${now.day}";
      
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
       final prefs = await SharedPreferences.getInstance();
       String? jsonHistory = prefs.getString('collection_value_history');
       if (jsonHistory == null) return null;
       
       Map<String, dynamic> history = json.decode(jsonHistory);
       if (history.isEmpty) return null;

       final sortedKeys = history.keys.toList()..sort();
       final String todayKey = sortedKeys.last;
       final double currentValue = (history[todayKey] as num).toDouble();
       
       // Trouver la date la plus proche il y a X jours
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

    Future<void> clearCollection() async {
      await _saveCollection([]);
    }
}