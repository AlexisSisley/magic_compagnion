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

  Future<List<DeckCard>> upsertCardInCollection({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,     
    int? absoluteQuantity,  
  }) async {
    final collection = await loadCollection();
    _upsertInMemory(collection, scryfallId, cardName, quantityToAdd, absoluteQuantity);
    await _saveCollection(collection);
    return collection;
  }

  // Helper privé pour ne pas sauvegarder à chaque boucle lors d'un batch
  void _upsertInMemory(List<DeckCard> collection, String scryfallId, String cardName, int? qtyAdd, int? absQty) {
    try {
      final existingCard = collection.firstWhere((c) => c.scryfallId == scryfallId);
      int newQuantity = existingCard.quantity;
      if (qtyAdd != null) newQuantity += qtyAdd;
      else if (absQty != null) newQuantity = absQty;

      if (newQuantity <= 0) collection.remove(existingCard); 
      else existingCard.quantity = newQuantity; 
    } catch (e) {
      int newQuantity = 0;
      if (qtyAdd != null) newQuantity = qtyAdd;
      else if (absQty != null) newQuantity = absQty;
      if (newQuantity > 0) {
        collection.add(DeckCard(scryfallId: scryfallId, name: cardName, quantity: newQuantity));
      }
    }
  }
  
   Future<void> addCard(ScryfallCard card, int quantity) async {
      await upsertCardInCollection(scryfallId: card.id, cardName: card.name, quantityToAdd: quantity);
   }

   // --- NOUVEAU : IMPORTATION DE MASSE (BATCH) ---
   
   /// Prend une liste de noms de cartes (ex: ["Sol Ring", "Mountain", ...])
   /// Et les ajoute à la collection en gérant la limite de 75 cartes par appel.
   Future<Map<String, int>> importBatchCards(List<String> rawNames) async {
     final collection = await loadCollection();
     int addedCount = 0;
     int errorCount = 0;

     // 1. Nettoyage et dédoublonnage des noms pour l'appel API
     // On garde la quantité demandée pour chaque nom si possible, 
     // mais ici on suppose une liste de noms simples. Si la liste est "2 Sol Ring", il faut parser avant.
     
     // Parsing simple : "4 Sol Ring" -> {name: "Sol Ring", qty: 4}
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

     // 2. Chunking (Paquets de 75)
     const int chunkSize = 75;
     for (var i = 0; i < uniqueNames.length; i += chunkSize) {
       final end = (i + chunkSize < uniqueNames.length) ? i + chunkSize : uniqueNames.length;
       final batchNames = uniqueNames.sublist(i, end);

       // Construction de la requête "identifiers"
       // Scryfall accepte { "name": "Sol Ring" }
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
             // On retrouve la quantité demandée initialement
             // Attention: Scryfall peut renvoyer un nom légèrement différent (ex: "Sol Ring" -> "Sol Ring")
             // On essaie de mapper le nom retourné avec notre map d'entrée
             
             // Astuce : On cherche dans notre map la clé qui est contenue dans le nom Scryfall ou inversement
             String originalKey = cardsToFetch.keys.firstWhere(
               (k) => scCard.name.toLowerCase().contains(k.toLowerCase()) || k.toLowerCase().contains(scCard.name.toLowerCase()),
               orElse: () => scCard.name
             );
             
             int qtyToAdd = cardsToFetch[originalKey] ?? 1;
             
             _upsertInMemory(collection, scCard.id, scCard.name, qtyToAdd, null);
             addedCount += qtyToAdd;
           }
         } else {
           errorCount += batchNames.length;
         }
       } catch (e) {
         log("Erreur batch import: $e");
         errorCount += batchNames.length;
       }
       
       // Pause pour respecter l'API
       await Future.delayed(const Duration(milliseconds: 100));
     }

     await _saveCollection(collection);
     
     return {'added': addedCount, 'errors': errorCount};
   }

   // ... (Garder les méthodes recordDailyValue et getEvolutionSince inchangées) ...
   // Je les omets ici pour la brièveté, mais assure-toi qu'elles restent dans ton fichier.
    Future<void> recordDailyValue(double totalValue) async {
      // (Ton code existant)
    }
    Future<Map<String, double>?> getEvolutionSince(int daysAgo) async {
       // (Ton code existant)
       return null; 
    }
}