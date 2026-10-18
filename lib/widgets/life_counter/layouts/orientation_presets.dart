// lib/widgets/life_counter/layouts/orientation_presets.dart
//
// Presets d'orientation de toute la table (spec §1.7) : Face-à-face, Côtés,
// Triangle, Cercle, Même sens.
//
// Pourquoi un fichier à part, en fonctions pures : la première version de
// ces presets écrivait des listes d'angles en dur, ou une arithmétique sur
// l'index d'affichage (`i.isEven ? 1 : 3`). Les deux supposent une
// disposition ; dès que la grille change (colonnes latérales, sous-grille à
// 8, repli face-à-face sur téléphone), elles tournent des joueurs vers un
// bord où ils ne sont pas. Ici chaque preset part de la POSITION RENDUE de
// chaque zone, en déduit un `TableSide`, et laisse `TableSide.quarterTurns`
// (table_seat.dart, seule table côté → rotation) donner l'angle.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

/// Les cinq agencements de toute la table que la spec §1.7 nomme.
enum OrientationPreset { faceToFace, sides, triangle, circle, sameWay }

extension OrientationPresetLabel on OrientationPreset {
  /// Libellé affiché dans la barre du mode réorganisation.
  String get label => switch (this) {
        OrientationPreset.faceToFace => 'Face-à-face',
        OrientationPreset.sides => 'Côtés',
        OrientationPreset.triangle => 'Triangle',
        OrientationPreset.circle => 'Cercle',
        OrientationPreset.sameWay => 'Même sens',
      };
}

/// Presets proposés pour un effectif, dans l'ordre d'affichage de la barre.
///
/// La spec ne propose que ceux qui « conviennent au nombre de joueurs ». À 4,
/// l'ordre est celui de la maquette (Côtés d'abord). Triangle n'a de sens
/// qu'à trois ; Côtés qu'à deux et quatre, où chaque moitié gauche/droite
/// reçoit un nombre égal de joueurs ; Cercle à partir de quatre, quand il y
/// a de quoi occuper les quatre bords. Au-delà de six, la table n'est plus
/// qu'une double rangée : seuls Face-à-face et Même sens y décrivent quelque
/// chose.
List<OrientationPreset> presetsOfferedFor(int playerCount) =>
    switch (playerCount) {
      2 => const [
          OrientationPreset.faceToFace,
          OrientationPreset.sides,
          OrientationPreset.sameWay,
        ],
      3 => const [
          OrientationPreset.faceToFace,
          OrientationPreset.triangle,
          OrientationPreset.sameWay,
        ],
      4 => const [
          OrientationPreset.sides,
          OrientationPreset.faceToFace,
          OrientationPreset.circle,
          OrientationPreset.sameWay,
        ],
      5 || 6 => const [
          OrientationPreset.faceToFace,
          OrientationPreset.circle,
          OrientationPreset.sameWay,
        ],
      _ => const [OrientationPreset.faceToFace, OrientationPreset.sameWay],
    };

