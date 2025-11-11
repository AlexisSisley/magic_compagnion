// Fichier : lib/models/player_model.dart

class Player {
  final int id;
  int life;
  Map<int, int> commanderDamageReceived;

  Player({
    required this.id,
    required this.life,
    required this.commanderDamageReceived,
  });

  int get totalCommanderDamage {
    return commanderDamageReceived.values.fold(0, (sum, damage) => sum + damage);
  }
}