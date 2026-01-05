// Fichier : lib/models/player_model.dart

class Player {
  final int id;
  String name;
  int life;
  int colorValue; 
  String? backgroundImagePath; // <--- NOUVEAU : Chemin vers l'image de fond (Skin)
  
  Map<int, int> commanderDamageReceived;
  int poison;
  int energy;
  int commanderCastCount; 
  bool isMonarch;
  int quarterTurns; 

  Player({
    required this.id,
    this.name = "Joueur",
    required this.life,
    this.colorValue = 0xFF000000,
    this.backgroundImagePath, // <--- NOUVEAU 
    required this.commanderDamageReceived,
    this.poison = 0,
    this.energy = 0,
    this.commanderCastCount = 0,
    this.isMonarch = false,
    this.quarterTurns = 0, 
  });
  
  int get totalCommanderDamage => commanderDamageReceived.values.fold(0, (sum, element) => sum + element);
}