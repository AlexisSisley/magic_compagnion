import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

const phonePortrait = Size(390, 844);
const phoneLandscape = Size(844, 390);
const tabletPortrait = Size(820, 1180);
const tabletLandscape = Size(1180, 820);

void main() {
  group('condition de forme (spec §3.1)', () {
    test('téléphone en portrait : PAS de colonne latérale, même à 4 joueurs', () {
      expect(tableLayoutFor(phonePortrait, 4).useSideColumns, isFalse);
    });

    test('téléphone en paysage : colonnes latérales', () {
      expect(tableLayoutFor(phoneLandscape, 4).useSideColumns, isTrue);
    });

    test('tablette en portrait : colonnes latérales malgré le portrait', () {
      expect(tableLayoutFor(tabletPortrait, 4).useSideColumns, isTrue);
    });

    test('tablette en paysage : colonnes latérales', () {
      expect(tableLayoutFor(tabletLandscape, 4).useSideColumns, isTrue);
    });

    test('5 et 6 joueurs ont aussi des colonnes latérales', () {
      expect(tableLayoutFor(tabletLandscape, 5).useSideColumns, isTrue);
      expect(tableLayoutFor(tabletLandscape, 6).useSideColumns, isTrue);
    });
  });

  group('on renonce, on ne rétrécit pas (spec §3.3)', () {
    test('le repli renvoie des sièges face à face, pas des colonnes étroites', () {
      final layout = tableLayoutFor(phonePortrait, 4);
      final sides = layout.seats.map((s) => s.side).toSet();
      expect(sides.contains(TableSide.left), isFalse);
      expect(sides.contains(TableSide.right), isFalse);
      expect(layout.sideWidth, 0.0);
    });

    test('une colonne rendue n\'est JAMAIS sous le plancher', () {
      for (final size in [phoneLandscape, const Size(400, 380), tabletPortrait, tabletLandscape]) {
        for (int n = 2; n <= 8; n++) {
          final layout = tableLayoutFor(size, n);
          if (layout.useSideColumns) {
            expect(layout.sideWidth,
                greaterThanOrEqualTo(kSideColumnNeed),
                reason: '$size à $n joueurs');
          }
        }
      }
    });

    test('un écran trop étroit pour le budget renonce aux côtés', () {
      // 340 de large en paysage (340 > 300) : petit côté 300 < 600, donc hub
      // (centreNeed = 160). Budget : 340 - 192 = 148 < 160, donc repli par
      // le budget et par lui seul.
      expect(tableLayoutFor(const Size(340, 300), 4).useSideColumns, isFalse);
    });
  });

  group('forme de la barre (spec §4.2)', () {
    test('téléphone : hub', () {
      expect(tableLayoutFor(phonePortrait, 4).barKind, ActionBarKind.hub);
      expect(tableLayoutFor(phoneLandscape, 4).barKind, ActionBarKind.hub);
    });

    test('tablette : bande', () {
      expect(tableLayoutFor(tabletPortrait, 4).barKind, ActionBarKind.band);
      expect(tableLayoutFor(tabletLandscape, 4).barKind, ActionBarKind.band);
    });

    test('le centre restant loge toujours la bande quand elle est choisie', () {
      for (final size in [tabletPortrait, tabletLandscape]) {
        final layout = tableLayoutFor(size, 4);
        final centre = size.width - 2 * layout.sideWidth;
        expect(centre, greaterThanOrEqualTo(kBandNeed), reason: '$size');
      }
    });

    test('au seuil exact de grand écran, la bande est choisie et tient', () {
      // Size(600, 600) : petit côté = 600, donc shortEdge >= kLargeScreenShortEdge
      // → barKind = band. Budget : 600 - 192 = 408 > kBandNeed (324), donc OK.
      final layout = tableLayoutFor(const Size(600, 600), 4);
      expect(layout.barKind, ActionBarKind.band);
      final centre = 600.0 - 2 * layout.sideWidth;
      expect(centre, greaterThanOrEqualTo(kBandNeed));
    });
  });

  group('nombres de joueurs sans siège latéral', () {
    for (final n in const [2, 3, 7, 8]) {
      test('$n joueurs : aucune colonne latérale sur aucun écran', () {
        for (final size in [phonePortrait, phoneLandscape, tabletLandscape]) {
          expect(tableLayoutFor(size, n).useSideColumns, isFalse,
              reason: '$size');
        }
      });
    }
  });
}
