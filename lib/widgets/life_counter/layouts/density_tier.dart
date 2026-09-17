// lib/widgets/life_counter/layouts/density_tier.dart
import 'dart:math' as math;
import 'dart:ui';

/// Hauteur de l'en-tête d'une zone joueur (`player_zone.dart`).
///
/// Revue finale (ruling 22) : 40.0 était FAUX, exactement comme `kActionWidth`
/// valait 36 alors qu'un `IconButton` Material mesure 48
/// (`kMinInteractiveDimension`) — ruling 16, même défaut, même remède.
/// `PlayerHeader` contient un `IconButton` nu ; mesuré sur une `PlayerZone`
/// de 340×340 : en-tête rendu de 40 px, bouton palette de 48 px, débordement
/// de 8 px rogné par le `clipBehavior` de la zone. La cible tactile effective
/// tombait donc à 48×40, sous le minimum, et les 8 px manquants étaient
/// absorbés par le `LifeDial` en dessous : le tap donnait +1 PV au lieu
/// d'ouvrir le sélecteur de couleur.
///
/// Cascade assumée : `kZoneShortEdgeFloor` 70 → 78, `kSideColumnNeed`
/// 96 → 104. Vérifié : tablette en portrait, 820 − 208 = 612 ≥ 472, les
/// colonnes latérales sont conservées ; le seuil de 600 px était déjà sans
/// colonnes.
///
/// Gardée par un test qui MESURE la hauteur réellement rendue de
/// `PlayerHeader` (`test/widgets/life_counter/player_zone_test.dart`), pour
/// que ce mensonge ne puisse pas revenir.
const double kZoneHeaderHeight = 48.0;

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
