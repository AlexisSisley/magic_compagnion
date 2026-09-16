# Life Counter V4 — Lot 6 : Table multijoueur — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire qu'une partie à 4-6 joueurs autour d'un appareil posé à plat soit lisible et jouable depuis chaque siège, en remplaçant la règle de disposition face-à-face figée d'`AdaptiveGrid` par un modèle de sièges, et en donnant à `PlayerZone` un contrat de densité.

**Architecture :** Deux fonctions pures portent toutes les décisions — `seatsFor(playerCount)` pour la géométrie, `tierFor(size)` pour la densité. `AdaptiveGrid` cesse de décider quoi que ce soit et devient un moteur de rendu piloté par les sièges. `PlayerZone` lit son cran depuis sa propre boîte mesurée. Aucun champ de modèle n'est ajouté : `PlayerState.quarterTurns` et `playerOrder` existent déjà.

**Tech Stack :** Flutter, Riverpod 3 (`Notifier`, `NotifierProvider.family`), `flutter_test`.

**Spec :** `docs/superpowers/specs/2026-09-16-life-counter-v4-lot6-table-multijoueur-design.md`
**Spec parente :** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md`

---

## Global Constraints

Ces contraintes s'appliquent à **toutes** les tâches. Elles sont la conséquence directe des cinq constats Critical des lots 1 à 3, tous trouvés avec des tests verts.

1. **`git add` avec chemins explicites uniquement.** Jamais `git add -A`, jamais `git commit -a`. Le dépôt est partagé avec une autre session qui laisse régulièrement des fichiers en cours dans `lib/` et `test/`.
2. **Les gestes se jouent, ils ne se simulent pas.** `tester.tap(...)`, jamais un appel direct au callback. C'est ce qui a révélé qu'`EliminationOverlay` absorbait tous les gestes d'une zone éliminée.
3. **Un glissement se livre en incréments.** Jamais un `PointerMoveEvent` unique de 130 px : un doigt réel en livre une dizaine de petits. Utiliser `TestGesture.moveBy` en boucle. C'est ce qui a rendu l'accélération de la molette inerte sur appareil sans qu'aucun test ne le voie.
4. **Tout test de non-régression doit discriminer.** Avant de commiter, casser temporairement le code que le test protège et vérifier que le test échoue. Un test qui passe dans les deux cas est à réécrire, pas à garder.
5. **Aucun nouveau geste global.** Ce lot déplace et pivote des zones existantes. La surface de gestes de `life_dial.dart` a coûté trois rondes de correction ; si un besoin de geste global apparaît, il se pose en question, il ne s'implémente pas.
6. **Typographie :** `AppTextStyles.lifeNumeral()` et `AppTextStyles.lifeBadge()`, jamais de `TextStyle` brut.
7. **Convention de rotation, valable partout dans ce plan :** `quarterTurns` est le paramètre de `RotatedBox`, qui tourne **dans le sens horaire**. Le texte d'un joueur a son haut qui pointe **à l'opposé** de lui. D'où : joueur en bas = 0, à gauche = 1, en haut = 2, à droite = 3.

---

## Forme des tests dans ce plan

**Les tests de fonctions pures sont écrits verbatim. Les tests de widgets sont décrits par leurs assertions, pas par leur code.**

Ce n'est pas de la paresse, c'est une correction. Les plans des lots 1 et 2 prescrivaient du code de test écrit de mémoire ; il a produit **six défauts de compilation**, dont un `enum` pris pour un `int` et une API Riverpod mal employée. Le lot 3 est passé aux assertions décrites : zéro défaut de ce type.

Ce plan a été revu sur ce critère après coup, et deux blocs de son premier jet ne compilaient pas — `GameSession.newGame(playerCount: 4)` alors que la factory prend `playerConfigs`, et `CriticalOverlay(level: 2)` alors que `level` est un `CriticalLevel`. Les deux sont corrigés ci-dessous. La règle vaut pour l'implémenteur : **lis la signature, n'écris pas de mémoire.**

Une fonction pure de ce lot (`seatsFor`, `tierFor`) n'a ni dépendance ni API à deviner — son test reste verbatim et sert de référence de style.

---

## Écarts constatés entre la spec et le code livré

À vérifier au démarrage, ils changent deux tâches :

- **`_calculateDefaultRotation` n'existe plus.** La spec §2.4 dit « est supprimée, remplacée par `seatsFor` ». Les lots 1 à 3 l'ont déjà retirée : `grep -rn "calculateDefaultRotation" lib/ test/` ne renvoie rien. Il n'y a donc rien à supprimer — seulement `seatsFor` à brancher là où les rotations initiales sont posées, c'est-à-dire la factory `GameSession.newGame` (`lib/models/game_session.dart:147`), qui crée aujourd'hui chaque `PlayerState` avec `quarterTurns` à sa valeur par défaut de 0.
- **Les tests existants d'`AdaptiveGrid` ne discriminent pas.** `test/widgets/life_counter/layouts/adaptive_grid_test.dart` n'assère que la présence des zones (`findsOneWidget`), jamais leur position ni leur rotation. Ils passeraient sur n'importe quelle disposition. La tâche 2 les remplace ; ne pas se reposer dessus comme filet de non-régression.

---

## File Structure

**Créés :**
- `lib/models/table_seat.dart` — `TableSide`, `TableSeat`, `seatsFor(int)`. Pure, aucune dépendance Flutter hors `meta`.
- `lib/widgets/life_counter/layouts/density_tier.dart` — `DensityTier`, `tierFor(Size)`. Pure.
- `test/models/table_seat_test.dart`
- `test/widgets/life_counter/layouts/density_tier_test.dart`

**Modifiés :**
- `lib/widgets/life_counter/layouts/adaptive_grid.dart` — perd sa règle de décision, gagne les côtés gauche/droite.
- `lib/models/game_session.dart:147` — `newGame` pose la rotation initiale depuis `seatsFor`.
- `lib/widgets/life_counter/player_zone.dart` — contrat de densité, badge de dégâts en attente déplacé dans le repère de la zone.
- `lib/widgets/life_counter/zone/conditional_handle.dart` — `reservedHeight` variable vers le haut.
- `lib/pages/life_counter/life_counter_page.dart` — la pile d'overlays devient non-absorbante.
- `test/widgets/life_counter/layouts/adaptive_grid_test.dart` — réécrit pour discriminer.
- `test/widgets/life_counter/zone/conditional_handle_test.dart` — un test ajouté, les existants intacts.
- `test/widgets/life_counter/player_zone_test.dart`

---

## Task 1 : `TableSeat` et `seatsFor`

Fonction pure, aucun consommateur à ce stade. C'est le seul endroit du lot où la géométrie est décidée.

**Files:**
- Create: `lib/models/table_seat.dart`
- Test: `test/models/table_seat_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces:
  - `enum TableSide { top, right, bottom, left }`
  - `class TableSeat { final TableSide side; final int slot; final int slotCount; int get quarterTurns; }`
  - `List<TableSeat> seatsFor(int playerCount)` — longueur égale à `playerCount`, indexée comme `playerOrder`.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/models/table_seat_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';