/// Centre de chaque zone, dans l'ordre d'AFFICHAGE, relativement au centre
/// de la table et rapporté à sa taille : `dx` et `dy` vont de -0.5 (bord
/// gauche / haut) à +0.5 (bord droit / bas).
///
/// Reproduit le placement d'`AdaptiveGrid` pour [layout] : rangées haute et
/// basse (en sous-grille 2×2 à huit joueurs), colonnes latérales de
/// `layout.sideWidth`, ou deux colonnes égales quand aucun siège n'est en
/// haut ni en bas (`columnPairs`). Le test « zoneCentresFor suit
/// AdaptiveGrid » compare ce modèle aux centres réellement rendus : si la
/// grille change de géométrie sans lui, ce test casse.
///
/// La couture centrale (bande d'actions ou hub) est ignorée. Elle est
/// symétrique, ne fait donc changer aucune zone de moitié, mais elle
/// allongerait d'autant la distance verticale au centre : dans une grille
/// 2×2, chaque zone cesserait d'être exactement sur la diagonale, et Cercle
/// prendrait la bande pour une préférence haut/bas qu'aucun joueur n'a.
List<Offset> zoneCentresFor(Size gridSize, TableLayout layout) {
  final seats = layout.seats;
  final n = seats.length;
  final centres = List<Offset>.filled(n, Offset.zero);

  List<int> onSide(TableSide side) {
    final indices = [
      for (int i = 0; i < n; i++)
        if (seats[i].side == side) i,
    ];
    indices.sort((a, b) => seats[a].slot.compareTo(seats[b].slot));
    return indices;
  }

  final top = onSide(TableSide.top);
  final bottom = onSide(TableSide.bottom);
  final left = onSide(TableSide.left);
  final right = onSide(TableSide.right);

  final side =
      layout.useSideColumns && gridSize.width > 0 ? layout.sideWidth / gridSize.width : 0.0;

  // Une colonne : zones empilées à parts égales sur toute la hauteur.
  void column(List<int> zones, double x0, double x1) {
    for (int k = 0; k < zones.length; k++) {
      centres[zones[k]] = Offset((x0 + x1) / 2, (k + 0.5) / zones.length);
    }
  }

  // Une moitié : une rangée à parts égales, ou 2×2 à huit joueurs (même
  // règle qu'`AdaptiveGrid._half`).
  void half(List<int> zones, double y0, double y1) {
    final x0 = side, x1 = 1 - side;
    if (n == 8 && zones.length == 4) {
      for (int k = 0; k < 4; k++) {
        final col = k % 2, row = k ~/ 2;
        centres[zones[k]] = Offset(
          x0 + (x1 - x0) * (col + 0.5) / 2,
          y0 + (y1 - y0) * (row + 0.5) / 2,
        );
      }
      return;
    }
    for (int k = 0; k < zones.length; k++) {
      centres[zones[k]] = Offset(
        x0 + (x1 - x0) * (k + 0.5) / zones.length,
        (y0 + y1) / 2,
      );
    }
  }

  if (top.isNotEmpty || bottom.isNotEmpty) {
    half(top, 0, 0.5);
    half(bottom, 0.5, 1);
    if (layout.useSideColumns) {
      column(left, 0, side);
      column(right, 1 - side, 1);
    }
  } else {
    // `columnPairs` : deux colonnes égales. La variante en deux rangées de
    // deux (quand la bande s'y loge) donne les mêmes cellules.
    column(left, 0, 0.5);
    column(right, 0.5, 1);
  }

  return [for (final c in centres) Offset(c.dx - 0.5, c.dy - 0.5)];
}

// Tolérance des comparaisons : les centres sont des fractions exactes de la
// table (1/4, 1/3…), seule l'arithmétique flottante les écarte.
const double _eps = 1e-9;

