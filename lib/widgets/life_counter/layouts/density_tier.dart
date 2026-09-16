// lib/widgets/life_counter/layouts/density_tier.dart
import 'dart:math' as math;
import 'dart:ui';

/// Hauteur de l'en-tête d'une zone joueur (`player_zone.dart`).
const double kZoneHeaderHeight = 40.0;

/// Hauteur minimale de la poignée du tiroir (`conditional_handle.dart`).
const double kZoneHandleHeight = 30.0;

/// Plancher du PETIT CÔTÉ d'une zone, dans son propre repère.
///
/// Nom délibéré (spec §6) : pour un siège latéral, cette valeur est la largeur
/// minimale de la colonne — la largeur avant rotation devient la hauteur après.
/// L'ancien nom `kZoneHeightFloor` mentait sur cet usage.
///
/// DÉRIVÉ, jamais recopié : si l'en-tête ou la poignée change, le plancher suit.
const double kZoneShortEdgeFloor = kZoneHeaderHeight + kZoneHandleHeight;

/// Ce qu'une zone joueur affiche, selon la place dont elle dispose.
enum DensityTier {
  /// PV, nom, compteurs secondaires.
  comfort,

  /// PV et nom.
  compact,

  /// PV seuls.
  minimal,
}

/// Cran de densité pour une zone de [sizeInPlayerFrame], mesurée dans SON
/// repère (après rotation).
DensityTier tierFor(Size sizeInPlayerFrame) {
  final shortEdge = math.min(sizeInPlayerFrame.width, sizeInPlayerFrame.height);
  if (shortEdge >= 180.0) return DensityTier.comfort;
  if (shortEdge >= 110.0) return DensityTier.compact;
  return DensityTier.minimal;
}

/// Hauteur de la poignée du tiroir pour un cran donné.
///
/// Elle ne descend jamais sous [kZoneHandleHeight] : c'est le seul point
/// d'entrée du tiroir, et une poignée qu'on ne peut pas attraper ferme la
/// fonctionnalité entière.
double handleHeightFor(DensityTier tier) => switch (tier) {
      DensityTier.comfort => 48.0,
      DensityTier.compact => kZoneHandleHeight,
      DensityTier.minimal => kZoneHandleHeight,
    };
