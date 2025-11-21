// Fichier : lib/services/collection_service.dart
// VERSION MISE À JOUR (Avec historique financier)

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_model.dart'; 

class CollectionService {
  static const _collectionKey = 'user_collection'; // Clé de la collection
  static const _valueHistoryKey = 'collection_value_history'; // Clé de l'historique financier

  /// Récupère TOUTE la collection sauvegardée
  Future<List<DeckCard>> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final String? collectionJson = prefs.getString(_collectionKey);

    if (collectionJson == null) {
      return []; // Retourne une liste vide si rien n'est sauvegardé
    }

    final List<dynamic> decodedList = json.decode(collectionJson) as List;
    return decodedList.map((jsonItem) => DeckCard.fromJson(jsonItem)).toList();
  }

  /// Sauvegarde la liste COMPLÈTE de la collection
  Future<void> _saveCollection(List<DeckCard> collection) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        collection.map((card) => card.toJson()).toList();
    final String collectionJson = json.encode(jsonList);
    await prefs.setString(_collectionKey, collectionJson);
  }

  /// Gère l'ajout, la mise à jour et la suppression de quantité
  Future<List<DeckCard>> upsertCardInCollection({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,     // Pour +1, -1
    int? absoluteQuantity,  // Pour définir une quantité (ex: 4)
  }) async {
    final collection = await loadCollection();

    try {
      final existingCard = collection.firstWhere((c) => c.scryfallId == scryfallId);
      
      int newQuantity = existingCard.quantity;
      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity <= 0) {
        collection.remove(existingCard); 
      } else {
        existingCard.quantity = newQuantity; 
      }

    } catch (e) {
      int newQuantity = 0;
      if (quantityToAdd != null) {
        newQuantity = quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity > 0) {
        collection.add(DeckCard(
          scryfallId: scryfallId,
          name: cardName,
          quantity: newQuantity,
        ));
      }
    }

    await _saveCollection(collection);
    return collection;
  }
  
  /// Fonction pratique pour ajouter depuis un objet ScryfallCard
   Future<void> addCard(ScryfallCard card, int quantity) async {
      await upsertCardInCollection(
        scryfallId: card.id,
        cardName: card.name,
        quantityToAdd: quantity
      );
   }

   // --- NOUVEAU : GESTION DE L'ÉVOLUTION FINANCIÈRE ---

   /// Enregistre la valeur totale actuelle de la collection avec la date d'aujourd'hui
   Future<void> recordDailyValue(double totalValue) async {
     if (totalValue <= 0) return;

     final prefs = await SharedPreferences.getInstance();
     final String? historyJson = prefs.getString(_valueHistoryKey);
     List<Map<String, dynamic>> history = [];

     if (historyJson != null) {
       history = List<Map<String, dynamic>>.from(json.decode(historyJson));
     }

     final String todayStr = DateTime.now().toIso8601String().split('T')[0]; // Format YYYY-MM-DD

     // Supprime l'entrée d'aujourd'hui si elle existe déjà (pour la mettre à jour)
     history.removeWhere((entry) => entry['date'] == todayStr);

     // Ajoute la nouvelle valeur
     history.add({
       'date': todayStr,
       'value': totalValue,
     });

     // Optionnel : Limiter l'historique (ex: garder les 30 derniers jours seulement)
     if (history.length > 60) {
       // Trie par date pour être sûr de supprimer les vieux
       history.sort((a, b) => a['date'].compareTo(b['date']));
       history = history.sublist(history.length - 60);
     }

     await prefs.setString(_valueHistoryKey, json.encode(history));
   }

   /// Récupère la différence de valeur par rapport à il y a X jours (ex: 7 jours)
   /// Retourne : { 'diffValue': double, 'diffPercentage': double } ou null si pas assez de données
   Future<Map<String, double>?> getEvolutionSince(int daysAgo) async {
     final prefs = await SharedPreferences.getInstance();
     final String? historyJson = prefs.getString(_valueHistoryKey);
     
     if (historyJson == null) return null;

     final List<dynamic> rawList = json.decode(historyJson);
     final List<Map<String, dynamic>> history = List<Map<String, dynamic>>.from(rawList);

     if (history.isEmpty) return null;

     // Trie par date croissante
     history.sort((a, b) => a['date'].compareTo(b['date']));

     // Valeur actuelle (la dernière enregistrée, qui vient d'être mise à jour théoriquement)
     final double currentValue = history.last['value'];

     // Date cible
     final DateTime targetDate = DateTime.now().subtract(Duration(days: daysAgo));
     
     // Trouver l'entrée la plus proche de la date cible (mais pas plus récente qu'aujourd'hui)
     Map<String, dynamic>? pastEntry;
     
     // On cherche la première entrée qui est >= targetDate
     // Ou alors on prend l'entrée la plus proche dans le passé
     for (var entry in history) {
       DateTime entryDate = DateTime.parse(entry['date']);
       // Si l'entrée est avant ou le même jour que la cible, on la garde comme candidate
       if (entryDate.isBefore(targetDate) || isSameDay(entryDate, targetDate)) {
         pastEntry = entry;
       } else {
         // Dès qu'on dépasse la date cible, on arrête, car on veut comparer au passé
         break;
       }
     }

     // Si on n'a pas trouvé d'entrée passée (ex: première utilisation), on ne peut pas comparer
     if (pastEntry == null) return null;

     final double pastValue = pastEntry['value'];
     
     if (pastValue == 0) return null; // Évite division par zéro

     final double diff = currentValue - pastValue;
     final double percent = (diff / pastValue) * 100;

     return {
       'diffValue': diff,
       'diffPercentage': percent,
     };
   }

   bool isSameDay(DateTime d1, DateTime d2) {
     return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
   }
}