/// Côté attribué à chaque zone par [preset], d'après son centre (voir
/// [zoneCentresFor]). Chaque règle est géométrique :
///
/// - Face-à-face : moitié haute → top, sinon bottom. Une zone à cheval sur
///   l'axe horizontal (colonne latérale pleine hauteur, à 5-6 joueurs) va
///   en bas, du côté de celui qui tient l'appareil -- même règle que le
///   joueur surnuméraire de `_faceToFace`.
/// - Côtés : moitié gauche → left, droite → right. Une zone à cheval sur
///   l'axe vertical (bande pleine largeur, à deux joueurs) se range par sa
///   moitié : haute → left, basse → right. C'est l'ancien « Côte à côte »
///   `[1, 3]` : deux joueurs assis sur les deux grands bords d'un téléphone
///   posé entre eux, chacun lisant sa bande en travers.
/// - Triangle : une zone à cheval sur l'axe vertical garde son bord haut ou
///   bas ; les autres vont au bord latéral de leur moitié. À trois joueurs
///   (une bande en haut, deux zones en bas), cela donne un joueur en tête de
///   table et deux sur les côtés.
/// - Cercle : chaque zone regarde le bord dont son centre est le plus
///   proche, distance rapportée à la taille de la table. À égalité (zone
///   exactement sur une diagonale, cas des quatre quadrants d'une grille
///   2×2), elle prend le bord qui part de son coin dans le sens horaire :
///   haut-gauche → top, haut-droite → right, bas-droite → bottom,
///   bas-gauche → left. D'où le « moulinet » à quatre joueurs, quatre bords
///   distincts ; et, sur la disposition `around` à 5-6, exactement ses
///   sièges.
/// - Même sens : tout le monde en bas.
List<TableSide> sidesForPreset(
  OrientationPreset preset,
  List<Offset> centres,
) {
  TableSide verticalHalf(Offset c) =>
      c.dy < -_eps ? TableSide.top : TableSide.bottom;

  TableSide lateralHalf(Offset c) =>
      c.dx < 0 ? TableSide.left : TableSide.right;

  bool straddlesVerticalAxis(Offset c) => c.dx.abs() <= _eps;

  TableSide nearestEdge(Offset c) {
    final h = c.dx.abs(), v = c.dy.abs();
    if (h > v + _eps) return lateralHalf(c);
    if (v > h + _eps) return verticalHalf(c);
    if (h <= _eps) return TableSide.bottom; // zone unique au centre
    // Égalité : le bord qui part du coin de la zone dans le sens horaire.
    if (c.dy < 0) return c.dx < 0 ? TableSide.top : TableSide.right;
    return c.dx > 0 ? TableSide.bottom : TableSide.left;
  }

  return [
    for (final c in centres)
      switch (preset) {
        OrientationPreset.faceToFace => verticalHalf(c),
        OrientationPreset.sides => straddlesVerticalAxis(c)
            ? (c.dy < 0 ? TableSide.left : TableSide.right)
            : lateralHalf(c),
        OrientationPreset.triangle =>
          straddlesVerticalAxis(c) ? verticalHalf(c) : lateralHalf(c),
        OrientationPreset.circle => nearestEdge(c),
        OrientationPreset.sameWay => TableSide.bottom,
      },
  ];
}

/// Un preset tel qu'il est proposé : son nom et l'angle de chaque zone,
/// dans l'ordre d'affichage.
typedef OfferedOrientationPreset = ({
  OrientationPreset preset,
  List<int> quarterTurns,
});

/// Presets proposés pour des zones centrées en [centres] (ordre
/// d'affichage), avec leurs rotations.
///
/// Deux presets au résultat identique sur cette disposition ne sont proposés
/// qu'une fois, sous le nom du premier de la liste : deux boutons qui font
/// la même chose sous deux noms mentiraient sur ce qu'ils font.
List<OfferedOrientationPreset> offeredPresetsForCentres(List<Offset> centres) {
  final offered = <OfferedOrientationPreset>[];
  for (final preset in presetsOfferedFor(centres.length)) {
    final turns = [
      for (final side in sidesForPreset(preset, centres)) side.quarterTurns,
    ];
    if (offered.any((o) => listEquals(o.quarterTurns, turns))) continue;
    offered.add((preset: preset, quarterTurns: turns));
  }
  return offered;
}

/// Angles que [preset] pose, dans l'ordre d'affichage, pour [playerCount]
/// joueurs sur une table de [gridSize].
///
/// Pour l'appelant qui applique un preset : il recalcule ses angles sur la
/// table mesurée AU MOMENT DE L'APPUI, au lieu de garder ceux qu'il avait au
/// dernier rendu de la barre -- qui pouvaient décrire une table d'avant un
/// pliage.
List<int> orientationPresetTurns(
  OrientationPreset preset,
  Size gridSize,
  int playerCount,
) => [
      for (final side in sidesForPreset(
        preset,
        zoneCentresFor(gridSize, tableLayoutFor(gridSize, playerCount)),
      ))
        side.quarterTurns,
    ];

/// Presets proposés pour [playerCount] joueurs sur une table de [gridSize],
/// d'après la disposition que `tableLayoutFor` y retient -- celle
/// qu'`AdaptiveGrid` rend.
List<OfferedOrientationPreset> offeredOrientationPresets(
  Size gridSize,
  int playerCount,
) =>
    offeredPresetsForCentres(
      zoneCentresFor(gridSize, tableLayoutFor(gridSize, playerCount)),
    );
