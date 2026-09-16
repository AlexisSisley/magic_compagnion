// lib/widgets/life_counter/layouts/density_tier.dart
// Contrat de densite du lot 6 (spec lot 6 §3).
//
// Le cran se decide sur la taille MESUREE, jamais sur le nombre de joueurs :
// six zones sur une tablette sont plus confortables que deux sur un petit
// telephone.

import 'dart:ui';

enum DensityTier { comfort, compact, minimal }

/// Hauteur utile sous laquelle la Column de `player_zone.dart` deborde :
/// `_headerHeight` (40) + la poignee (30).
const double kZoneHeightFloor = 70.0;

/// Cran de densite pour une zone, d'apres sa taille DANS LE REPERE DU JOUEUR.
///
/// L'appelant transpose avant d'appeler : un siege lateral est haut et etroit
/// a l'ecran, large et bas pour son joueur.
DensityTier tierFor(Size sizeInPlayerFrame) {
  final h = sizeInPlayerFrame.height;
  final w = sizeInPlayerFrame.width;

  if (h < 120 || w < 200) return DensityTier.minimal;
  if (h < 260) return DensityTier.compact;
  return DensityTier.comfort;
}

/// Hauteur de la poignee pour un cran.
///
/// La densite ne retrecit JAMAIS la poignee : elle est le seul point d'entree
/// du tiroir (l'appui long appartient au mode ajustement, le tap sur le nom a
/// l'historique). 30 px est deja sous les 48 dp Material ; il n'y a rien a
/// reprendre en dessous. Le cran confort est le seul qui ait la place de
/// solder cette dette.
double handleHeightFor(DensityTier tier) => switch (tier) {
      DensityTier.comfort => 48.0,
      DensityTier.compact => 30.0,
      DensityTier.minimal => 30.0,
    };
