import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';

void main() {
  group('tierFor', () {
    test('grande zone : confort', () {
      expect(tierFor(const Size(400, 400)), DensityTier.comfort);
    });

    test('zone moyenne : compact', () {
      expect(tierFor(const Size(360, 200)), DensityTier.compact);
    });

    test('petite zone : minimal', () {
      expect(tierFor(const Size(180, 90)), DensityTier.minimal);
    });

    test('un siege lateral est classe sur sa taille dans le repere du joueur',
        () {
      // 300 de large sur 140 de haut POUR LE JOUEUR, meme si a l'ecran la
      // boite est haute et etroite. L'appelant transpose avant d'appeler.
      expect(tierFor(const Size(300, 140)), DensityTier.compact);
    });

    test('la hauteur commande le cran plus que la largeur', () {
      expect(tierFor(const Size(800, 80)), DensityTier.minimal);
    });
  });

  // Revue finale du lot 6, constat mineur 3 : `kZoneHeightFloor` etait un
  // litteral `70.0`, somme recopiee a la main de deux constantes que rien ne
  // reliait a lui. Elle en derive desormais -- ces deux tests verrouillent a
  // la fois la derivation et la valeur effective, pour qu'un futur
  // changement d'en-tete ou de poignee se voie ici.
  group('kZoneHeightFloor', () {
    test('derive de la hauteur d en-tete et du plancher de poignee', () {
      expect(kZoneHeightFloor,
          kZoneHeaderHeight + handleHeightFor(DensityTier.minimal));
    });

    test('vaut toujours les 70 px du plancher historique (lot 2)', () {
      expect(kZoneHeightFloor, 70.0,
          reason: 'si la derivation deplace ce plancher, on veut le voir : '
              'c est la largeur minimale absolue des colonnes laterales '
              'd AdaptiveGrid');
    });
  });

  group('handleHeightFor', () {
    test('compact et minimal gardent la hauteur livree au lot 2', () {
      expect(handleHeightFor(DensityTier.compact), 30.0);
      expect(handleHeightFor(DensityTier.minimal), 30.0,
          reason: 'jamais zero : la poignee est le seul acces au tiroir');
    });

    test('confort elargit vers la cible Material de 48 dp', () {
      expect(handleHeightFor(DensityTier.comfort), 48.0);
    });

    test('aucun cran ne descend sous la hauteur livree au lot 2', () {
      for (final tier in DensityTier.values) {
        expect(handleHeightFor(tier), greaterThanOrEqualTo(30.0),
            reason: '$tier');
      }
    });
  });
}