void main() {
  group('TableSeat.quarterTurns', () {
    // Convention : RotatedBox tourne dans le sens horaire, et le haut du texte
    // d'un joueur pointe à l'opposé de lui.
    test('bas = 0, gauche = 1, haut = 2, droite = 3', () {
      expect(const TableSeat(side: TableSide.bottom, slot: 0, slotCount: 1).quarterTurns, 0);
      expect(const TableSeat(side: TableSide.left, slot: 0, slotCount: 1).quarterTurns, 1);
      expect(const TableSeat(side: TableSide.top, slot: 0, slotCount: 1).quarterTurns, 2);
      expect(const TableSeat(side: TableSide.right, slot: 0, slotCount: 1).quarterTurns, 3);
    });
  });

  group('seatsFor', () {
    test('retourne exactement un siège par joueur, de 2 à 8', () {
      for (int n = 2; n <= 8; n++) {
        expect(seatsFor(n).length, n, reason: '$n joueurs');
      }
    });

    test('2 joueurs : haut, bas', () {
      final seats = seatsFor(2);
      expect(seats.map((s) => s.side).toList(), [TableSide.top, TableSide.bottom]);
      expect(seats.map((s) => s.quarterTurns).toList(), [2, 0]);
    });

    test('3 joueurs : 1 haut, 2 bas', () {
      final seats = seatsFor(3);
      expect(seats.map((s) => s.side).toList(),
          [TableSide.top, TableSide.bottom, TableSide.bottom]);
      expect(seats[1].slotCount, 2);
      expect(seats[1].slot, 0);
      expect(seats[2].slot, 1);
    });

    test('4 joueurs : un par côté, dans l ordre haut/droite/bas/gauche', () {
      final seats = seatsFor(4);
      expect(seats.map((s) => s.side).toList(),
          [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left]);
      expect(seats.map((s) => s.quarterTurns).toList(), [2, 3, 0, 1]);
      expect(seats.every((s) => s.slotCount == 1), isTrue);
    });

    test('5 joueurs : 2 haut, 1 droite, 1 bas, 1 gauche', () {
      final seats = seatsFor(5);
      expect(seats.map((s) => s.side).toList(), [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.left,
      ]);
      expect(seats[0].slotCount, 2);
      expect(seats[1].slot, 1);
    });

    test('6 joueurs : 2 haut, 1 droite, 2 bas, 1 gauche', () {
      final seats = seatsFor(6);
      expect(seats.map((s) => s.side).toList(), [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.bottom, TableSide.left,
      ]);
      expect(seats[3].slotCount, 2);
      expect(seats[4].slot, 1);
    });

    test('7 joueurs : retour au face-a-face, 3 haut 4 bas', () {
      final seats = seatsFor(7);
      expect(seats.where((s) => s.side == TableSide.top).length, 3);
      expect(seats.where((s) => s.side == TableSide.bottom).length, 4);
      expect(seats.any((s) => s.side == TableSide.left || s.side == TableSide.right),
          isFalse,
          reason: 'au-dela de 6, les sieges lateraux deviennent illisibles');
    });

    test('8 joueurs : 4 haut 4 bas, aucun siege lateral', () {
      final seats = seatsFor(8);
      expect(seats.where((s) => s.side == TableSide.top).length, 4);
      expect(seats.where((s) => s.side == TableSide.bottom).length, 4);
      expect(seats.any((s) => s.side == TableSide.left || s.side == TableSide.right),
          isFalse);
    });

    test('les slots d un meme cote sont contigus et commencent a zero', () {
      for (int n = 2; n <= 8; n++) {
        final seats = seatsFor(n);
        for (final side in TableSide.values) {
          final onSide = seats.where((s) => s.side == side).toList();
          if (onSide.isEmpty) continue;
          final slots = onSide.map((s) => s.slot).toList()..sort();
          expect(slots, List.generate(onSide.length, (i) => i),
              reason: '$n joueurs, cote $side');
          expect(onSide.every((s) => s.slotCount == onSide.length), isTrue,
              reason: '$n joueurs, cote $side : slotCount incoherent');
        }
      }
    });

    test('1 joueur ou moins : un seul siege en bas, pas de crash', () {
      expect(seatsFor(1).length, 1);
      expect(seatsFor(1).single.side, TableSide.bottom);
      expect(seatsFor(0), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/models/table_seat_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'magic_companion/models/table_seat.dart'`

- [ ] **Step 3: Écrire le modèle**

Créer `lib/models/table_seat.dart` :

```dart
// lib/models/table_seat.dart
// Geometrie de table du lot 6 (spec lot 6 §2).
//
// Cette fonction est le SEUL endroit ou la disposition des joueurs est decidee.
// AdaptiveGrid ne fait que rendre ce qu'elle retourne.

/// Cote de la table ou un joueur est assis.
enum TableSide { top, right, bottom, left }

/// La place d'un joueur autour de l'appareil pose a plat.
class TableSeat {
  const TableSeat({
    required this.side,
    required this.slot,
    required this.slotCount,
  });

  final TableSide side;

  /// Position sur ce cote, de 0 a `slotCount - 1`.
  final int slot;

  /// Nombre de joueurs qui partagent ce cote.
  final int slotCount;

  /// Rotation a appliquer via `RotatedBox`, qui tourne dans le sens HORAIRE.
  ///
  /// Le haut du texte d'un joueur pointe a l'oppose de lui : un joueur assis
  /// a l'est lit un texte dont le haut pointe vers l'ouest, soit un quart de
  /// tour anti-horaire, soit trois quarts de tour horaires.
  int get quarterTurns => switch (side) {
        TableSide.bottom => 0,
        TableSide.left => 1,
        TableSide.top => 2,
        TableSide.right => 3,
      };

  @override
  String toString() => 'TableSeat($side, $slot/$slotCount)';
}

/// Sieges par defaut pour `playerCount` joueurs, indexes comme `playerOrder`.
///
/// De 4 a 6 joueurs, les quatre cotes sont utilises : c'est le mode d'usage
/// reel, l'appareil pose a plat au centre de la table. Au-dela de 6, on
/// repasse en face-a-face — quatre cotes ne suffisent plus et un cote latéral
/// partage a trois devient illisible.
List<TableSeat> seatsFor(int playerCount) {
  if (playerCount <= 0) return const [];

  // Repartition par cote, dans l'ordre d'affectation des joueurs.
  final List<TableSide> sides = switch (playerCount) {
    1 => [TableSide.bottom],
    2 => [TableSide.top, TableSide.bottom],
    3 => [TableSide.top, TableSide.bottom, TableSide.bottom],
    4 => [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left],
    5 => [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.left,
      ],
    6 => [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.bottom, TableSide.left,
      ],
    _ => _faceToFace(playerCount),
  };

  final counts = <TableSide, int>{};
  for (final side in sides) {
    counts[side] = (counts[side] ?? 0) + 1;
  }

  final used = <TableSide, int>{};
  return sides.map((side) {
    final slot = used[side] ?? 0;
    used[side] = slot + 1;
    return TableSeat(side: side, slot: slot, slotCount: counts[side]!);
  }).toList(growable: false);
}

/// Regle historique conservee au-dela de 6 joueurs : moitie haute en face,
/// moitie basse du cote de l'utilisateur, l'impair allant en bas.
List<TableSide> _faceToFace(int playerCount) {
  final topCount = playerCount ~/ 2;
  return [
    for (int i = 0; i < topCount; i++) TableSide.top,
    for (int i = topCount; i < playerCount; i++) TableSide.bottom,
  ];
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/models/table_seat_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 5: Vérifier que les tests discriminent**

Contrainte globale 4. Inverser temporairement deux lignes du `switch` de `quarterTurns` (`TableSide.left => 3, TableSide.right => 1`), relancer, vérifier que **deux** tests échouent, puis rétablir.

Run: `flutter test test/models/table_seat_test.dart`
Expected après inversion : FAIL sur `bas = 0, gauche = 1, haut = 2, droite = 3` et `4 joueurs`.

- [ ] **Step 6: Commit**

```bash
git add lib/models/table_seat.dart test/models/table_seat_test.dart
git commit -m "feat: add TableSeat and seatsFor, the lot 6 seating geometry"
```

---

## Task 2 : `AdaptiveGrid` devient un moteur de rendu

Aucun changement visible : à 2, 3, 7 et 8 joueurs le rendu est identique. C'est la tâche de non-régression qui autorise la tâche 3.

**Files:**
- Modify: `lib/widgets/life_counter/layouts/adaptive_grid.dart`
- Test: `test/widgets/life_counter/layouts/adaptive_grid_test.dart` (réécrit)

**Interfaces:**
- Consumes: `seatsFor`, `TableSeat`, `TableSide` (tâche 1).
- Produces: `AdaptiveGrid({required List<Widget> playerZones, required Widget centralBar})` — signature **inchangée**, les appelants ne bougent pas.

- [ ] **Step 1: Écrire les tests qui échouent**

Remplacer intégralement `test/widgets/life_counter/layouts/adaptive_grid_test.dart`. Les tests existants n'assèrent que la présence ; ceux-ci assèrent position et rotation, seules propriétés qui distinguent une disposition d'une autre.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';

Widget _grid(int playerCount) {
  return MaterialApp(
    home: Scaffold(
      body: AdaptiveGrid(
        playerZones: List.generate(
          playerCount,
          (i) => Container(key: ValueKey('player_$i')),
        ),
        centralBar: Container(key: const ValueKey('central_bar'), height: 60),
      ),
    ),
  );
}

Offset _centerOf(WidgetTester tester, int index) =>
    tester.getCenter(find.byKey(ValueKey('player_$index')));

/// Rotation effectivement appliquee a une zone par la grille.
int _quarterTurnsOf(WidgetTester tester, int index) {
  final boxes = tester.widgetList<RotatedBox>(
    find.ancestor(
      of: find.byKey(ValueKey('player_$index')),
      matching: find.byType(RotatedBox),
    ),
  );
  // Une seule RotatedBox par zone ; zero si la grille n'en pose pas.
  return boxes.isEmpty ? 0 : boxes.first.quarterTurns % 4;
}

void main() {
  group('AdaptiveGrid — non-regression face-a-face', () {
    testWidgets('2 joueurs : joueur 0 au-dessus du joueur 1, retourne',
        (tester) async {
      await tester.pumpWidget(_grid(2));
      expect(_centerOf(tester, 0).dy, lessThan(_centerOf(tester, 1).dy));
      expect(_quarterTurnsOf(tester, 0), 2);
      expect(_quarterTurnsOf(tester, 1), 0);
    });

    testWidgets('3 joueurs : 1 en haut, 2 en bas cote a cote', (tester) async {
      await tester.pumpWidget(_grid(3));
      expect(_centerOf(tester, 0).dy, lessThan(_centerOf(tester, 1).dy));
      expect(_centerOf(tester, 1).dy, equals(_centerOf(tester, 2).dy));
      expect(_centerOf(tester, 1).dx, lessThan(_centerOf(tester, 2).dx));
      expect(_quarterTurnsOf(tester, 0), 2);
    });

    testWidgets('7 joueurs : 3 en haut retournes, 4 en bas', (tester) async {
      await tester.pumpWidget(_grid(7));
      for (int i = 0; i < 3; i++) {
        expect(_quarterTurnsOf(tester, i), 2, reason: 'joueur $i');
      }
      for (int i = 3; i < 7; i++) {
        expect(_quarterTurnsOf(tester, i), 0, reason: 'joueur $i');
        expect(_centerOf(tester, i).dy, greaterThan(_centerOf(tester, 0).dy));
      }
    });

    testWidgets('8 joueurs : deux sous-grilles 2x2', (tester) async {
      await tester.pumpWidget(_grid(8));
      // Moitie haute : 0 et 1 sur une rangee, 2 et 3 sur la suivante.
      expect(_centerOf(tester, 0).dy, equals(_centerOf(tester, 1).dy));
      expect(_centerOf(tester, 0).dy, lessThan(_centerOf(tester, 2).dy));
      expect(_centerOf(tester, 2).dy, equals(_centerOf(tester, 3).dy));
      // Moitie basse.
      expect(_centerOf(tester, 4).dy, equals(_centerOf(tester, 5).dy));
      expect(_centerOf(tester, 4).dy, lessThan(_centerOf(tester, 6).dy));
      for (int i = 0; i < 4; i++) {
        expect(_quarterTurnsOf(tester, i), 2, reason: 'joueur $i');
      }
    });

    testWidgets('la barre centrale est rendue et separe les deux moities',
        (tester) async {
      await tester.pumpWidget(_grid(2));
      final bar = tester.getCenter(find.byKey(const ValueKey('central_bar')));
      expect(_centerOf(tester, 0).dy, lessThan(bar.dy));
      expect(_centerOf(tester, 1).dy, greaterThan(bar.dy));
    });
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/layouts/adaptive_grid_test.dart`
Expected: FAIL — la grille actuelle ne pose pas de `RotatedBox` sur les zones basses (le helper retourne 0, ce qui passe), mais `8 joueurs` et `7 joueurs` échouent sur les positions si la sous-grille diffère. Noter précisément quels tests échouent : si **aucun** n'échoue, les tests ne discriminent pas encore et il faut les renforcer avant de continuer.

- [ ] **Step 3: Réécrire la grille**

Remplacer intégralement `lib/widgets/life_counter/layouts/adaptive_grid.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:magic_companion/models/table_seat.dart';

/// Moteur de rendu des zones joueur (spec lot 6 §2.1).
///
/// Cette classe ne decide plus de la disposition : elle rend les sieges que
/// `seatsFor` lui donne. Toute question de geometrie se tranche dans
/// `lib/models/table_seat.dart`, pas ici.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.playerZones,
    required this.centralBar,
  });

  final List<Widget> playerZones;
  final Widget centralBar;

  /// Part de largeur prise par une colonne laterale quand elle existe.
  static const double sideColumnFraction = 0.22;

  @override
  Widget build(BuildContext context) {
    final seats = seatsFor(playerZones.length);

    List<Widget> zonesOn(TableSide side) {
      final indexed = <int>[];
      for (int i = 0; i < seats.length; i++) {
        if (seats[i].side == side) indexed.add(i);
      }
      indexed.sort((a, b) => seats[a].slot.compareTo(seats[b].slot));
      return indexed
          .map((i) => _rotated(playerZones[i], seats[i].quarterTurns))
          .toList();
    }

    final top = zonesOn(TableSide.top);
    final bottom = zonesOn(TableSide.bottom);
    final left = zonesOn(TableSide.left);
    final right = zonesOn(TableSide.right);

    final useSubGrid = playerZones.length == 8;

    final centre = Column(
      children: [
        Expanded(child: _half(top, useSubGrid: useSubGrid)),
        centralBar,
        Expanded(child: _half(bottom, useSubGrid: useSubGrid)),
      ],
    );

    if (left.isEmpty && right.isEmpty) return centre;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideWidth = constraints.maxWidth * sideColumnFraction;
        return Row(
          children: [
            if (left.isNotEmpty)
              SizedBox(width: sideWidth, child: _column(left)),
            Expanded(child: centre),
            if (right.isNotEmpty)
              SizedBox(width: sideWidth, child: _column(right)),
          ],
        );
      },
    );
  }

  static Widget _rotated(Widget zone, int quarterTurns) {
    final padded = Padding(padding: const EdgeInsets.all(2), child: zone);
    if (quarterTurns % 4 == 0) return padded;
    return RotatedBox(quarterTurns: quarterTurns, child: padded);
  }

  static Widget _column(List<Widget> zones) {
    return Column(
      children: [for (final zone in zones) Expanded(child: zone)],
    );
  }

  static Widget _half(List<Widget> zones, {required bool useSubGrid}) {
    if (zones.isEmpty) return const SizedBox.shrink();

    if (useSubGrid && zones.length == 4) {
      return Column(
        children: [
          Expanded(child: Row(children: [
            for (int i = 0; i < 2; i++) Expanded(child: zones[i]),
          ])),
          Expanded(child: Row(children: [
            for (int i = 2; i < 4; i++) Expanded(child: zones[i]),
          ])),
        ],
      );
    }

    return Row(children: [for (final zone in zones) Expanded(child: zone)]);
  }
}
```

- [ ] **Step 4: Lancer la suite complète**

Run: `flutter test`
Expected: PASS. Si `life_counter_page` a des tests qui dépendent de la structure de la grille, les lire avant de les modifier : ils peuvent signaler une vraie régression.

- [ ] **Step 5: Vérifier que les tests discriminent**

Dans `seatsFor`, remplacer temporairement le cas `2` par `[TableSide.bottom, TableSide.top]` (joueurs inversés). Relancer le test de la grille : `2 joueurs` **doit** échouer. Rétablir.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/layouts/adaptive_grid.dart test/widgets/life_counter/layouts/adaptive_grid_test.dart
git commit -m "refactor: drive AdaptiveGrid from seatsFor instead of a hardcoded rule"
```

---

## Task 3 : Les sièges latéraux, et la rotation initiale posée à la création de partie

C'est la tâche où le changement devient visible pour le joueur.

**Files:**
- Modify: `lib/models/game_session.dart` (factory `newGame`, ~ligne 147)
- Test: `test/widgets/life_counter/layouts/adaptive_grid_test.dart` (tests ajoutés)
- Test: `test/models/game_session_test.dart` (tests ajoutés — créer le groupe s'il n'existe pas)

**Interfaces:**
- Consumes: `seatsFor`, `TableSeat.quarterTurns` (tâche 1), `AdaptiveGrid` (tâche 2).
- Produces: `GameSession.newGame` pose `PlayerState.quarterTurns` depuis `seatsFor`.

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter au groupe `AdaptiveGrid` de `test/widgets/life_counter/layouts/adaptive_grid_test.dart` :

```dart
  group('AdaptiveGrid — sieges lateraux', () {
    testWidgets('4 joueurs : un par cote, rotations 2/3/0/1', (tester) async {
      await tester.pumpWidget(_grid(4));
      expect(_quarterTurnsOf(tester, 0), 2, reason: 'haut');
      expect(_quarterTurnsOf(tester, 1), 3, reason: 'droite');
      expect(_quarterTurnsOf(tester, 2), 0, reason: 'bas');
      expect(_quarterTurnsOf(tester, 3), 1, reason: 'gauche');
    });

    testWidgets('4 joueurs : gauche et droite encadrent le centre',
        (tester) async {
      await tester.pumpWidget(_grid(4));
      final gauche = _centerOf(tester, 3).dx;
      final droite = _centerOf(tester, 1).dx;
      final haut = _centerOf(tester, 0).dx;
      expect(gauche, lessThan(haut));
      expect(droite, greaterThan(haut));
    });

    testWidgets('4 joueurs : haut et bas encadrent verticalement',
        (tester) async {
      await tester.pumpWidget(_grid(4));
      expect(_centerOf(tester, 0).dy, lessThan(_centerOf(tester, 2).dy));
    });

    testWidgets('6 joueurs : deux en haut, deux en bas, un de chaque cote',
        (tester) async {
      await tester.pumpWidget(_grid(6));
      expect(_centerOf(tester, 0).dy, equals(_centerOf(tester, 1).dy));
      expect(_centerOf(tester, 3).dy, equals(_centerOf(tester, 4).dy));
      expect(_quarterTurnsOf(tester, 2), 3, reason: 'droite');
      expect(_quarterTurnsOf(tester, 5), 1, reason: 'gauche');
    });

    testWidgets('8 joueurs : aucune colonne laterale', (tester) async {
      await tester.pumpWidget(_grid(8));
      for (int i = 0; i < 8; i++) {
        expect(_quarterTurnsOf(tester, i), anyOf(0, 2), reason: 'joueur $i');
      }
    });
  });
```

Ajouter dans `test/models/game_session_test.dart` un groupe `GameSession.newGame — rotations initiales`, décrit par ses assertions :

**Signature réelle, vérifiée** (`lib/models/game_session.dart:139`) :

```dart
factory GameSession.newGame({
  required GameFormat format,
  required List<PlayerConfig> playerConfigs,
  List<String>? extraCounterIds,
  String? tag,
})
```

Elle prend **`playerConfigs`, pas `playerCount`**. Construire les configs avec un helper local du fichier de test — regarder d'abord si `game_session_test.dart` en a déjà un, et le réutiliser plutôt que d'en écrire un second. `PlayerConfig` exige `id`, `name`, `type` et `colorValue` (`lib/models/player_config.dart:38`).

Trois tests :

1. **4 joueurs → `[2, 3, 0, 1]`.** Assertion sur `session.players.map((p) => p.quarterTurns).toList()`. C'est le test qui porte tout le lot : haut, droite, bas, gauche.
2. **2 joueurs → `[2, 0]`.** Le face-à-face historique est préservé.
3. **8 joueurs → aucune rotation latérale.** Chaque `quarterTurns` vaut 0 ou 2.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/layouts/adaptive_grid_test.dart test/models/game_session_test.dart`
Expected: FAIL — les rotations valent toutes 0 côté session, et les sièges latéraux ne sont pas encore posés côté grille si la tâche 2 est incomplète.

- [ ] **Step 3: Poser la rotation initiale**

Dans `lib/models/game_session.dart`, importer `table_seat.dart` et, dans la factory `newGame`, au moment où chaque `PlayerState` est construit, lire le siège correspondant :

```dart
    final seats = seatsFor(playerCount);
    // ... dans la generation des PlayerState, a l'index i :
    //     quarterTurns: seats[i].quarterTurns,
```

La rotation ainsi posée est un **défaut** : `updateRotation` (`lib/providers/game_session_notifier.dart:122`) continue de la remplacer, et la valeur du joueur est persistée. Ne rien changer à ce chemin.

- [ ] **Step 4: Lancer la suite complète**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Vérifier le tap sous rotation — le test que ce lot existe pour écrire**

Contrainte globale 2, et spec lot 6 §6.1. Ajouter à `test/widgets/life_counter/player_zone_test.dart` un test qui, pour chacune des quatre orientations, **joue** un tap sur la moitié « décrément » telle que le joueur la voit, et vérifie que le delta est négatif.

Le point clé : la position du tap doit être calculée dans le repère du joueur, puis transformée, et non prise au centre-gauche du rectangle écran. S'inspirer de la façon dont `life_dial_test.dart` localise ses moitiés, et **vérifier la discrimination** en inversant temporairement les deux moitiés dans `LifeDial` : le test doit échouer pour au moins deux orientations. S'il passe toujours, il ne teste rien — le réécrire.

- [ ] **Step 6: Commit**

```bash
git add lib/models/game_session.dart test/models/game_session_test.dart test/widgets/life_counter/layouts/adaptive_grid_test.dart test/widgets/life_counter/player_zone_test.dart
git commit -m "feat: seat players around all four sides at 4-6 players"
```

---

## Task 4 : `tierFor` et le contrat de densité

**Files:**
- Create: `lib/widgets/life_counter/layouts/density_tier.dart`
- Test: `test/widgets/life_counter/layouts/density_tier_test.dart`
- Modify: `lib/widgets/life_counter/zone/conditional_handle.dart`
- Test: `test/widgets/life_counter/zone/conditional_handle_test.dart` (ajout, existants intacts)
- Modify: `lib/widgets/life_counter/player_zone.dart`

**Interfaces:**
- Consumes: rien des tâches précédentes.
- Produces:
  - `enum DensityTier { comfort, compact, minimal }`
  - `DensityTier tierFor(Size sizeInPlayerFrame)`
  - `double handleHeightFor(DensityTier tier)`
  - `ConditionalHandle({required CounterSummary summary, VoidCallback? onTap, DensityTier tier = DensityTier.compact})`

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/widgets/life_counter/layouts/density_tier_test.dart` :

```dart
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
```

Ajouter à `test/widgets/life_counter/zone/conditional_handle_test.dart` — **sans toucher aux tests existants**, en particulier celui qui verrouille l'égalité des hauteurs calme/alerte :

```dart
  group('ConditionalHandle — densite', () {
    testWidgets('la hauteur suit le cran, jamais l etat des compteurs',
        (tester) async {
      Future<double> heightFor(DensityTier tier, CounterSummary summary) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ConditionalHandle(summary: summary, tier: tier),
          ),
        ));
        return tester.getSize(find.byType(ConditionalHandle)).height;
      }

      const calme = CounterSummary();
      const alerte = CounterSummary(poison: 3);

      expect(await heightFor(DensityTier.comfort, calme), 48.0);
      expect(await heightFor(DensityTier.comfort, alerte), 48.0);
      expect(await heightFor(DensityTier.minimal, calme), 30.0);
      expect(await heightFor(DensityTier.minimal, alerte), 30.0);
    });

    testWidgets('en cran minimal la poignee est muette mais tapable',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConditionalHandle(
            summary: const CounterSummary(poison: 3, energy: 2),
            tier: DensityTier.minimal,
            onTap: () => taps++,
          ),
        ),
      ));

      // Aucun chiffre de compteur affiche.
      expect(find.textContaining('3'), findsNothing);
      expect(find.textContaining('2'), findsNothing);

      // Mais la cible repond a un VRAI tap (contrainte globale 2).
      await tester.tap(find.byType(ConditionalHandle));
      await tester.pump();
      expect(taps, 1);
    });
  });
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/layouts/density_tier_test.dart test/widgets/life_counter/zone/conditional_handle_test.dart`
Expected: FAIL — `density_tier.dart` n'existe pas, `ConditionalHandle` n'accepte pas `tier`.

- [ ] **Step 3: Écrire la densité**

Créer `lib/widgets/life_counter/layouts/density_tier.dart` :

```dart
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
```

Modifier `ConditionalHandle` : ajouter le champ `final DensityTier tier;` (défaut `DensityTier.compact`), remplacer `SizedBox(height: reservedHeight)` par `SizedBox(height: handleHeightFor(tier))`, et rendre `_band()` **muet** en cran minimal (afficher `_grip()` quel que soit `summary.isCalm`). Conserver `reservedHeight = 30.0` comme constante — d'autres fichiers la lisent — en documentant qu'elle est désormais le plancher et non la valeur unique.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/layouts/ test/widgets/life_counter/zone/`
Expected: PASS, **y compris les tests existants de `conditional_handle_test.dart`** qui verrouillent l'égalité calme/alerte.

- [ ] **Step 5: Brancher `PlayerZone` sur son cran**

Dans `player_zone.dart`, envelopper le corps de la zone dans un `LayoutBuilder`, calculer la taille dans le repère du joueur (transposer largeur et hauteur quand `widget.quarterTurns.isOdd`), appeler `tierFor`, et passer le cran à `ConditionalHandle`. Le cran est calculé dans `build` à partir des contraintes reçues : il ne bouge donc qu'à un changement de taille ou de rotation, jamais quand un compteur change — ce que le test de l'étape 1 verrouille déjà côté poignée.

En cran minimal, réduire le nom à la pastille de couleur (spec §3.2) en n'affichant pas le libellé du `PlayerHeader`.

- [ ] **Step 6: Lancer la suite complète**

Run: `flutter test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/life_counter/layouts/density_tier.dart lib/widgets/life_counter/zone/conditional_handle.dart lib/widgets/life_counter/player_zone.dart test/widgets/life_counter/layouts/density_tier_test.dart test/widgets/life_counter/zone/conditional_handle_test.dart
git commit -m "feat: add the density tier contract, never shrinking the drawer handle"
```

---

## Task 5 : La couche d'alerte, et la pile de composition non-absorbante

C'est la tâche qui applique directement la leçon du lot 2 : `EliminationOverlay` absorbait tous les gestes d'une zone éliminée, invisible pendant tout le cycle V3.

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart` (`_buildPlayerZoneWithOverlays`, ~ligne 928)
- Test: `test/widgets/life_counter/critical_overlay_test.dart` (ajout)

**Interfaces:**
- Consumes: `DensityTier`, `tierFor` (tâche 4).
- Produces: rien de nouveau.

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter à `test/widgets/life_counter/critical_overlay_test.dart` un groupe `CriticalOverlay — non absorbant`, décrit par ses assertions.

**Signature réelle, vérifiée** (`lib/widgets/life_counter/critical_overlay.dart:15`) : `CriticalOverlay({required CriticalLevel level, required Widget child})`. **`level` est un `enum CriticalLevel { safe, warning, danger, lethal }`** (`animation_service.dart:12`), pas un `int` — passer `CriticalLevel.danger`, jamais `2`.

Un seul test, mais c'est le test qui compte :

- Monter un `CriticalOverlay` à `CriticalLevel.danger` autour d'un enfant qui compte ses taps.
- **Jouer un vrai `tester.tap`** sur l'enfant — jamais appeler son callback (contrainte globale 2).
- Attendre exactement **un** tap reçu.
- `reason:` mentionnant qu'il s'agit du même motif qu'`EliminationOverlay` au lot 2 : une couche qui avale les gestes de celle en dessous.

Le calcul du niveau se lit dans `AnimationService.getCriticalLevel({required int currentLife, required int startingLife})`, qui ne regarde aujourd'hui **que la vie** — voir l'étape 4.

- [ ] **Step 2: Lancer le test**

Run: `flutter test test/widgets/life_counter/critical_overlay_test.dart`
Expected: à déterminer. Si le test **passe du premier coup**, la couche est déjà non-absorbante : le noter et passer à l'étape 4 sans modifier le widget. Ne pas « corriger » un widget sain.

- [ ] **Step 3: Rendre la couche non-absorbante si nécessaire**

Envelopper la décoration dans `IgnorePointer`, comme le lot 2 l'a fait pour les trois couches d'`EliminationOverlay`. Ne jamais démonter conditionnellement l'enfant — c'est la solution qui avait été écartée au lot 2.

- [ ] **Step 4: La couche d'alerte perce en cran minimal**

Dans `_buildPlayerZoneWithOverlays`, vérifier que `CriticalOverlay` est appliqué **quel que soit le cran** de la zone. Spec §3.3 : vie ≤ 5, poison ≥ `maxPoison − 2`, ou 18+ dégâts de commandant d'une même source. C'est la seule chose autorisée à percer en cran minimal.

**Vérifié : `AnimationService.getCriticalLevel` ne couvre aujourd'hui que la vie** — elle prend `currentLife` et `startingLife` et retourne un `CriticalLevel` sur le ratio (`≤ 0.10` → `lethal`, `≤ 0.25` → `danger`, `≤ 0.50` → `warning`). L'étendre au poison et au commander damage demande donc de **changer sa signature**, ce qui touche tous ses appelants.

Deux options, à trancher à l'exécution plutôt qu'ici : ajouter des paramètres optionnels nommés (`poison`, `maxPoison`, `worstCommanderDamage`) avec des défauts qui préservent le comportement actuel, ou laisser la fonction intacte et calculer le niveau d'alerte étendu dans la page. La première garde le calcul en un seul endroit ; la seconde ne touche à aucun appelant. Un test par condition dans les deux cas : vie ≤ 5, poison ≥ `maxPoison − 2`, commander damage ≥ 18 d'une même source.

- [ ] **Step 5: Lancer la suite complète**

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/pages/life_counter/life_counter_page.dart test/widgets/life_counter/critical_overlay_test.dart
git commit -m "feat: let the alert layer pierce every density tier, verified non-absorbing"
```

---

## Task 6 : Le badge de dégâts en attente pivote avec sa zone

Constat reporté au lot 3 : le badge est rendu **hors** du `RotatedBox`, donc il ne pivote pas. Aujourd'hui peu visible parce que les rotations non nulles sont rares ; ce lot les rend systématiques sur deux sièges sur quatre à 4-6 joueurs.

**Files:**
- Modify: `lib/widgets/life_counter/player_zone.dart`
- Test: `test/widgets/life_counter/player_zone_test.dart`

**Interfaces:**
- Consumes: la géométrie des tâches 1-3.
- Produces: rien de nouveau.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
  testWidgets('le badge de degats en attente pivote avec sa zone',
      (tester) async {
    // Monter une zone a quarterTurns: 1 avec un delta en attente, puis
    // verifier que le badge est rendu SOUS la meme RotatedBox que le chiffre
    // de PV — pas a cote d'elle.
    // (Adapter le montage au helper de montage deja present dans ce fichier.)
    final badge = find.byKey(const ValueKey('pending_damage_badge'));
    expect(badge, findsOneWidget);

    final rotatedAncestors = find.ancestor(
      of: badge,
      matching: find.byType(RotatedBox),
    );
    expect(rotatedAncestors, findsWidgets,
        reason: 'le badge doit vivre dans le repere de la zone');
  });
```

> Si le badge n'a pas encore de `Key`, lui en donner une (`ValueKey('pending_damage_badge')`) dans le même commit : un test qui localise un widget par son texte casserait au premier changement de libellé.

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/widgets/life_counter/player_zone_test.dart`
Expected: FAIL — le badge n'a pas d'ancêtre `RotatedBox`.

- [ ] **Step 3: Déplacer le badge dans le repère de la zone**

Le rendre dans le `Stack` interne de la zone, sous la même rotation que le chiffre de PV, plutôt qu'au-dessus de la zone dans la page.

- [ ] **Step 4: Lancer la suite complète**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Vérifier que le test discrimine**

Remettre temporairement le badge hors du `RotatedBox`, relancer, vérifier l'échec, rétablir.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/player_zone.dart test/widgets/life_counter/player_zone_test.dart
git commit -m "fix: render the pending damage badge inside the zone's rotated frame"
```

---

## Critères de sortie du lot

Les tests ne suffisent pas ici, et c'est écrit dans la spec §6.1 plutôt que découvert en revue.

- [ ] `flutter test` vert, `flutter analyze` sans erreur ni avertissement.
- [ ] **Vérification sur appareil réel, à 4 joueurs**, appareil posé à plat :
  - depuis chaque siège, le chiffre de PV se lit à l'endroit ;
  - depuis chaque siège, la moitié gauche décrémente et la moitié droite incrémente **telles que ce joueur les voit** ;
  - la poignée s'atteint au doigt aux quatre orientations, et ouvre le tiroir ;
  - le badge de dégâts en attente apparaît à l'endroit sur les deux sièges latéraux.
- [ ] **Vérification sur appareil réel, à 8 joueurs sur petit écran** : le cran minimal reste lisible, et la poignée reste atteignable.
- [ ] Les quatre points à calibrer de la spec §7 sont tranchés ou explicitement reportés : seuils en pixels des crans, lisibilité d'un siège latéral en minimal, découverte du tiroir en minimal.
- [ ] **Le réordonnancement par glisser-déposer est vérifié aux quatre orientations, sur appareil.** Report hérité du lot 3 : l'aperçu de glissement fige la zone à 130 px, ce qui rend le vrai geste intestable en widget test. La revue du lot 3 avertit que sans rappel explicite ce report devient permanent — d'où sa présence ici, en critère de sortie et non en constat reporté. Ce lot le rend d'autant plus visible qu'il place des zones sur quatre côtés : un glissement depuis un siège latéral traverse une rotation.

---

## Self-Review

**Couverture de la spec :**

| Section de la spec | Tâche |
|---|---|
| §2.1 séparation position/rotation | 1, 2 |
| §2.2 carte des sièges | 1 |
| §2.3 sièges latéraux, retour face-à-face au-delà de 6, défaut non contraignant | 1, 3 |
| §2.4 branchement sur l'existant, `_calculateDefaultRotation` | 3 (déjà supprimée — voir Écarts) |
| §3.1 cran sur taille mesurée, repère du joueur | 4 |
| §3.2 les trois crans | 4 |
| §3.3 couche d'alerte hors crans | 5 |
| §3.4 cran figé en cours de partie | 4 (étape 5) |
| §3.5 poignée jamais rétrécie, plancher de hauteur | 4 |
| §5.1.1 partir de la surface de gestes corrigée | Contraintes globales |
| §6 tests | toutes |
| §6.1 tap sous rotation, appareil réel | 3 (étape 5), Critères de sortie |
| §6.2 les trois façons dont un test ment | Contraintes globales 2-4 |
| §5.2 tâche 6, badge hors `RotatedBox` | 6 |
| §8 aucun geste global | Contrainte globale 5 |

**Deux endroits où ce plan demande de lire avant d'écrire** plutôt que de prescrire un code exact, et c'est délibéré : la signature de `GameSession.newGame` (tâche 3) et celle de `CriticalOverlay` (tâche 5). Les inventer produirait du code qui ne compile pas — c'est l'erreur que les plans des lots 1 et 2 ont commise quatre fois.

**Cohérence des types :** `DensityTier` et `tierFor` sont définis en tâche 4 et utilisés en tâches 4 et 5. `TableSeat`, `TableSide`, `seatsFor` sont définis en tâche 1 et utilisés en 2 et 3. `handleHeightFor` est défini et consommé en tâche 4. `kZoneHeightFloor` est défini en tâche 4 ; il est documentaire tant que `tierFor` garantit le plancher par ses seuils.
