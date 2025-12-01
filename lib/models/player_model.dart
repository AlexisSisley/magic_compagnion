// Fichier : lib/models/player_model.dart

class Player {
  final int id;
  int life;
  // MODIFICATION : Ajout de la couleur (valeur int pour la sauvegarde)
  int colorValue; 
  Map<int, int> commanderDamageReceived;

  Player({
    required this.id,
    required this.life,
    // MODIFICATION : Couleur par défaut (sera écrasée à l'initialisation)
    this.colorValue = 0xFF000000, 
    required this.commanderDamageReceived,
  });
  
  int get totalCommanderDamage => commanderDamageReceived.values.fold(0, (sum, element) => sum + element);
}