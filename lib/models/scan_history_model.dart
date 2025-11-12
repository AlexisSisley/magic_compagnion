// Fichier : lib/models/scan_history_model.dart
// NOUVEAU FICHIER

class ScanHistoryItem {
  final String scryfallId; // L'ID Scryfall pour la fiabilité
  final String cardName;   // Le nom, pour l'affichage
  final String? imagePath; // Le chemin vers la photo prise (optionnel)
  final DateTime timestamp;  // Quand le scan a eu lieu

  ScanHistoryItem({
    required this.scryfallId,
    required this.cardName,
    this.imagePath,
    required this.timestamp,
  });

  // Méthode pour convertir notre objet en JSON (pour la sauvegarde)
  Map<String, dynamic> toJson() => {
        'scryfallId': scryfallId,
        'cardName': cardName,
        'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(), // Convertit la date en texte
      };

  // Méthode pour créer notre objet depuis un JSON (pour le chargement)
  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) => ScanHistoryItem(
        scryfallId: json['scryfallId'],
        cardName: json['cardName'],
        imagePath: json['imagePath'],
        timestamp: DateTime.parse(json['timestamp']), // Reconvertit le texte en date
      );
}