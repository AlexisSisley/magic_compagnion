# Life counter — table multijoueur v2, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire lire à chaque joueur son compteur à l'endroit depuis sa chaise, sans jamais sacrifier l'accès aux actions ni la lisibilité des zones.

**Architecture:** Une fonction pure `tableLayoutFor(Size, int)` décide **seule** de la disposition (colonnes latérales ou non, largeur, forme de la barre). `AdaptiveGrid` ne fait que placer ce qu'elle lui dit, sans jamais pivoter quoi que ce soit. `PlayerZone` reste l'unique propriétaire de la rotation. Le mode d'ajustement devient un geste continu au lieu d'un mode persistant.

**Tech Stack:** Flutter / Dart, Riverpod 3, `flutter_test`, `fake_async`.

**Spec:** `docs/superpowers/specs/2026-09-17-life-counter-table-multijoueur-v2-design.md`

**Maquette de référence :** https://claude.ai/artifact/UvvoPP5qqB3fF79F9Q81XD

**Branche de départ :** `main` (après le revert du lot 6, commit `6e147c7`).
**Source de récupération :** branche `lot6-archive` (`09e16c7`) — voir §10 de la spec.

## Global Constraints

- **La rotation n'a qu'un seul propriétaire :** `PlayerZone`, via `RotatedBox` à `player_zone.dart:413`. `AdaptiveGrid` ne contient **aucune** `RotatedBox`. Un test verrouille cette absence.
- **Convention de rotation :** `RotatedBox` tourne dans le sens **horaire**. Moitié « décrément » : à 0 → `dx` inférieur ; à 1 → `dy` **inférieur** ; à 2 → `dx` supérieur ; à 3 → `dy` **supérieur**.
- **`kZoneShortEdgeFloor = 70.0`**, **dérivé** de `kZoneHeaderHeight (40.0) + kZoneHandleHeight (30.0)`, jamais recopié.
- **On renonce, on ne rétrécit pas :** si une colonne latérale n'est pas payable en entier, il n'y en a aucune et la table repasse en face-à-face strict.
- **La barre d'actions est servie en premier.** Elle ne défile jamais horizontalement pour cacher une action.
- **La poignée du tiroir ne descend jamais sous 30 px** et reste le seul point d'entrée du tiroir.
- **Repérage des tests :** par `ValueKey` quand le test porte sur un **comportement** ; par **géométrie** quand la propriété testée **EST** la disposition.
- **Aucune fixture ne part d'un `playerOrder` identité** quand le test porte sur l'ordre.
- **Chaque test ajouté est vérifié discriminant** : une mutation nommée du code de production le fait échouer, puis est restaurée, et `git status --short` est vide avant le commit.

---

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/models/table_seat.dart` | **Créer.** Géométrie des sièges : qui est assis où, et quelle rotation en découle. | T1 |
| `lib/widgets/life_counter/layouts/density_tier.dart` | **Créer.** Contrat de densité et plancher dérivé du petit côté d'une zone. | T2 |
| `lib/widgets/life_counter/layouts/table_layout.dart` | **Créer.** Décision de disposition, fonction pure. Le cœur de cette refonte. | T3 |
| `lib/widgets/life_counter/layouts/adaptive_grid.dart` | **Réécrire.** Placement pur, piloté par T3. Aucune rotation. | T4 |
| `lib/pages/life_counter/life_counter_page.dart` | **Modifier.** Attribution des rotations de siège, réordonnancement, barre d'actions. | T5, T6 |
| `lib/models/game_session.dart` | **Modifier.** Marqueur de migration `rotationsMigrated`. | T5 |
| `lib/widgets/life_counter/zone/action_hub.dart` | **Créer.** Bouton rond + feuille des huit actions. | T6 |
| `lib/widgets/life_counter/zone/life_dial.dart` | **Modifier.** Rangée resserrée, geste continu glissé-relâché. | T7 |

---

## Task 1: Modèle de sièges

**Files:**
- Create: `lib/models/table_seat.dart`
- Test: `test/models/table_seat_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `enum TableSide { top, right, bottom, left }` ; `class TableSeat` avec `final TableSide side`, `final int slot`, `final int slotCount`, `int get quarterTurns` ; `List<TableSeat> seatsFor(int playerCount, {bool allowSideColumns = true})`.

Le paramètre `allowSideColumns` est ce qui permet à T3 d'imposer le repli face-à-face sans dupliquer la géométrie ailleurs.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
// test/models/table_seat_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';

