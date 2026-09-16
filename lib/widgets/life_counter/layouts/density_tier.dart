// lib/widgets/life_counter/layouts/density_tier.dart
// Contrat de densite du lot 6 (spec lot 6 §3).
//
// Le cran se decide sur la taille MESUREE, jamais sur le nombre de joueurs :
// six zones sur une tablette sont plus confortables que deux sur un petit
// telephone.

import 'dart:ui';

enum DensityTier { comfort, compact, minimal }

/// Hauteur reservee a l'en-tete d'une zone joueur (palette, rotation, nom),
/// au-dessus du cadran de vie (spec §2.1).
///
/// Elle vit ICI et non dans `player_zone.dart` -- qui la lit -- pour que
/// `kZoneHeightFloor` ci-dessous puisse en deriver sans cycle d'import :
/// `player_zone.dart` importe deja ce fichier, l'inverse serait circulaire.
const double kZoneHeaderHeight = 40.0;

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

/// Hauteur utile sous laquelle la Column de `player_zone.dart` deborde.
///
/// Revue finale du lot 6 : c'etait un litteral `70.0` recopie a la main, une
/// SOMME figee (en-tete 40 + poignee 30) qu'aucun lien ne rattachait a ses
/// deux sources. Elle en derive desormais -- toucher a l'en-tete ou au
/// plancher de la poignee deplace le plancher avec elles.
final double kZoneHeightFloor =
    kZoneHeaderHeight + handleHeightFor(DensityTier.minimal);

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
