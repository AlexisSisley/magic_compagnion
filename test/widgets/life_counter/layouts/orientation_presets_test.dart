// test/widgets/life_counter/layouts/orientation_presets_test.dart
//
// Tâche 8b (spec §1.7) : les presets d'orientation sont dérivés de la
// position RENDUE de chaque zone. Trois familles de preuves :
// - le modèle de positions (`zoneCentresFor`) coïncide avec ce
//   qu'`AdaptiveGrid` rend réellement, de 2 à 8 joueurs, aux deux tailles ;
// - chaque preset donne à chaque zone le côté que sa position rendue
//   appelle (règles générales) et la table complète des angles attendus ;
// - disponibilité par effectif, et dédoublonnage.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';
import 'package:magic_companion/widgets/life_counter/layouts/orientation_presets.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

/// Téléphone portrait (replié) et Fold déplié : les deux tailles du tableau
/// du §1.4, utilisées comme taille de GRILLE, celle que la page mesure.
const _phone = Size(390, 844);
const _fold = Size(840, 700);

const _f = OrientationPreset.faceToFace;
const _s = OrientationPreset.sides;
const _t = OrientationPreset.triangle;
const _c = OrientationPreset.circle;
const _m = OrientationPreset.sameWay;

/// Table attendue : pour chaque taille et chaque effectif, les presets
/// proposés DANS L'ORDRE de la barre, et leurs angles en ordre d'affichage.
/// Recopiée dans le rapport de tâche.
final Map<Size, Map<int, List<(OrientationPreset, List<int>)>>> _expected = {
  _phone: {
    2: [(_f, [2, 0]), (_s, [1, 3]), (_m, [0, 0])],
    3: [(_f, [2, 0, 0]), (_t, [2, 1, 3]), (_m, [0, 0, 0])],
    4: [
      (_s, [1, 3, 1, 3]),
      (_f, [2, 2, 0, 0]),
      (_c, [2, 3, 1, 0]),
      (_m, [0, 0, 0, 0]),
    ],
    5: [(_f, [2, 2, 0, 0, 0]), (_c, [2, 3, 1, 0, 3]), (_m, [0, 0, 0, 0, 0])],
    6: [
      (_f, [2, 2, 2, 0, 0, 0]),
      (_c, [1, 2, 3, 1, 0, 3]),
      (_m, [0, 0, 0, 0, 0, 0]),
    ],
    7: [(_f, [2, 2, 2, 0, 0, 0, 0]), (_m, [0, 0, 0, 0, 0, 0, 0])],
    8: [(_f, [2, 2, 2, 2, 0, 0, 0, 0]), (_m, [0, 0, 0, 0, 0, 0, 0, 0])],
  },
  _fold: {
    2: [(_f, [2, 0]), (_s, [1, 3]), (_m, [0, 0])],
    3: [(_f, [2, 0, 0]), (_t, [2, 1, 3]), (_m, [0, 0, 0])],
    4: [
      (_s, [1, 3, 1, 3]),
      (_f, [2, 2, 0, 0]),
      (_c, [2, 3, 1, 0]),
      (_m, [0, 0, 0, 0]),
    ],
    // `around` : colonnes latérales pleine hauteur. Face-à-face les range
    // en bas (à cheval sur l'axe) ; Cercle retrouve exactement les sièges.
    5: [(_f, [2, 2, 0, 0, 0]), (_c, [2, 2, 3, 0, 1]), (_m, [0, 0, 0, 0, 0])],
    6: [
      (_f, [2, 2, 0, 0, 0, 0]),
      (_c, [2, 2, 3, 0, 0, 1]),
      (_m, [0, 0, 0, 0, 0, 0]),
    ],
    7: [(_f, [2, 2, 2, 0, 0, 0, 0]), (_m, [0, 0, 0, 0, 0, 0, 0])],
    8: [(_f, [2, 2, 2, 2, 0, 0, 0, 0]), (_m, [0, 0, 0, 0, 0, 0, 0, 0])],
  },
};

/// Rend `AdaptiveGrid` à [size] avec [n] zones vides, bande et hub de
/// hauteur nulle (voir la doc de `zoneCentresFor` : la couture est hors du
/// modèle), et renvoie le centre de chaque zone en ordre d'affichage,
/// rapporté à la table (-0.5..0.5).
Future<List<Offset>> _renderedCentres(
    WidgetTester tester, Size size, int n) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: AdaptiveGrid(
          playerZones: [for (int i = 0; i < n; i++) const SizedBox.expand()],
          centralBar: const SizedBox.shrink(),
          actionHub: const SizedBox.shrink(),
        ),
      ),
    ),
  ));
  return [
    for (int i = 0; i < n; i++)
      () {
        final c = tester.getCenter(find.byKey(ValueKey('grid_slot_$i')));
        return Offset(c.dx / size.width - 0.5, c.dy / size.height - 0.5);
      }(),
  ];
}

