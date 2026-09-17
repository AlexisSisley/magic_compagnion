// test/widgets/life_counter/layouts/density_tier_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';

void main() {
  test('le plancher est DÉRIVÉ de l\'en-tête et de la poignée, pas recopié', () {
    expect(kZoneShortEdgeFloor, kZoneHeaderHeight + kZoneHandleHeight);
  });

  // Revue finale (ruling 22) : 78 = 48 (en-tête, porté de 40 à la cible
  // tactile minimale de Material) + 30 (poignée).
  test('le plancher vaut 78 px avec les valeurs actuelles', () {
    expect(kZoneShortEdgeFloor, 78.0);
  });

  test('une grande zone est au cran confort', () {
    expect(tierFor(const Size(300, 220)), DensityTier.comfort);
  });

  test('une zone moyenne est au cran compact', () {
    expect(tierFor(const Size(300, 120)), DensityTier.compact);
  });

  test('une zone au ras du plancher est au cran minimal', () {
    expect(tierFor(const Size(300, 72)), DensityTier.minimal);
  });

  test('la poignée ne descend jamais sous 30 px, quel que soit le cran', () {
    for (final tier in DensityTier.values) {
      expect(handleHeightFor(tier), greaterThanOrEqualTo(kZoneHandleHeight));
    }
  });

  test('le confort offre une poignée plus généreuse', () {
    expect(handleHeightFor(DensityTier.comfort),
        greaterThan(handleHeightFor(DensityTier.minimal)));
  });
}
