// Fichier : lib/models/player_model.dart

import 'package:magic_companion/models/profile_model.dart';

class Player {
  final int id;
  String name;
  int life;
  int colorValue;
  String? backgroundImagePath;
  String? secondaryBackgroundImagePath;

  Map<int, int> commanderDamageReceived;
  int poison;
  int energy;
  int commanderCastCount;
  bool isMonarch;
  int quarterTurns;

  /// Gallery of saved commanders — allows quick artwork switching in-game.
  List<CommanderEntry> commanderGallery;

  Player({
    required this.id,
    this.name = 'Joueur',
    required this.life,
    this.colorValue = 0xFF000000,
    this.backgroundImagePath,
    this.secondaryBackgroundImagePath,
    required this.commanderDamageReceived,
    this.poison = 0,
    this.energy = 0,
    this.commanderCastCount = 0,
    this.isMonarch = false,
    this.quarterTurns = 0,
    this.commanderGallery = const [],
  });

  int get totalCommanderDamage => commanderDamageReceived.values.fold(0, (sum, element) => sum + element);
}