void main() {
  testWidgets(
      'zoneCentresFor suit AdaptiveGrid : mêmes centres que la grille rendue, '
      '2 à 8 joueurs, téléphone et Fold', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in const [_phone, _fold]) {
      for (int n = 2; n <= 8; n++) {
        final rendered = await _renderedCentres(tester, size, n);
        final model = zoneCentresFor(size, tableLayoutFor(size, n));
        for (int i = 0; i < n; i++) {
          expect(model[i].dx, closeTo(rendered[i].dx, 1e-6),
              reason: '$size, $n joueurs, zone $i (x)');
          expect(model[i].dy, closeTo(rendered[i].dy, 1e-6),
              reason: '$size, $n joueurs, zone $i (y)');
        }
      }
    }
  });

  testWidgets(
      'chaque zone reçoit le côté que SA position rendue appelle '
      '(Face-à-face, Côtés, Triangle, Même sens)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in const [_phone, _fold]) {
      for (int n = 2; n <= 8; n++) {
        // Les règles sont vérifiées sur les centres RENDUS, pas sur le
        // modèle : c'est la position que voit le joueur qui compte.
        final rendered = await _renderedCentres(tester, size, n);
        final ff = sidesForPreset(_f, rendered);
        final sides = sidesForPreset(_s, rendered);
        final tri = sidesForPreset(_t, rendered);
        final same = sidesForPreset(_m, rendered);
        for (int i = 0; i < n; i++) {
          final c = rendered[i];
          final where = '$size, $n joueurs, zone $i en $c';
          expect(ff[i], c.dy < -1e-6 ? TableSide.top : TableSide.bottom,
              reason: 'Face-à-face, $where');
          if (c.dx.abs() > 1e-6) {
            final lateral = c.dx < 0 ? TableSide.left : TableSide.right;
            expect(sides[i], lateral, reason: 'Côtés, $where');
            expect(tri[i], lateral, reason: 'Triangle, $where');
          } else {
            expect(sides[i], c.dy < 0 ? TableSide.left : TableSide.right,
                reason: 'Côtés, bande pleine largeur, $where');
            expect(tri[i], ff[i], reason: 'Triangle, bande, $where');
          }
          expect(same[i], TableSide.bottom, reason: 'Même sens, $where');
        }
      }
    }
  });

  test(
      'Cercle : chaque zone regarde le bord le plus proche de son centre, '
      'en moulinet horaire sur une grille 2×2', () {
    // Quatre quadrants exactement sur les diagonales : l'égalité se
    // tranche dans le sens horaire, quatre bords distincts.
    const quadrants = [
      Offset(-0.25, -0.25), // haut-gauche
      Offset(0.25, -0.25), // haut-droite
      Offset(-0.25, 0.25), // bas-gauche
      Offset(0.25, 0.25), // bas-droite
    ];
    expect(sidesForPreset(_c, quadrants), [
      TableSide.top,
      TableSide.right,
      TableSide.left,
      TableSide.bottom,
    ]);
    // Hors diagonale, le bord le plus proche l'emporte.
    expect(
      sidesForPreset(_c, const [
        Offset(-0.4, 0.1),
        Offset(0.1, -0.3),
        Offset(0.4, -0.1),
        Offset(-0.1, 0.3),
      ]),
      [TableSide.left, TableSide.top, TableSide.right, TableSide.bottom],
    );
  });

  test(
      'à 5-6 joueurs sur la disposition `around`, Cercle retrouve les '
      'sièges de la table', () {
    for (final n in const [5, 6]) {
      final layout = tableLayoutFor(_fold, n);
      expect(layout.useSideColumns, isTrue,
          reason: 'précondition : colonnes latérales au Fold, $n joueurs');
      expect(
        sidesForPreset(_c, zoneCentresFor(_fold, layout)),
        [for (final seat in layout.seats) seat.side],
        reason: '$n joueurs',
      );
    }
  });

  group('presets proposés et leurs angles', () {
    for (final size in _expected.keys) {
      for (final entry in _expected[size]!.entries) {
        final n = entry.key;
        test('$size, $n joueurs', () {
          final offered = offeredOrientationPresets(size, n);
          expect(
            [for (final o in offered) o.preset],
            [for (final e in entry.value) e.$1],
            reason: 'presets proposés, dans l\'ordre de la barre',
          );
          for (int k = 0; k < offered.length; k++) {
            expect(offered[k].quarterTurns, entry.value[k].$2,
                reason: offered[k].preset.label);
          }
        });
      }
    }
  });

  test('disponibilité par effectif (spec §1.7, ordre de la maquette à 4)', () {
    expect(presetsOfferedFor(2), [_f, _s, _m]);
    expect(presetsOfferedFor(3), [_f, _t, _m]);
    expect(presetsOfferedFor(4), [_s, _f, _c, _m]);
    expect(presetsOfferedFor(5), [_f, _c, _m]);
    expect(presetsOfferedFor(6), [_f, _c, _m]);
    expect(presetsOfferedFor(7), [_f, _m]);
    expect(presetsOfferedFor(8), [_f, _m]);
  });

  test('libellés français', () {
    expect([for (final p in OrientationPreset.values) p.label], [
      'Face-à-face',
      'Côtés',
      'Triangle',
      'Cercle',
      'Même sens',
    ]);
  });

  test(
      'deux presets au même résultat ne sont proposés qu\'une fois, sous le '
      'nom du premier', () {
    // Deux zones côte à côte dans la moitié basse : Face-à-face les met
    // toutes deux en bas, exactement comme Même sens.
    final offered = offeredPresetsForCentres(const [
      Offset(-0.25, 0.25),
      Offset(0.25, 0.25),
    ]);
    expect([for (final o in offered) o.preset], [_f, _s]);
    expect(offered.first.quarterTurns, [0, 0]);
  });
}
