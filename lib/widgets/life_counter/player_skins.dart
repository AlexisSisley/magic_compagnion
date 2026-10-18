// lib/widgets/life_counter/player_skins.dart
// Source UNIQUE des couleurs et fonds de zone joueur.
//
// Avant ce fichier, deux listes divergentes coexistaient :
// `game_setup_modal._defaultColors` (6 entrées) et
// `player_skin_picker.playerSkinColorOptions` (12 entrées), toutes deux en
// `Colors.*.shade900` Material. D'où des zones qui ne se ressemblaient pas
// d'un écran à l'autre, et une saturation étrangère à la DA Grimoire.
//
// Les teintes ci-dessous sont des couleurs de TERRAIN désaturées, validées
// sur maquette. Elles appartiennent à la famille « domaine » et ne
// partagent AUCUNE valeur avec la famille « sémantique » (feedback/*) :
// un badge « possédée » ne doit pas se confondre avec une zone verte.

import 'package:flutter/material.dart';

/// Habillage d'une zone joueur : une couleur, et le fond illustré qui
/// l'accompagne quand l'asset est présent.
@immutable
class PlayerSkin {
  const PlayerSkin({
    required this.label,
    required this.color,
    this.assetPath,
  });

  final String label;
  final Color color;

  /// Fond illustré embarqué, ou `null` pour un aplat.
  ///
  /// JAMAIS un art de carte Magic : ces visuels appartiennent à Wizards of
  /// the Coast et ne peuvent pas être redistribués dans le binaire. Les arts
  /// Scryfall restent accessibles en réseau via `player_skin_picker`.
  final String? assetPath;

  @override
  bool operator ==(Object other) =>
      other is PlayerSkin &&
      other.label == label &&
      other.color == color &&
      other.assetPath == assetPath;

  @override
  int get hashCode => Object.hash(label, color, assetPath);
}

const List<PlayerSkin> kPlayerSkins = [
  PlayerSkin(label: 'Plaine', color: Color(0xFFC9B88A)),
  PlayerSkin(label: 'Île', color: Color(0xFF3E6B8A)),
  PlayerSkin(label: 'Marécage', color: Color(0xFF4A4350)),
  PlayerSkin(label: 'Montagne', color: Color(0xFF8A4038)),
  PlayerSkin(label: 'Forêt', color: Color(0xFF4A6B4F)),
  PlayerSkin(label: 'Incolore', color: Color(0xFF5A5A63)),
  PlayerSkin(label: 'Cendre', color: Color(0xFF3A3646)),
  PlayerSkin(label: 'Parchemin', color: Color(0xFF6E5A3C)),
];

/// Habillage par défaut du siège [seatIndex], 0 pour le premier joueur.
PlayerSkin defaultSkinForSeat(int seatIndex) =>
    kPlayerSkins[seatIndex % kPlayerSkins.length];