void main() {
  test('2 joueurs : face à face', () {
    expect(seatsFor(2).map((s) => s.side).toList(),
        [TableSide.bottom, TableSide.top]);
  });

  test('4 joueurs : un siège par côté', () {
    expect(seatsFor(4).map((s) => s.side).toList(),
        [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left]);
  });

  test('4 joueurs : les rotations suivent les sièges', () {
    expect(seatsFor(4).map((s) => s.quarterTurns).toList(), [2, 3, 0, 1]);
  });

  test('5 joueurs : deux en haut, un par côté, un en bas', () {
    expect(seatsFor(5).map((s) => s.side).toList(), [
      TableSide.top, TableSide.top, TableSide.right,
      TableSide.bottom, TableSide.left,
    ]);
  });

  test('6 joueurs : deux en haut, deux en bas, un par côté', () {
    expect(seatsFor(6).map((s) => s.side).toList(), [
      TableSide.top, TableSide.top, TableSide.right,
      TableSide.bottom, TableSide.bottom, TableSide.left,
    ]);
  });

  test('7 joueurs : repli face à face, aucun siège latéral', () {
    final sides = seatsFor(7).map((s) => s.side).toSet();
    expect(sides.contains(TableSide.left), isFalse);
    expect(sides.contains(TableSide.right), isFalse);
  });

  test('allowSideColumns: false force le face à face même à 4 joueurs', () {
    expect(seatsFor(4, allowSideColumns: false).map((s) => s.side).toList(),
        [TableSide.top, TableSide.top, TableSide.bottom, TableSide.bottom]);
  });

  test('le repli met le joueur surnuméraire en bas, du côté utilisateur', () {
    expect(seatsFor(5, allowSideColumns: false).map((s) => s.side).toList(), [
      TableSide.top, TableSide.top,
      TableSide.bottom, TableSide.bottom, TableSide.bottom,
    ]);
  });

  test('les slots d\'un même côté sont numérotés de 0 à slotCount-1', () {
    final tops = seatsFor(6).where((s) => s.side == TableSide.top).toList();
    expect(tops.map((s) => s.slot).toList(), [0, 1]);
    expect(tops.every((s) => s.slotCount == 2), isTrue);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/models/table_seat_test.dart`
Attendu : ÉCHEC, `Error: Couldn't resolve the package 'magic_companion/models/table_seat.dart'`.

- [ ] **Step 3: Écrire l'implémentation**

```dart
// lib/models/table_seat.dart

/// Côté de la table où un joueur est assis, l'appareil étant posé à plat.
enum TableSide { top, right, bottom, left }

/// Siège d'un joueur : son côté, et sa place parmi ceux qui partagent ce côté.
class TableSeat {
  const TableSeat({
    required this.side,
    required this.slot,
    required this.slotCount,
  });

  final TableSide side;
  final int slot;
  final int slotCount;

  /// Rotation à appliquer pour que ce joueur lise à l'endroit depuis sa chaise.
  ///
  /// `RotatedBox` tourne dans le sens HORAIRE : un quart de tour envoie le bord
  /// gauche de l'enfant sur le bord haut de l'écran. Un joueur assis à gauche
  /// regarde vers la droite, sa main gauche pointe donc vers le haut de
  /// l'écran — d'où `left => 1`.
  int get quarterTurns => switch (side) {
        TableSide.bottom => 0,
        TableSide.left => 1,
        TableSide.top => 2,
        TableSide.right => 3,
      };
}

/// Répartition des joueurs autour de la table.
///
/// [allowSideColumns] à `false` impose le repli face-à-face : c'est ainsi que
/// `tableLayoutFor` applique la règle d'abordabilité (spec §3.3) sans que la
/// géométrie soit dupliquée hors de ce fichier.
List<TableSeat> seatsFor(int playerCount, {bool allowSideColumns = true}) {
  if (!allowSideColumns || playerCount <= 3 || playerCount > 6) {
    return _faceToFace(playerCount);
  }
  final sides = switch (playerCount) {
    4 => [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left],
    5 => [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.left,
      ],
    _ => [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.bottom, TableSide.left,
      ],
  };
  return _withSlots(sides);
}

/// Moitié haute pivotée à 180°, moitié basse à l'endroit. Le joueur
/// surnuméraire va en bas, du côté de celui qui tient l'appareil.
List<TableSeat> _faceToFace(int playerCount) {
  final topCount = playerCount ~/ 2;
  return _withSlots([
    for (int i = 0; i < playerCount; i++)
      i < topCount ? TableSide.top : TableSide.bottom,
  ]);
}

List<TableSeat> _withSlots(List<TableSide> sides) {
  final counts = <TableSide, int>{};
  for (final side in sides) {
    counts[side] = (counts[side] ?? 0) + 1;
  }
  final used = <TableSide, int>{};
  return [
    for (final side in sides)
      TableSeat(
        side: side,
        slot: used[side] = (used[side] ?? -1) + 1,
        slotCount: counts[side]!,
      ),
  ];
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/models/table_seat_test.dart`
Attendu : 9 tests PASS.

- [ ] **Step 5: Vérifier la discrimination**

Inverser `TableSide.left => 1` et `TableSide.right => 3` dans `quarterTurns`, relancer : le test « les rotations suivent les sièges » doit ÉCHOUER. Restaurer avec `git checkout -- lib/models/table_seat.dart` et vérifier que `git status --short` ne montre plus ce fichier.

- [ ] **Step 6: Commit**

```bash
git add lib/models/table_seat.dart test/models/table_seat_test.dart
git commit -m "feat: add the table seating geometry, with its face-to-face fallback"
```

---

## Task 2: Contrat de densité

**Files:**
- Create: `lib/widgets/life_counter/layouts/density_tier.dart`
- Test: `test/widgets/life_counter/layouts/density_tier_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `enum DensityTier { comfort, compact, minimal }` ; `const double kZoneHeaderHeight = 40.0` ; `const double kZoneHandleHeight = 30.0` ; `const double kZoneShortEdgeFloor` ; `DensityTier tierFor(Size sizeInPlayerFrame)` ; `double handleHeightFor(DensityTier tier)`.

`Size sizeInPlayerFrame` est la taille de la zone **dans son propre repère**, après rotation : pour un siège latéral, sa largeur est la largeur de la colonne.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
// test/widgets/life_counter/layouts/density_tier_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';

void main() {
  test('le plancher est DÉRIVÉ de l\'en-tête et de la poignée, pas recopié', () {
    expect(kZoneShortEdgeFloor, kZoneHeaderHeight + kZoneHandleHeight);
  });

  test('le plancher vaut 70 px avec les valeurs actuelles', () {
    expect(kZoneShortEdgeFloor, 70.0);
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
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/layouts/density_tier_test.dart`
Attendu : ÉCHEC à la résolution du paquet.

- [ ] **Step 3: Écrire l'implémentation**

```dart
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
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/widgets/life_counter/layouts/density_tier_test.dart`
Attendu : 7 tests PASS.

- [ ] **Step 5: Vérifier la discrimination**

Porter `kZoneHeaderHeight` à `50.0`, relancer : le test « le plancher vaut 70 px » doit ÉCHOUER et celui de la dérivation doit RESTER VERT — c'est ce couple qui prouve que la valeur est dérivée et non recopiée. Restaurer, vérifier `git status --short` vide.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/layouts/density_tier.dart test/widgets/life_counter/layouts/density_tier_test.dart
git commit -m "feat: add the density contract with a derived short-edge floor"
```

---

## Task 3: Décision de disposition — le cœur

**Files:**
- Create: `lib/widgets/life_counter/layouts/table_layout.dart`
- Test: `test/widgets/life_counter/layouts/table_layout_test.dart`

**Interfaces:**
- Consumes: `seatsFor(int, {bool allowSideColumns})` et `TableSide` (T1) ; `kZoneShortEdgeFloor` (T2).
- Produces: `enum ActionBarKind { hub, band }` ; `class TableLayout` avec `final bool useSideColumns`, `final double sideWidth`, `final ActionBarKind barKind`, `final List<TableSeat> seats` ; `TableLayout tableLayoutFor(Size size, int playerCount)` ; les constantes `kSideColumnNeed`, `kBandNeed`, `kHubNeed`, `kLargeScreenShortEdge`.

C'est la tâche qui corrige le défaut du lot 6. Elle est **pure** : aucune dépendance à Flutter au-delà de `Size`, donc elle se teste sans monter le moindre widget.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
// test/widgets/life_counter/layouts/table_layout_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';
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
      for (final size in [phoneLandscape, tabletPortrait, tabletLandscape]) {
        for (int n = 2; n <= 8; n++) {
          final layout = tableLayoutFor(size, n);
          if (layout.useSideColumns) {
            expect(layout.sideWidth,
                greaterThanOrEqualTo(kZoneShortEdgeFloor),
                reason: '$size à $n joueurs');
          }
        }
      }
    });

    test('un écran trop étroit pour le budget renonce aux côtés', () {
      // 320 de large : 2 x 96 = 192, il resterait 128 au centre, sous les 160
      // dont le hub a besoin.
      expect(tableLayoutFor(const Size(320, 700), 4).useSideColumns, isFalse);
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
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/layouts/table_layout_test.dart`
Attendu : ÉCHEC à la résolution du paquet.

- [ ] **Step 3: Écrire l'implémentation**

```dart
// lib/widgets/life_counter/layouts/table_layout.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';

/// Forme que prend l'accès aux actions de partie.
enum ActionBarKind {
  /// Bouton rond au centre de la table, qui ouvre une feuille. Petit écran.
  hub,

  /// Bande horizontale entre les deux moitiés. Grand écran.
  band,
}

/// Largeur minimale d'une colonne latérale : le plancher de la zone, plus une
/// marge de respiration sans laquelle la colonne est techniquement conforme et
/// visuellement inutilisable.
const double kSideColumnNeed = kZoneShortEdgeFloor + 26.0;

const int kActionCount = 8;
const double kActionWidth = 36.0;
const double kActionGap = 4.0;

/// Largeur naturelle de la bande d'actions : les huit actions, sans défilement.
const double kBandNeed = kActionCount * (kActionWidth + kActionGap) + kActionGap;

/// Place réservée au centre pour le hub et son pourtour tapable.
const double kHubNeed = 160.0;

/// Petit côté à partir duquel un écran est considéré comme grand.
const double kLargeScreenShortEdge = 600.0;

/// Décision de disposition pour un écran et un nombre de joueurs donnés.
class TableLayout {
  const TableLayout({
    required this.useSideColumns,
    required this.sideWidth,
    required this.barKind,
    required this.seats,
  });

  final bool useSideColumns;
  final double sideWidth;
  final ActionBarKind barKind;

  /// Sièges effectivement retenus. En cas de repli, ce sont ceux du
  /// face-à-face : le reste du code n'a pas à connaître la règle.
  final List<TableSeat> seats;
}

/// Décide de la disposition (spec §3 et §4).
///
/// Le défaut que cette fonction existe pour empêcher : le lot 6 donnait 30 % de
/// la largeur à chaque colonne latérale, quoi qu'il arrive. Sur un écran large,
/// deux joueurs mangeaient 60 % de la surface et la barre d'actions n'avait plus
/// de place — elle se réduisait silencieusement à ses deux premières icônes.
///
/// Ici, une colonne latérale doit être payée EN ENTIER, sur deux critères
/// indépendants, et à défaut il n'y en a aucune.
TableLayout tableLayoutFor(Size size, int playerCount) {
  final shortEdge = math.min(size.width, size.height);
  final barKind = shortEdge < kLargeScreenShortEdge
      ? ActionBarKind.hub
      : ActionBarKind.band;

  TableLayout fallback() => TableLayout(
        useSideColumns: false,
        sideWidth: 0.0,
        barKind: barKind,
        seats: seatsFor(playerCount, allowSideColumns: false),
      );

  final wanted = seatsFor(playerCount);
  final wantsSides = wanted.any(
      (s) => s.side == TableSide.left || s.side == TableSide.right);
  if (!wantsSides) return fallback();

  // Condition de forme : paysage, ou grand écran. Sur un téléphone en
  // portrait, une colonne latérale donne une bande verticale trop étroite pour
  // être lisible même quand elle passe le plancher numérique.
  final shapeAllows =
      size.width > size.height || shortEdge >= kLargeScreenShortEdge;
  if (!shapeAllows) return fallback();

  // Condition de budget : le centre garde d'abord de quoi loger les actions.
  final centreNeed = barKind == ActionBarKind.band ? kBandNeed : kHubNeed;
  if (size.width - 2 * kSideColumnNeed < centreNeed) return fallback();

  // 0.17 est un réglage esthétique pour les grands écrans, JAMAIS la garantie
  // du plancher : celle-ci est portée par le `math.max` ci-dessous, en dur.
  final sideWidth = math.max(
    kSideColumnNeed,
    math.min(size.width * 0.17, (size.width - centreNeed) / 2),
  );

  return TableLayout(
    useSideColumns: true,
    sideWidth: sideWidth,
    barKind: barKind,
    seats: wanted,
  );
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/widgets/life_counter/layouts/table_layout_test.dart`
Attendu : 12 tests PASS.

- [ ] **Step 5: Vérifier la discrimination — trois mutations**

1. Remplacer le corps de la condition de forme par `final shapeAllows = true;` → le test « téléphone en portrait : PAS de colonne latérale » doit ÉCHOUER.
2. Remplacer le `math.max(kSideColumnNeed, ...)` par son seul `math.min(...)` → le test « une colonne rendue n'est JAMAIS sous le plancher » doit ÉCHOUER.
3. Porter `kLargeScreenShortEdge` à `300.0` → les tests de forme de barre sur téléphone doivent ÉCHOUER.

Restaurer après chaque mutation, et vérifier `git status --short` vide avant de commiter.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/layouts/table_layout.dart test/widgets/life_counter/layouts/table_layout_test.dart
git commit -m "feat: decide the table layout by affordability, never by a fixed fraction"
```

---

## Task 4: AdaptiveGrid purement positionnelle

**Files:**
- Modify: `lib/widgets/life_counter/layouts/adaptive_grid.dart` (réécriture complète)
- Test: `test/widgets/life_counter/layouts/adaptive_grid_test.dart`

**Interfaces:**
- Consumes: `tableLayoutFor(Size, int)`, `TableLayout`, `ActionBarKind` (T3) ; `TableSide`, `TableSeat` (T1).
- Produces: `AdaptiveGrid({Key? key, required List<Widget> playerZones, required Widget centralBar, required Widget actionHub})`.

La signature gagne `actionHub` : la grille choisit lequel des deux rendre, d'après `TableLayout.barKind`. L'appelant fournit les deux et ne décide de rien.

- [ ] **Step 1: Écrire les tests qui échouent**

Le fichier de test existant est réécrit. Les tests à écrire, décrits par leurs assertions — les signatures exactes sont celles ci-dessus :

1. **« AdaptiveGrid ne contient aucune RotatedBox »** — monter la grille avec 4 zones, asserter `find.descendant(of: find.byType(AdaptiveGrid), matching: find.byType(RotatedBox))` → `findsNothing`. C'est le verrou de la contrainte globale n°1.
2. **« à 4 joueurs sur téléphone en portrait, aucune zone n'est en colonne latérale »** — monter dans un `MediaQuery` de 390×844, et asserter par **géométrie** que les quatre zones ont toutes la même largeur (`tester.getSize` de chaque `ValueKey('grid_slot_<i>')`), ce qui ne peut être vrai que sans colonne latérale.
3. **« à 4 joueurs sur tablette en paysage, deux zones occupent les bords »** — monter en 1180×820, asserter par géométrie que la zone du slot gauche a un `dx` de centre inférieur à toutes les autres, et celle du slot droit un `dx` supérieur.
4. **« la largeur de colonne rendue est celle que `tableLayoutFor` a décidée »** — comparer `tester.getSize(...).width` de la zone latérale à `tableLayoutFor(const Size(1180, 820), 4).sideWidth`, à 1 px près.
5. **« la bande centrale est rendue sur tablette, le hub sur téléphone »** — asserter la présence de `ValueKey('action_band')` vs `ValueKey('action_hub')` selon le `MediaQuery`.
6. **« à 8 joueurs, chaque moitié passe en sous-grille 2×2 »** — asserter par géométrie que les quatre zones du haut se répartissent sur deux `dy` distincts.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/layouts/adaptive_grid_test.dart`
Attendu : ÉCHEC — `AdaptiveGrid` n'accepte pas encore `actionHub`.

- [ ] **Step 3: Écrire l'implémentation**

```dart
// lib/widgets/life_counter/layouts/adaptive_grid.dart
import 'package:flutter/material.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

/// Place les zones joueur autour de la table.
///
/// Cette classe ne décide de RIEN : `tableLayoutFor` tranche la disposition,
/// `seatsFor` tranche la géométrie. Et surtout, elle ne PIVOTE rien — la
/// rotation appartient à `PlayerZone` et à lui seul. Au lot 6, la grille
/// pivotait la moitié haute pendant que le siège écrivait la même rotation dans
/// l'état : 180° + 180° = 360°, table inversée, tous les tests verts.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.playerZones,
    required this.centralBar,
    required this.actionHub,
  });

  final List<Widget> playerZones;

  /// Bande horizontale des huit actions. Rendue sur grand écran.
  final Widget centralBar;

  /// Bouton rond central qui ouvre la feuille des actions. Rendu sur petit
  /// écran, où une bande lisible ne tient pas sans voler leur place aux zones.
  final Widget actionHub;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = tableLayoutFor(
          Size(constraints.maxWidth, constraints.maxHeight),
          playerZones.length,
        );
        final seats = layout.seats;

        List<Widget> zonesOn(TableSide side) {
          final indexed = <int>[];
          for (int i = 0; i < seats.length; i++) {
            if (seats[i].side == side) indexed.add(i);
          }
          indexed.sort((a, b) => seats[a].slot.compareTo(seats[b].slot));
          return [
            for (final i in indexed)
              Padding(
                key: ValueKey('grid_slot_$i'),
                padding: const EdgeInsets.all(2),
                child: playerZones[i],
              ),
          ];
        }

        final top = zonesOn(TableSide.top);
        final bottom = zonesOn(TableSide.bottom);
        final left = zonesOn(TableSide.left);
        final right = zonesOn(TableSide.right);
        final subGrid = playerZones.length == 8;

        final centre = Column(
          children: [
            Expanded(child: _half(top, subGrid: subGrid)),
            if (layout.barKind == ActionBarKind.band)
              KeyedSubtree(
                  key: const ValueKey('action_band'), child: centralBar),
            Expanded(child: _half(bottom, subGrid: subGrid)),
          ],
        );

        final withHub = layout.barKind == ActionBarKind.hub
            ? Stack(
                alignment: Alignment.center,
                children: [
                  centre,
                  KeyedSubtree(
                      key: const ValueKey('action_hub'), child: actionHub),
                ],
              )
            : centre;

        if (!layout.useSideColumns) return withHub;

        return Row(
          children: [
            SizedBox(width: layout.sideWidth, child: _column(left)),
            Expanded(child: withHub),
            SizedBox(width: layout.sideWidth, child: _column(right)),
          ],
        );
      },
    );
  }

  static Widget _column(List<Widget> zones) =>
      Column(children: [for (final zone in zones) Expanded(child: zone)]);

  static Widget _half(List<Widget> zones, {required bool subGrid}) {
    if (zones.isEmpty) return const SizedBox.shrink();
    if (subGrid && zones.length == 4) {
      return Column(
        children: [
          Expanded(
              child: Row(children: [
            for (int i = 0; i < 2; i++) Expanded(child: zones[i]),
          ])),
          Expanded(
              child: Row(children: [
            for (int i = 2; i < 4; i++) Expanded(child: zones[i]),
          ])),
        ],
      );
    }
    return Row(children: [for (final zone in zones) Expanded(child: zone)]);
  }
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/widgets/life_counter/layouts/adaptive_grid_test.dart`
Attendu : 6 tests PASS.

- [ ] **Step 5: Vérifier la discrimination**

Envelopper `playerZones[i]` dans `RotatedBox(quarterTurns: 2, child: ...)` : le test n°1 doit ÉCHOUER. Restaurer, `git status --short` vide.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/layouts/adaptive_grid.dart test/widgets/life_counter/layouts/adaptive_grid_test.dart
git commit -m "refactor: make AdaptiveGrid place seats without ever rotating them"
```

---

## Task 5: Rotations de siège, migration et réordonnancement

**Files:**
- Modify: `lib/models/game_session.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart`
- Test: `test/models/game_session_test.dart`
- Test: `test/pages/life_counter/reorder_rotation_test.dart`

**Interfaces:**
- Consumes: `seatsFor(int, {bool allowSideColumns})` (T1).
- Produces: `GameSession.toJson()` écrit `'rotationsMigrated': true` ; `GameSession.fromJson` ne migre que si le marqueur est absent.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
// à ajouter dans test/models/game_session_test.dart
test('un snapshot écrit par ce code porte le marqueur de migration', () {
  final session = GameSession.newGame(
    format: GameFormat.builtInFormats.first,
    playerConfigs: List.generate(
      4,
      (i) => PlayerConfig(
        id: 'p$i',
        name: 'Joueur $i',
        type: i == 0 ? PlayerType.owner : PlayerType.guest,
      ),
    ),
  );
  expect(session.toJson()['rotationsMigrated'], isTrue);
});

test('un « Même sens » délibéré survit à un aller-retour JSON', () {
  final session = GameSession.newGame(
    format: GameFormat.builtInFormats.first,
    playerConfigs: List.generate(
      4,
      (i) => PlayerConfig(
        id: 'p$i',
        name: 'Joueur $i',
        type: i == 0 ? PlayerType.owner : PlayerType.guest,
      ),
    ),
  );
  final allZero = session.copyWith(
    players: session.players.map((p) => p.copyWith(quarterTurns: 0)).toList(),
  );
  final round = GameSession.fromJson(allZero.toJson());
  expect(round.players.map((p) => p.quarterTurns).toList(), [0, 0, 0, 0],
      reason: 'sans le marqueur, l\'heuristique prendrait ce choix délibéré '
          'pour un ancien snapshot et le réécrirait à chaque rechargement');
});

test('un ancien snapshot SANS marqueur reçoit les rotations de siège', () {
  final session = GameSession.newGame(
    format: GameFormat.builtInFormats.first,
    playerConfigs: List.generate(
      4,
      (i) => PlayerConfig(
        id: 'p$i',
        name: 'Joueur $i',
        type: i == 0 ? PlayerType.owner : PlayerType.guest,
      ),
    ),
  );
  final legacy = Map<String, dynamic>.from(session.toJson())
    ..remove('rotationsMigrated');
  legacy['players'] = (legacy['players'] as List)
      .map((p) => Map<String, dynamic>.from(p as Map)..['quarterTurns'] = 0)
      .toList();
  final migrated = GameSession.fromJson(legacy);
  expect(migrated.players.map((p) => p.quarterTurns).toList(), [2, 3, 0, 1]);
});
```

Et, dans `test/pages/life_counter/reorder_rotation_test.dart`, deux tests widget décrits par leurs assertions :

1. **« un réordonnancement ne touche que les zones déplacées »** — partir d'une table à 4 joueurs dont les quatre `quarterTurns` ont été mis à 0, jouer le **vrai geste** (appui long d'une seconde puis glissement livré en 12 incréments, jamais en un seul saut), échanger les zones des joueurs 0 et 3, et asserter que les joueurs 1 et 2 valent **toujours** 0 pendant que 0 et 3 ont pris la rotation de leur nouveau siège. Repérage exclusivement par `ValueKey('player_zone_<playerId>')`.
2. **« un preset se pose dans l'ordre d'AFFICHAGE »** — après ce même réordonnancement, appliquer un preset et asserter le résultat dans l'ordre canonique `playerId`. La fixture ne doit **pas** partir d'un `playerOrder` identité, sans quoi les deux ordres sont indiscernables et le test est vide.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/models/game_session_test.dart`
Attendu : ÉCHEC, `rotationsMigrated` vaut `null`.

- [ ] **Step 3: Écrire l'implémentation**

Dans `toJson()`, ajouter en première entrée de la map :

```dart
// Marqueur de migration des rotations (spec §8.1). Tout snapshot écrit par ce
// code porte déjà ses `quarterTurns` définitifs : `_migrateLegacyRotation` ne
// doit plus jamais s'exécuter dessus, sans quoi un joueur qui choisit
// délibérément « Même sens » (soit [0, 0, 0, 0], exactement ce que
// l'heuristique prend pour un ancien snapshot) verrait son choix écrasé par
// les défauts de sièges à chaque rechargement.
'rotationsMigrated': true,
```

Dans `fromJson`, remplacer l'appel direct par :

```dart
// Le marqueur est absent de tous les snapshots antérieurs à cette version :
// ce sont eux, et eux seuls, que la migration doit toucher.
final players = json['rotationsMigrated'] == true
    ? orderedPlayers
    : _migrateLegacyRotation(orderedPlayers, playerOrder);
```

Ajouter la méthode de migration, avec sa retombée canonique — `fromJson` produit un `playerOrder` **vide** pour les snapshots antérieurs au champ, c'est-à-dire tous les snapshots réels :

```dart
static List<PlayerState> _migrateLegacyRotation(
    List<PlayerState> players, List<int> playerOrder) {
  if (players.length <= 1) return players;
  if (players.any((p) => p.quarterTurns != 0)) return players;
  // `playerOrder` est vide pour tout snapshot antérieur à ce champ : sans
  // cette retombée, la migration ne toucherait aucun joueur réel.
  final effectiveOrder = playerOrder.length == players.length
      ? playerOrder
      : players.map((p) => p.playerId).toList();
  final seats = seatsFor(effectiveOrder.length);
  final byId = {for (final p in players) p.playerId: p};
  for (int i = 0; i < effectiveOrder.length; i++) {
    final id = effectiveOrder[i];
    byId[id] = byId[id]!.copyWith(quarterTurns: seats[i].quarterTurns);
  }
  return players.map((p) => byId[p.playerId]!).toList();
}
```

Dans `_onReorderPlayers` de `life_counter_page.dart`, après `_controller.reorderPlayers(order)` :

```dart
// Une zone DÉPLACÉE prend l'orientation par défaut de son nouveau siège
// (décision utilisateur). Seules les deux zones permutées changent de
// siège : les reposer TOUTES détruisait l'orientation des joueurs que
// personne n'avait touchés — un « Même sens » sautait au premier
// glisser-déposer sans rapport.
final seats = seatsFor(order.length);
for (final displayIndex in {oldIndex, newIndex}) {
  _controller.updateRotation(
      order[displayIndex], seats[displayIndex].quarterTurns);
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/models/game_session_test.dart test/pages/life_counter/reorder_rotation_test.dart`
Attendu : tous PASS.

- [ ] **Step 5: Vérifier la discrimination**

1. Retirer le garde `json['rotationsMigrated'] == true` → le test « un Même sens délibéré survit » doit ÉCHOUER.
2. Remplacer `for (final displayIndex in {oldIndex, newIndex})` par une boucle sur tout `order` → le test « ne touche que les zones déplacées » doit ÉCHOUER.

Restaurer après chacune, `git status --short` vide.

- [ ] **Step 6: Commit**

```bash
git add lib/models/game_session.dart lib/pages/life_counter/life_counter_page.dart test/models/game_session_test.dart test/pages/life_counter/reorder_rotation_test.dart
git commit -m "feat: seat rotations, migrated once and reseated only when moved"
```

---

## Task 6: Hub d'actions

**Files:**
- Create: `lib/widgets/life_counter/zone/action_hub.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart` (l'appel à `AdaptiveGrid`, et `_buildCentralBar`)
- Test: `test/widgets/life_counter/zone/action_hub_test.dart`

**Interfaces:**
- Consumes: `ActionBarKind` (T3), `AdaptiveGrid({... required Widget actionHub})` (T4).
- Produces: `ActionHub({Key? key, required List<GameAction> actions})` ; `class GameAction { const GameAction({required this.icon, required this.label, required this.onPressed}); final IconData icon; final String label; final VoidCallback onPressed; }`.

- [ ] **Step 1: Écrire les tests qui échouent**

Tests décrits par leurs assertions :

1. **« le hub n'affiche qu'un bouton au repos »** — monter `ActionHub` avec huit `GameAction`, asserter `find.byKey(const ValueKey('action_hub_button'))` → `findsOneWidget`, et qu'aucun libellé d'action n'est visible.
2. **« taper le hub ouvre les HUIT actions »** — taper la clé ci-dessus, `pumpAndSettle`, puis asserter que les huit libellés sont trouvés. C'est le test qui interdit la dégradation silencieuse : il compte, il ne se contente pas de vérifier que la feuille s'ouvre.
3. **« choisir une action la déclenche et ferme la feuille »** — taper un libellé, asserter que le `onPressed` correspondant a été appelé **une seule fois** et que la feuille est refermée.
4. **« le bouton du hub fait au moins 48 px »** — `tester.getSize` sur la clé, asserter `width >= 48 && height >= 48`, la cible tactile minimale.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/action_hub_test.dart`
Attendu : ÉCHEC à la résolution du paquet.

- [ ] **Step 3: Écrire l'implémentation**

```dart
// lib/widgets/life_counter/zone/action_hub.dart
import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Une action de partie, telle que le hub la présente.
class GameAction {
  const GameAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// Accès aux actions de partie sur petit écran (spec §4.2).
///
/// Un bouton rond au centre de la table, qui ouvre une feuille contenant TOUTES
/// les actions. Il ne coûte que son diamètre, donc il ne prend jamais la place
/// des zones — contrairement à la bande, qui sur un écran étroit se réduisait
/// silencieusement à ses deux premières icônes et emportait avec elle le choix
/// du nombre de joueurs et les options de jeu.
class ActionHub extends StatelessWidget {
  const ActionHub({super.key, required this.actions});

  final List<GameAction> actions;

  static const double diameter = 56.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        key: const ValueKey('action_hub_button'),
        color: AppColors.surfaceElevated,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            for (final action in actions)
              ListTile(
                leading: Icon(action.icon, color: AppColors.textSecondary),
                title: Text(action.label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  action.onPressed();
                },
              ),
          ],
        ),
      ),
    );
  }
}
```

Dans `life_counter_page.dart`, extraire la liste des huit actions dans un getter `List<GameAction> _gameActions` utilisé **à la fois** par `_buildCentralBar()` et par `ActionHub`, puis passer `actionHub: ActionHub(actions: _gameActions)` à `AdaptiveGrid`.

Supprimer le `SingleChildScrollView` horizontal de `_buildCentralBar()` : la bande n'est rendue que quand `tableLayoutFor` a vérifié qu'elle tient.

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/widgets/life_counter/zone/action_hub_test.dart`
Attendu : 4 tests PASS.

- [ ] **Step 5: Vérifier la discrimination**

Tronquer la liste de la feuille à `actions.take(2)` : le test « ouvre les HUIT actions » doit ÉCHOUER. Restaurer, `git status --short` vide.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/zone/action_hub.dart lib/pages/life_counter/life_counter_page.dart test/widgets/life_counter/zone/action_hub_test.dart
git commit -m "feat: reach every game action through a hub on small screens"
```

---

## Task 7: Paliers resserrés, fermés au relâchement

**Files:**
- Modify: `lib/widgets/life_counter/zone/life_dial.dart` (`_stepRow` à la ligne 222, `_half` à la ligne 282, et le `Stack` de `build` autour de la ligne 188)
- Test: `test/widgets/life_counter/zone/life_dial_test.dart`

**Interfaces:**
- Consumes: `PlayerZoneNotifier.enterAdjustMode()` / `exitAdjustMode()`, déjà présents.
- Produces: rien de nouveau pour les autres tâches.

C'est la tâche la plus délicate : elle remplace quatre `GestureDetector(onTap:)` par un suivi de pointeur, parce qu'un `onTap` ne peut pas se produire sans lever le doigt.

- [ ] **Step 1: Écrire les tests qui échouent**

Tests décrits par leurs assertions :

1. **« l'appui long ouvre les paliers »** — appui long sur le cadran, asserter que les quatre libellés `-10`, `-5`, `+5`, `+10` sont visibles.
2. **« relâcher hors des paliers ferme le mode sans rien appliquer »** — appui long, relâcher au centre du cadran, asserter que les libellés ont disparu **et** que `onLifeChanged` n'a jamais été appelé.
3. **« glisser sur un palier puis relâcher applique CE palier »** — appui long, `moveTo` le centre du bouton `ValueKey('life_step_-5')`, relâcher ; asserter que `onLifeChanged` a été appelé une fois avec `-5`, et que les libellés ont disparu.
4. **« le mode ne survit pas au relâchement »** — après le test 3, asserter `find.byKey(const ValueKey('life_step_-5'))` → `findsNothing`.
5. **« la rangée ne prend pas toute la largeur »** — appui long, comparer `tester.getSize` de `ValueKey('life_step_row')` à celle du cadran : asserter que la rangée fait **moins de 70 %** de la largeur de la zone. C'est la propriété de §5.4, et elle se teste par **géométrie** parce que la propriété testée EST la disposition.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/life_dial_test.dart`
Attendu : les tests 3, 4 et 5 ÉCHOUENT — le mode persiste et la rangée est en pleine largeur.

- [ ] **Step 3: Écrire l'implémentation**

Remplacer `_stepRow()` par une version resserrée et repérable, chaque bouton portant une clé et une `GlobalKey` pour le test de survol :

```dart
/// Fraction de la largeur de la zone laissée libre de chaque côté de la
/// rangée (spec §5.4). La rangée pleine largeur retombait exactement là où
/// le pouce arrive, ce qui faisait modifier les PV par accident.
static const double _stepRowSideMargin = 0.18;

final Map<int, GlobalKey> _stepKeys = {
  for (final delta in const [-10, -5, 5, 10]) delta: GlobalKey(),
};

Widget _stepRow(double zoneWidth) {
  final inset = zoneWidth * _stepRowSideMargin;
  return Padding(
    key: const ValueKey('life_step_row'),
    padding: EdgeInsets.fromLTRB(inset, 8, inset, 8),
    child: Row(
      children: [
        for (final delta in const [-10, -5, 5, 10])
          Expanded(
            child: Padding(
              key: ValueKey('life_step_$delta'),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                key: _stepKeys[delta],
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: delta < 0
                      ? AppColors.accentRed.withAlpha(40)
                      : AppColors.accentGreen.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  delta > 0 ? '+$delta' : '$delta',
                  style: AppTextStyles.lifeStepLabel(
                    color: delta < 0
                        ? AppColors.accentRed
                        : AppColors.accentGreen,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
```

Remplacer la sortie par tap (`GestureDetector(onTap: notifier.exitAdjustMode)` sur un `SizedBox.expand()`) par une fermeture au relâchement du pointeur. Dans `_half`, `onTapUp` et `onTapCancel` doivent, quand `isAdjusting` est vrai, résoudre le palier survolé plutôt que d'émettre un ±1 :

```dart
/// Palier dont le bouton contient [globalPosition], ou `null`.
///
/// Les boutons sont retrouvés par leur `GlobalKey` : aucune position n'est
/// calculée à la main, ce qui reste juste quelle que soit la rotation du
/// siège — un point sur lequel ce projet s'est déjà trompé neuf fois.
int? _stepUnder(Offset globalPosition) {
  for (final entry in _stepKeys.entries) {
    final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) continue;
    final origin = box.localToGlobal(Offset.zero);
    if ((origin & box.size).contains(globalPosition)) return entry.key;
  }
  return null;
}

/// Fin du geste en mode ajustement : on applique le palier survolé, s'il y en
/// a un, puis on sort du mode dans tous les cas.
///
/// Le mode ne survit pas au doigt (spec §5.1). L'amendement du lot 2 avait
/// écarté cette fermeture au motif que les paliers deviendraient
/// inatteignables — ce qui n'est vrai que s'il faut LEVER le doigt pour taper.
/// Avec un glissé-relâché, ils restent atteignables sans rompre le contact.
void _endAdjustGesture(PlayerZoneNotifier notifier, Offset globalPosition) {
  final delta = _stepUnder(globalPosition);
  if (delta != null) _emit(delta);
  notifier.exitAdjustMode();
}
```

Le `Stack` de `build` conserve `IgnorePointer(ignoring: isAdjusting)` sur les deux moitiés — les démonter couperait net le pointeur en cours — et le `_stepRow(constraints.maxWidth)` remplace l'ancienne paire couche-de-sortie + rangée.

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/widgets/life_counter/zone/life_dial_test.dart`
Attendu : tous PASS.

- [ ] **Step 5: Vérifier la discrimination**

1. Retirer l'appel à `notifier.exitAdjustMode()` dans `_endAdjustGesture` → le test « le mode ne survit pas au relâchement » doit ÉCHOUER.
2. Porter `_stepRowSideMargin` à `0.0` → le test « la rangée ne prend pas toute la largeur » doit ÉCHOUER.

Restaurer après chacune, `git status --short` vide.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/zone/life_dial.dart test/widgets/life_counter/zone/life_dial_test.dart
git commit -m "feat: make the step row one continuous gesture, narrowed"
```

---

## Task 8: Porte de vérification visuelle

**Files:** aucun fichier de code. Cette tâche produit des **captures d'écran**.

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: le feu vert de merge. C'est la seule tâche que les tests ne peuvent pas remplacer.

**Cette tâche est bloquante.** Le lot 6 est parti avec 1028 tests verts et zéro pixel regardé ; c'est exactement ce qu'elle existe pour empêcher. Aucun merge tant qu'elle n'est pas rendue.

- [ ] **Step 1: Lancer la suite complète et l'analyse**

Run: `flutter test` puis `flutter analyze`
Attendu : tout vert, aucune erreur ni avertissement nouveau (le `warning` `_tag` dans `game_setup_modal.dart` est antérieur à cette branche).

- [ ] **Step 2: Capturer les six situations de la spec §7.2**

1. 4 joueurs, téléphone en portrait — face-à-face strict, aucune colonne latérale, hub atteignable.
2. 4 joueurs, tablette en paysage, **posée à plat sur une table** — une capture, puis une vérification **depuis chacune des quatre chaises** : le chiffre se lit à l'endroit, la moitié gauche décrémente *telle que ce joueur-là la voit*, la poignée s'atteint au doigt.
3. 8 joueurs, petit écran — cran minimal lisible, poignée atteignable.
4. Les huit actions atteignables dans les deux formes de barre, sans défilement caché.
5. Le geste de palier au pouce, sur appareil réel, à la taille de zone d'une partie à 4 joueurs — le point de vigilance de §5.3.
6. Glisser-déposer aux quatre orientations.

- [ ] **Step 3: Soumettre les captures à l'utilisateur**

Ne pas fusionner. Présenter les captures et attendre son verdict.

Le point n°5 est celui qui peut invalider une décision de la spec : si atteindre une cible de 30 px en bout d'appui long sans lever le doigt se révèle pénible, le repli prévu est la §5.4 seule — rangée resserrée, mode persistant conservé. Le signaler franchement plutôt que de le laisser passer.

- [ ] **Step 4: Commit du journal de vérification**

```bash
git add docs/superpowers/notes/
git commit -m "docs: record the visual verification of the multiplayer table"
```

---

## Auto-revue

**1. Couverture de la spec.**

| Section | Tâche |
|---|---|
| §2 modèle de sièges | T1 |
| §2.1 propriétaire unique de la rotation | T4 (verrou), T5 (attribution) |
| §2.2 convention de rotation | T1 (`quarterTurns`), vérifiée géométriquement en T7 |
| §3 règle d'abordabilité | T3 |
| §4 barre d'actions | T3 (décision), T4 (rendu), T6 (hub) |
| §5 mode ajustement | T7 |
| §6 contrat de densité | T2 |
| §7.1 critères automatiques | intégré à chaque tâche (étape 5) |
| §7.2 critères visuels | T8 |
| §7.3 forme des tests | contraintes globales, appliquées partout |
| §8 migration | T5 |
| §9 hors périmètre | aucune tâche, volontairement |

Aucun trou.

**2. Balayage des remplissages.** Aucun « TBD », aucun « gérer les cas limites », aucun « comme la tâche N ». Les tâches T4, T6 et T7 décrivent leurs tests par leurs **assertions** plutôt que par du code verbatim : c'est délibéré. Sur le lot 6, deux blocs de test écrits verbatim dans le plan ne compilaient pas, et six défauts de compilation en ont découlé sur les lots 1 et 2. Les signatures exactes sont données ; la forme du test appartient à l'implémenteur, qui, lui, peut la compiler.

**3. Cohérence des types.** `seatsFor(int, {bool allowSideColumns})` est défini en T1 et consommé en T3 et T5 avec cette signature. `TableLayout` et `ActionBarKind` sont définis en T3 et consommés en T4. `kZoneShortEdgeFloor` est défini en T2 et consommé en T3. `AdaptiveGrid` gagne `actionHub` en T4, fourni en T6 — T4 doit donc être exécutée avant T6, et le plan les ordonne ainsi.

**Une dépendance à surveiller à l'exécution :** T4 introduit le paramètre `actionHub` et casse l'appel existant dans `life_counter_page.dart`. T4 doit fournir un `actionHub` provisoire (`const SizedBox.shrink()`) pour que la suite reste verte entre T4 et T6, et T6 le remplace. C'est noté ici plutôt que découvert à l'exécution.
