# Chantier A — Life counter : géométrie, orientation, lisibilité

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre la table équitable et lisible à 4 joueurs sur les deux écrans du Pixel Fold, et rendre l'orientation et la réorganisation explicites.

**Architecture:** La disposition est décidée par une fonction pure, `arrangementFor`, qui applique la règle du grand côté ; `seatsForArrangement` en dérive les sièges, et `TableSeat.quarterTurns` reste la seule source de rotation. Tout le reste du chantier branche des widgets existants sur ces décisions, sans introduire de seconde source de vérité.

**Tech Stack:** Flutter 3.9+, Riverpod 3 (`StateNotifier` et `Notifier` coexistent), Drift, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-18-mythic-moxfield-design.md` (§1.1 à §1.9)

## Global Constraints

- **Aucune couleur de joueur écrite en dur hors de `lib/widgets/life_counter/player_skins.dart`.** Un test balaie `lib/` et échoue sinon (Tâche 1).
- **`TableSeat.quarterTurns` est le seul calculateur de rotation.** Aucun autre fichier ne dérive une rotation d'un côté de table (spec §1.4, et §2.1 de la spec table multijoueur v2).
- **`kZoneShortEdgeFloor` et `kSideColumnNeed` sont dérivés, jamais recopiés.** Toute nouvelle exigence de place s'exprime en fonction d'eux.
- **Aucune cible tactile sous 48×48** (`kMinInteractiveDimension`). C'est le défaut que toute cette refonte existe pour éliminer.
- **Chaque test ajouté doit être discriminant** : avant de le committer, casser volontairement la ligne de production qu'il couvre et vérifier qu'il échoue.
- Langue des libellés : français, sans emoji.
- Commandes : `flutter test <chemin>` pour un fichier, `flutter test` pour tout, `flutter analyze` avant chaque commit.

---

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/widgets/life_counter/player_skins.dart` | **Créé.** Source unique des couleurs et fonds de zone. | 1 |
| `lib/widgets/life_counter/tuning.dart` | **Créé.** Les quatre réglages jamais calibrés, nommés en un lieu. | 2 |
| `lib/models/table_seat.dart` | **Modifié.** `TableArrangement`, `seatsForArrangement`. | 3 |
| `lib/widgets/life_counter/layouts/table_layout.dart` | **Modifié.** `arrangementFor` (règle du grand côté), équité, `kSideColumnNeed` relevé. | 3 |
| `lib/providers/game_session_notifier.dart` | **Modifié.** Rotations semées depuis les sièges ; `applyOrientationPreset`. | 4, 8 |
| `lib/widgets/life_counter/zone/life_dial.dart` | **Modifié.** Repères `−`/`+`, moitié touchée éclaircie. | 5 |
| `lib/providers/player_zone_notifier.dart` | **Modifié.** Delta cumulé sur une fenêtre. | 6 |
| `lib/widgets/life_counter/zone/pending_delta.dart` | **Créé.** Rendu du delta cumulé, collé au total. | 6 |
| `lib/widgets/life_counter/zone/seated_sheet.dart` | **Créé.** Surface modale orientée vers son siège. | 7 |
| `lib/widgets/life_counter/zone/player_drawer.dart` | **Modifié.** Passe par `SeatedSheet`. | 7 |
| `lib/widgets/life_counter/zone/counter_editor_dialog.dart` | **Modifié.** Passe par `SeatedSheet`. | 7 |
| `lib/widgets/life_counter/draggable_player_zone.dart` | **Modifié.** Ne glisse qu'en mode réorganisation. | 8 |
| `lib/widgets/life_counter/zone/orientation_picker.dart` | **Créé.** Quatre flèches par zone. | 8 |
| `lib/widgets/life_counter/reorganise_bar.dart` | **Créé.** Barre de mode et presets. | 8 |
| `lib/pages/life_counter/life_counter_page.dart` | **Modifié.** Porte l'état `isReorganising` et monte la barre. | 8 |

---

## Task 1: Source unique des couleurs et fonds de zone

**Files:**
- Create: `lib/widgets/life_counter/player_skins.dart`
- Modify: `lib/widgets/life_counter/game_setup_modal.dart:53-56`
- Modify: `lib/widgets/life_counter/zone/player_skin_picker.dart:29-34`
- Test: `test/widgets/life_counter/player_skins_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `class PlayerSkin { final String label; final Color color; final String? assetPath; }`, `const List<PlayerSkin> kPlayerSkins`, `PlayerSkin defaultSkinForSeat(int seatIndex)`.

**Qui appelle quoi, une fois la tâche finie :** `game_setup_modal.dart` appelle `defaultSkinForSeat(index)` là où il lisait `_defaultColors[index % _defaultColors.length]` (ligne 314), et `kPlayerSkins` là où il affichait `_defaultColors` (ligne 803). `player_skin_picker.dart` expose `kPlayerSkins` à la place de `playerSkinColorOptions`. Aucun autre fichier ne définit de couleur de joueur.

- [ ] **Step 1: Écrire le test qui interdit les couleurs en dur**

```dart
// test/widgets/life_counter/player_skins_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/player_skins.dart';

void main() {
  test('kPlayerSkins couvre au moins six sièges', () {
    expect(kPlayerSkins.length, greaterThanOrEqualTo(6));
  });

  test('defaultSkinForSeat boucle sans jamais sortir de la liste', () {
    for (int i = 0; i < 20; i++) {
      expect(kPlayerSkins, contains(defaultSkinForSeat(i)));
    }
  });

  test('aucune couleur de joueur Material en dur hors de player_skins.dart', () {
    final offenders = <String>[];
    final shades = RegExp(r'Colors\.\w+\.shade(800|900)');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('player_skins.dart')) continue;
      final text = entity.readAsStringSync();
      // Seuls les fichiers du life counter sont concernés : une couleur
      // Material ailleurs n'est pas une couleur de joueur.
      if (!entity.path.contains('life_counter')) continue;
      if (shades.hasMatch(text)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty,
        reason: 'Couleurs de joueur en dur : ${offenders.join(", ")}');
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

Run: `flutter test test/widgets/life_counter/player_skins_test.dart`
Expected: FAIL — `player_skins.dart` n'existe pas (erreur de compilation).

- [ ] **Step 3: Créer `player_skins.dart`**

```dart
// lib/widgets/life_counter/player_skins.dart
// Source UNIQUE des couleurs et fonds de zone joueur.
//
// Avant ce fichier, deux listes divergentes coexistaient :
// `game_setup_modal._defaultColors` (6 entrées) et
// `player_skin_picker.playerSkinColorOptions` (12 entrées), toutes deux en
// `Colors.*.shade900` Material. D'où des zones qui ne se ressemblaient pas
// d'un écran à l'autre, et une saturation étrangère à la DA Grimoire.
//
// Les teintes ci-dessous sont des couleurs de TERRAIN désaturées, validées
// sur maquette. Elles appartiennent à la famille « domaine » et ne
// partagent AUCUNE valeur avec la famille « sémantique » (feedback/*) :
// un badge « possédée » ne doit pas se confondre avec une zone verte.

import 'package:flutter/material.dart';

/// Habillage d'une zone joueur : une couleur, et le fond illustré qui
/// l'accompagne quand l'asset est présent.
@immutable
class PlayerSkin {
  const PlayerSkin({
    required this.label,
    required this.color,
    this.assetPath,
  });

  final String label;
  final Color color;

  /// Fond illustré embarqué, ou `null` pour un aplat.
  ///
  /// JAMAIS un art de carte Magic : ces visuels appartiennent à Wizards of
  /// the Coast et ne peuvent pas être redistribués dans le binaire. Les arts
  /// Scryfall restent accessibles en réseau via `player_skin_picker`.
  final String? assetPath;

  @override
  bool operator ==(Object other) =>
      other is PlayerSkin &&
      other.label == label &&
      other.color == color &&
      other.assetPath == assetPath;

  @override
  int get hashCode => Object.hash(label, color, assetPath);
}

const List<PlayerSkin> kPlayerSkins = [
  PlayerSkin(label: 'Plaine', color: Color(0xFFC9B88A)),
  PlayerSkin(label: 'Île', color: Color(0xFF3E6B8A)),
  PlayerSkin(label: 'Marécage', color: Color(0xFF4A4350)),
  PlayerSkin(label: 'Montagne', color: Color(0xFF8A4038)),
  PlayerSkin(label: 'Forêt', color: Color(0xFF4A6B4F)),
  PlayerSkin(label: 'Incolore', color: Color(0xFF5A5A63)),
  PlayerSkin(label: 'Cendre', color: Color(0xFF3A3646)),
  PlayerSkin(label: 'Parchemin', color: Color(0xFF6E5A3C)),
];

/// Habillage par défaut du siège [seatIndex], 0 pour le premier joueur.
PlayerSkin defaultSkinForSeat(int seatIndex) =>
    kPlayerSkins[seatIndex % kPlayerSkins.length];
```

- [ ] **Step 4: Lancer le test, vérifier qu'il échoue encore sur le troisième cas**

Run: `flutter test test/widgets/life_counter/player_skins_test.dart`
Expected: les deux premiers tests PASS, le troisième FAIL en nommant `game_setup_modal.dart` et `player_skin_picker.dart`.

- [ ] **Step 5: Brancher `game_setup_modal.dart`**

Supprimer le champ `_defaultColors` (lignes 53-56). Puis, ligne 314 :

```dart
// Avant : backgroundColor: _defaultColors[index % _defaultColors.length],
backgroundColor: defaultSkinForSeat(index).color,
```

Lignes 619 et 725, le défaut `_defaultColors[1]` devient :

```dart
Color selectedColor = existingProfile != null
    ? Color(existingProfile.colorValue)
    : defaultSkinForSeat(1).color;
```

Ligne 803, la palette proposée :

```dart
children: kPlayerSkins.map((skin) => GestureDetector(
```

(le corps du `map` lit `skin.color` là où il lisait `c`.)

Ajouter l'import `import 'player_skins.dart';`.

- [ ] **Step 6: Brancher `player_skin_picker.dart`**

Supprimer `playerSkinColorOptions` (lignes 29-34) et son doc-comment. Ajouter `import '../player_skins.dart';`. Remplacer chaque usage de `playerSkinColorOptions` par `kPlayerSkins`, en lisant `.color` sur chaque entrée.

- [ ] **Step 7: Lancer toute la suite**

Run: `flutter test && flutter analyze`
Expected: PASS, aucun avertissement nouveau.

- [ ] **Step 8: Vérifier que le test est discriminant**

Réintroduire temporairement `final c = Colors.red.shade900;` dans `game_setup_modal.dart`, relancer `flutter test test/widgets/life_counter/player_skins_test.dart`, constater le FAIL, puis retirer la ligne.

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/life_counter/player_skins.dart lib/widgets/life_counter/game_setup_modal.dart lib/widgets/life_counter/zone/player_skin_picker.dart test/widgets/life_counter/player_skins_test.dart
git commit -m "feat(life-counter): source unique des couleurs de joueur"
```

---

## Task 2: Fichier de calibrage

**Files:**
- Create: `lib/widgets/life_counter/tuning.dart`
- Modify: `lib/widgets/life_counter/zone/life_dial.dart` (constante `kLongPressTimeout` et réglages de molette)
- Test: `test/widgets/life_counter/tuning_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `kLongPressTimeout`, `kWheelPixelsPerStep`, `kWheelAcceleration`, `kDamageBufferWindow`.

**Qui appelle quoi :** `life_dial.dart` importe `../tuning.dart` et cesse de définir `kLongPressTimeout` localement. La Tâche 6 lira `kDamageBufferWindow` depuis ce fichier. Aucun de ces réglages n'est exposé dans les Réglages de l'application.

- [ ] **Step 1: Écrire le test**

```dart
// test/widgets/life_counter/tuning_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/tuning.dart';

void main() {
  test('les réglages ont des valeurs utilisables', () {
    expect(kLongPressTimeout.inMilliseconds, inInclusiveRange(200, 600));
    expect(kDamageBufferWindow.inMilliseconds, inInclusiveRange(1000, 5000));
    expect(kWheelPixelsPerStep, greaterThan(0));
    expect(kWheelAcceleration, greaterThanOrEqualTo(1.0));
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/widgets/life_counter/tuning_test.dart`
Expected: FAIL — `tuning.dart` n'existe pas.

- [ ] **Step 3: Créer `tuning.dart`**

```dart
// lib/widgets/life_counter/tuning.dart
// Les réglages du life counter qui n'ont JAMAIS été éprouvés en partie
// réelle. Les specs v4 (§6) et table multijoueur v2 les listaient comme
// « à calibrer en usage réel » ; ils étaient dispersés dans le code de
// production, donc introuvables au moment où l'on voulait les toucher.
//
// Aucune de ces valeurs n'est exposée dans les Réglages : ce fichier existe
// pour qu'un ajustement après une partie soit un geste, pas une fouille.

/// Durée d'appui avant l'entrée en mode ajustement.
///
/// Assez courte pour ne pas frustrer, assez longue pour ne pas se
/// déclencher sur un tap appuyé. Valeur historique, jamais mesurée.
const Duration kLongPressTimeout = Duration(milliseconds: 350);

/// Fenêtre pendant laquelle les changements de vie successifs sont cumulés
/// en un seul delta affiché, et pendant laquelle la rangée d'attribution de
/// dégâts de commandant reste ouverte.
///
/// Les 2 s d'origine n'ont jamais été validées. C'est le PREMIER réglage à
/// éprouver en partie réelle.
const Duration kDamageBufferWindow = Duration(seconds: 2);

/// Distance en pixels que le doigt doit parcourir, en mode ajustement, pour
/// faire bouger le total d'une unité à vitesse nominale.
const double kWheelPixelsPerStep = 12.0;

/// Facteur appliqué au pas de la molette quand le geste s'allonge, pour que
/// de gros montants restent atteignables sans vingt allers-retours.
/// 1.0 désactive l'accélération.
const double kWheelAcceleration = 1.6;
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `flutter test test/widgets/life_counter/tuning_test.dart`
Expected: PASS.

- [ ] **Step 5: Faire pointer `life_dial.dart` sur le fichier**

Supprimer la définition locale de `kLongPressTimeout` dans `life_dial.dart` et ajouter `import '../tuning.dart';`. Remplacer les littéraux de sensibilité de molette par `kWheelPixelsPerStep` et `kWheelAcceleration` aux endroits où `wheelAccumulator` est converti en pas.

- [ ] **Step 6: Lancer toute la suite**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/life_counter/tuning.dart lib/widgets/life_counter/zone/life_dial.dart test/widgets/life_counter/tuning_test.dart
git commit -m "refactor(life-counter): regroupe les reglages non calibres"
```

---

## Task 3: Règle du grand côté et équité des surfaces

**Files:**
- Modify: `lib/models/table_seat.dart`
- Modify: `lib/widgets/life_counter/layouts/table_layout.dart:70-140`
- Test: `test/widgets/life_counter/layouts/table_layout_test.dart` (fichier existant, groupes ajoutés)

**Interfaces:**
- Consumes: `kZoneShortEdgeFloor` et `tierFor` de `density_tier.dart`.
- Produces: `enum TableArrangement { faceToFace, columnPairs, around }`, `TableArrangement arrangementFor(Size size, int playerCount)`, `List<TableSeat> seatsForArrangement(int playerCount, TableArrangement arrangement)`.

**Qui appelle quoi :** `tableLayoutFor` appelle `arrangementFor` puis `seatsForArrangement`, et c'est le SEUL appelant de ces deux fonctions. `seatsFor` est conservée comme façade (`seatsFor(n)` = `seatsForArrangement(n, arrangementFor(...))` n'est pas possible sans `Size` : `seatsFor` garde sa signature actuelle et délègue à `seatsForArrangement` avec `faceToFace` ou `around`, pour ne casser aucun appelant existant).

- [ ] **Step 1: Écrire les tests de la règle du grand côté**

```dart
// à ajouter dans test/widgets/life_counter/layouts/table_layout_test.dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

void main() {
  group('règle du grand côté', () {
    test('à 4 joueurs sur écran replié, les zones sont en colonnes', () {
      // 390x844 : la zone d'une grille 2x2 fait 195x422, plus haute que large.
      expect(arrangementFor(const Size(390, 844), 4),
          TableArrangement.columnPairs);
    });

    test('à 4 joueurs sur écran déplié, les zones restent en face-à-face', () {
      // 840x700 : la zone fait 420x350, plus large que haute.
      expect(arrangementFor(const Size(840, 700), 4),
          TableArrangement.faceToFace);
    });

    test('columnPairs donne 90° à gauche et 270° à droite', () {
      final seats = seatsForArrangement(4, TableArrangement.columnPairs);
      final left = seats.where((s) => s.side == TableSide.left).toList();
      final right = seats.where((s) => s.side == TableSide.right).toList();
      expect(left, hasLength(2));
      expect(right, hasLength(2));
      expect(left.every((s) => s.quarterTurns == 1), isTrue);
      expect(right.every((s) => s.quarterTurns == 3), isTrue);
    });
  });

  group('équité des surfaces', () {
    test('à 4 joueurs, aucune colonne latérale, quel que soit l écran', () {
      for (final size in const [Size(840, 700), Size(390, 844), Size(1280, 800)]) {
        expect(tableLayoutFor(size, 4).useSideColumns, isFalse,
            reason: 'colonnes latérales à 4 joueurs sur $size');
      }
    });

    test('à 3 joueurs, aucune colonne latérale', () {
      expect(tableLayoutFor(const Size(840, 700), 3).useSideColumns, isFalse);
    });

    test('la bande ne sert que là où une frontière traverse la table', () {
      // Spec §1.2 : une bande horizontale ne vole de surface à personne
      // SEULEMENT si une frontière traverse déjà toute la table. En zones
      // égales à 3 ou 4 joueurs, il n'y en a pas : c'est le hub.
      expect(tableLayoutFor(const Size(1280, 800), 4).barKind,
          ActionBarKind.hub);
      expect(tableLayoutFor(const Size(1280, 800), 2).barKind,
          ActionBarKind.band);
      expect(tableLayoutFor(const Size(1280, 800), 6).barKind,
          ActionBarKind.band);
    });

    test('sur petit écran, le hub reste la seule forme', () {
      for (int n = 2; n <= 6; n++) {
        expect(tableLayoutFor(const Size(390, 844), n).barKind,
            ActionBarKind.hub);
      }
    });

    test('à 6 joueurs, une colonne doit tenir le cran compact', () {
      final layout = tableLayoutFor(const Size(1280, 800), 6);
      if (layout.useSideColumns) {
        expect(layout.sideWidth, greaterThanOrEqualTo(kSideColumnNeed));
        expect(tierFor(Size(layout.sideWidth, 800)),
            isNot(DensityTier.minimal));
      }
    });
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/widgets/life_counter/layouts/table_layout_test.dart`
Expected: FAIL — `arrangementFor` et `TableArrangement` n'existent pas.

- [ ] **Step 3: Ajouter l'arrangement dans `table_seat.dart`**

Après l'enum `TableSide`, ajouter :

```dart
/// Façon dont les sièges sont répartis sur l'écran.
///
/// Introduit pour que la DISPOSITION et la ROTATION aient une seule origine
/// commune : `TableSeat.quarterTurns` dérive de `side`, et `side` dérive de
/// l'arrangement. Auparavant la rotation d'un joueur était stockée sur le
/// modèle et la disposition calculée à part, d'où des orientations qui ne
/// correspondaient pas à la grille affichée.
enum TableArrangement {
  /// Moitié haute à 180°, moitié basse à 0°. Zones plus larges que hautes.
  faceToFace,

  /// Deux colonnes : celle de gauche à 90°, celle de droite à 270°.
  /// Zones plus hautes que larges — la rotation leur rend leur grand côté.
  columnPairs,

  /// Un joueur par bord, avec colonnes latérales. 5 et 6 joueurs.
  around,
}
```

Puis, après `seatsFor`, ajouter :

```dart
/// Sièges pour un [arrangement] donné.
///
/// Seul `tableLayoutFor` appelle cette fonction : c'est lui qui décide de
/// l'arrangement, via `arrangementFor`.
List<TableSeat> seatsForArrangement(
  int playerCount,
  TableArrangement arrangement,
) =>
    switch (arrangement) {
      TableArrangement.faceToFace => _faceToFace(playerCount),
      TableArrangement.columnPairs => _columnPairs(playerCount),
      TableArrangement.around => seatsFor(playerCount),
    };

/// Deux colonnes de hauteur égale, remplies en alternance gauche/droite pour
/// qu'un nombre impair de joueurs ne laisse pas une colonne vide.
List<TableSeat> _columnPairs(int playerCount) => _withSlots([
      for (int i = 0; i < playerCount; i++)
        i.isEven ? TableSide.left : TableSide.right,
    ]);
```

- [ ] **Step 3bis: Restreindre la bande d'actions (spec §1.2)**

Dans `table_layout.dart`, `barKind` n'est plus déduit du seul `shortEdge`.
Remplacer son calcul en tête de `tableLayoutFor` par :

```dart
  // Une bande horizontale ne lèse personne SEULEMENT là où une frontière
  // traverse déjà toute la table : le face-à-face à 2 joueurs, et les
  // dispositions à colonnes où elle s'insère entre les deux rangées
  // centrales. En zones égales à 3 ou 4 joueurs, il n'y a pas de telle
  // frontière : une bande y couperait la table en deux et volerait de la
  // hauteur au centre. C'est le défaut constaté en capture le 18/10/2026.
  final hasFullWidthSeam = playerCount == 2 || playerCount > 4;
  final barKind = (shortEdge < kLargeScreenShortEdge || !hasFullWidthSeam)
      ? ActionBarKind.hub
      : ActionBarKind.band;
```

- [ ] **Step 4: Ajouter `arrangementFor` dans `table_layout.dart`**

Au-dessus de `tableLayoutFor` :

```dart
/// Arrangement retenu pour un écran et un nombre de joueurs (spec §1.4).
///
/// **La règle du grand côté.** Une zone est orientée de façon à ce que son
/// sens de lecture suive son GRAND côté. Une zone plus haute que large
/// reçoit donc un quart de tour ; une zone plus large que haute n'en reçoit
/// pas. C'est pourquoi l'écran déplié (zone 420×350) reste en face-à-face
/// alors que l'écran replié (zone 195×422) passe en colonnes.
///
/// Au-delà de 4 joueurs, une grille égale n'est pas réalisable et
/// l'arrangement `around` reprend la main — sous réserve que les colonnes
/// soient payables, ce que `tableLayoutFor` vérifie ensuite.
TableArrangement arrangementFor(Size size, int playerCount) {
  if (playerCount > 4) return TableArrangement.around;

  // Grille égale : 2 colonnes dès 3 joueurs, 1 seule à 2 joueurs.
  final columns = playerCount <= 2 ? 1 : 2;
  final rows = (playerCount / columns).ceil();
  final zone = Size(size.width / columns, size.height / rows);

  return zone.height > zone.width
      ? TableArrangement.columnPairs
      : TableArrangement.faceToFace;
}
```

- [ ] **Step 5: Récrire le corps de `tableLayoutFor`**

Remplacer le corps actuel (de `final wanted = seatsFor(playerCount);` jusqu'au `return` final) par :

```dart
  final arrangement = arrangementFor(size, playerCount);

  // Équité : jusqu'à 4 joueurs, la grille est égale et personne n'est
  // relégué dans une bande. Les colonnes latérales n'existent plus que là
  // où une grille égale est impossible.
  if (arrangement != TableArrangement.around) {
    return TableLayout(
      useSideColumns: false,
      sideWidth: 0.0,
      barKind: barKind,
      seats: seatsForArrangement(playerCount, arrangement),
    );
  }

  final wanted = seatsForArrangement(playerCount, arrangement);
  final wantsSides = wanted.any(
      (s) => s.side == TableSide.left || s.side == TableSide.right);
  if (!wantsSides) return fallback();

  final shapeAllows =
      size.width > size.height || shortEdge >= kLargeScreenShortEdge;
  if (!shapeAllows) return fallback();

  final centreNeed = barKind == ActionBarKind.band ? kBandNeed : kHubNeed;
  if (size.width - 2 * kSideColumnNeed < centreNeed) return fallback();

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
```

- [ ] **Step 6: Relever `kSideColumnNeed` à l'exigence `compact`**

Dans `table_layout.dart`, remplacer la constante et son doc-comment :

```dart
/// Petit côté minimal pour qu'une zone tienne le cran `compact` (nom + PV +
/// poignée). Valeur lue sur le seuil de `tierFor`.
const double kCompactShortEdge = 110.0;

/// Largeur minimale d'une colonne latérale.
///
/// DÉRIVÉE de `kCompactShortEdge`, et non plus de `kZoneShortEdgeFloor`
/// (spec §1.1) : une colonne au plancher absolu tombait au cran `minimal`,
/// donc sans nom ni compteurs, pendant que son voisin de face avait cinq
/// fois la surface. Une colonne se paie désormais au cran `compact`, ou ne
/// se prend pas.
const double kSideColumnNeed = kCompactShortEdge + 26.0;
```

Ajouter `import 'density_tier.dart';` s'il n'est pas déjà présent (il l'est, pour `kZoneShortEdgeFloor`).

- [ ] **Step 7: Lancer les tests de disposition**

Run: `flutter test test/widgets/life_counter/layouts/table_layout_test.dart`
Expected: PASS. Des tests préexistants sur les colonnes à 4 joueurs vont échouer — c'est attendu : ils encodent le comportement que cette tâche supprime. Les mettre à jour pour 6 joueurs, et ajouter un commentaire renvoyant au §1.1 de la spec.

- [ ] **Step 8: Lancer toute la suite**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 9: Vérifier que les tests sont discriminants**

Inverser la comparaison dans `arrangementFor` (`zone.height < zone.width`), relancer, constater deux FAIL nommant les deux tailles d'écran, puis rétablir.

- [ ] **Step 10: Commit**

```bash
git add lib/models/table_seat.dart lib/widgets/life_counter/layouts/table_layout.dart test/widgets/life_counter/layouts/table_layout_test.dart
git commit -m "feat(life-counter): regle du grand cote et equite des surfaces"
```

---

## Task 4: Rotation à propriétaire unique

**Files:**
- Modify: `lib/providers/game_session_notifier.dart:198-205`
- Test: `test/providers/game_session_rotation_test.dart`

**Interfaces:**
- Consumes: `seatsForArrangement`, `arrangementFor`, `TableSeat.quarterTurns` (Tâche 3).
- Produces: `void seedRotationsFromSeats(List<TableSeat> seats)` sur `GameSessionNotifier`.

**Qui appelle quoi :** `life_counter_page.dart` appelle `seedRotationsFromSeats(layout.seats)` à chaque fois que `tableLayoutFor` renvoie un layout dont les sièges diffèrent du précédent — c'est-à-dire au démarrage d'une partie, à la rotation de l'appareil, et au dépliage. `updateRotation` reste le seul chemin pour une rotation choisie à la main (Tâche 8), et elle écrase la valeur semée.

- [ ] **Step 1: Écrire le test**

```dart
// test/providers/game_session_rotation_test.dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

void main() {
  /// Table de référence de la convention : `RotatedBox` tourne dans le sens
  /// horaire, un joueur assis à gauche regarde vers la droite.
  const expected = {
    TableSide.bottom: 0,
    TableSide.left: 1,
    TableSide.top: 2,
    TableSide.right: 3,
  };

  test('la rotation d un siège ne vient que de son côté, 2 à 6 joueurs', () {
    for (final size in const [Size(390, 844), Size(840, 700)]) {
      for (int n = 2; n <= 6; n++) {
        for (final seat in tableLayoutFor(size, n).seats) {
          expect(seat.quarterTurns, expected[seat.side],
              reason: '$n joueurs sur $size, côté ${seat.side}');
        }
      }
    }
  });

  test('une zone plus haute que large reçoit un quart de tour', () {
    final layout = tableLayoutFor(const Size(390, 844), 4);
    expect(layout.seats.every((s) => s.quarterTurns.isOdd), isTrue);
  });

  test('une zone plus large que haute ne reçoit pas de quart de tour', () {
    final layout = tableLayoutFor(const Size(840, 700), 4);
    expect(layout.seats.every((s) => s.quarterTurns.isEven), isTrue);
  });
}
```

- [ ] **Step 2: Lancer, vérifier que les deux derniers échouent**

Run: `flutter test test/providers/game_session_rotation_test.dart`
Expected: le test « plus haute que large » FAIL tant que la Tâche 3 n'est pas branchée sur la page ; s'il passe déjà, c'est que la Tâche 3 est complète — poursuivre.

- [ ] **Step 3: Ajouter `seedRotationsFromSeats`**

Dans `game_session_notifier.dart`, sous `updateRotation` :

```dart
  /// Applique aux joueurs les rotations que leur donne la disposition.
  ///
  /// La rotation n'a qu'un seul propriétaire (spec §1.4, et §2.1 de la spec
  /// table multijoueur v2) : `TableSeat.quarterTurns`. Ce point d'entrée
  /// existe pour que `player.quarterTurns`, qui est persisté, reste un
  /// CACHE de cette dérivation, jamais une seconde vérité.
  ///
  /// Une rotation choisie à la main par l'utilisateur passe par
  /// `updateRotation` et écrase la valeur semée : c'est délibéré, la règle
  /// du grand côté donne un défaut, pas un verdict.
  void seedRotationsFromSeats(List<TableSeat> seats) {
    final players = state.players;
    if (players.length != seats.length) return;
    state = state.copyWith(
      players: [
        for (int i = 0; i < players.length; i++)
          players[i].quarterTurns == seats[i].quarterTurns
              ? players[i]
              : players[i].copyWith(quarterTurns: seats[i].quarterTurns),
      ],
    );
  }
```

Ajouter `import '../models/table_seat.dart';`.

- [ ] **Step 4: Appeler depuis `life_counter_page.dart`**

Dans le `build` de la page, là où `tableLayoutFor` est déjà appelé, après l'obtention du `layout` :

```dart
    // Les rotations suivent la disposition. Posté hors de la phase de build
    // pour ne pas modifier un provider pendant qu'on construit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gameSessionProvider.notifier).seedRotationsFromSeats(layout.seats);
    });
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/providers/game_session_rotation_test.dart && flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/game_session_notifier.dart lib/pages/life_counter/life_counter_page.dart test/providers/game_session_rotation_test.dart
git commit -m "fix(life-counter): la rotation n'a qu'un seul proprietaire"
```

---

## Task 5: Repères des moitiés et moitié touchée

**Files:**
- Modify: `lib/widgets/life_counter/zone/life_dial.dart`
- Test: `test/widgets/life_counter/zone/life_dial_affordance_test.dart`

**Interfaces:**
- Consumes: rien de neuf.
- Produces: aucune API publique nouvelle — un changement de rendu interne à `LifeDial`.

**Qui appelle quoi :** personne de nouveau. `LifeDial` est déjà monté par `player_zone.dart` dans le `RotatedBox`, donc les repères héritent de la rotation de la zone sans code supplémentaire. C'est pour cela qu'ils vont DANS `LifeDial` et non dans `PlayerZone`.

- [ ] **Step 1: Écrire le test**

```dart
// test/widgets/life_counter/zone/life_dial_affordance_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

/// Harnais minimal : un `LifeDial` seul, dans une boîte de taille connue.
/// `onDelta` est obligatoire ; on l'ignore ici, ces tests portent sur le
/// rendu et non sur l'émission.
Widget harness() => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: LifeDial(
                life: 40,
                onDelta: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('chaque moitié porte son repère', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('−'), findsOneWidget); // le signe moins typographique
    expect(find.text('+'), findsOneWidget);
  });

  testWidgets('la moitié touchée s éclaircit tant que le doigt est posé',
      (tester) async {
    await tester.pumpWidget(harness());
    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LifeDial)) - const Offset(40, 0));
    await tester.pump();

    final highlight = tester.widget<Container>(
        find.byKey(const Key('life-dial-highlight-minus')));
    expect((highlight.decoration as BoxDecoration).color?.a, greaterThan(0.0));

    await gesture.up();
    await tester.pumpAndSettle();
    final after = tester.widget<Container>(
        find.byKey(const Key('life-dial-highlight-minus')));
    expect((after.decoration as BoxDecoration).color?.a ?? 0.0, 0.0);
  });
}
```

**Note sur le harnais :** la signature exacte de `LifeDial` n'a pas été
relevée au moment d'écrire ce plan. Ouvrir `life_dial.dart`, lire son
constructeur, et ajuster `harness()` à ses paramètres requis avant de
lancer. Le reste du test ne dépend pas de la signature.

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/widgets/life_counter/zone/life_dial_affordance_test.dart`
Expected: FAIL — ni les repères ni les clés n'existent.

- [ ] **Step 3: Ajouter l'état de pression**

Dans `_LifeDialState`, à côté de `_pendingTaps` :

```dart
  /// Moitié actuellement sous le doigt : -1, +1, ou 0 si aucune.
  ///
  /// Sur mobile il n'y a pas de survol. Cet état est l'équivalent tactile :
  /// il dit « c'est bien cette moitié que tu viens de toucher », ce que rien
  /// n'indiquait avant — d'où des taps qui semblaient ne rien faire.
  int _pressedHalf = 0;
```

L'affecter dans `_startHold(delta)` (`_pressedHalf = delta;` suivi de `setState`), et le remettre à 0 dans `_confirmTap`, `_cancelPress` et `_clearPending`.

- [ ] **Step 4: Rendre les repères et le voile**

Dans le `build`, empiler sous le chiffre, à l'intérieur du même repère que les moitiés :

```dart
        // Repères permanents, posés vers les bords extérieurs pour ne jamais
        // croiser le chiffre. Opacité basse : ils informent, ils ne décorent
        // pas.
        Positioned.fill(
          child: IgnorePointer(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    key: const Key('life-dial-highlight-minus'),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: _pressedHalf == -1
                          ? AppColors.textPrimary.withValues(alpha: 0.14)
                          : AppColors.transparent,
                      border: Border(
                        right: BorderSide(
                          color: AppColors.textPrimary.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    child: Text('−',
                        style: AppTextStyles.text(
                            fontSize: 34,
                            color: AppColors.textPrimary
                                .withValues(alpha: 0.34))),
                  ),
                ),
                Expanded(
                  child: Container(
                    key: const Key('life-dial-highlight-plus'),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: _pressedHalf == 1
                          ? AppColors.textPrimary.withValues(alpha: 0.14)
                          : AppColors.transparent,
                    ),
                    child: Text('+',
                        style: AppTextStyles.text(
                            fontSize: 34,
                            color: AppColors.textPrimary
                                .withValues(alpha: 0.34))),
                  ),
                ),
              ],
            ),
          ),
        ),
```

Le `IgnorePointer` est indispensable : sans lui, cette couche volerait les événements à l'arène de gestes déjà réglée au prix fort dans ce fichier.

- [ ] **Step 5: Lancer**

Run: `flutter test test/widgets/life_counter/zone/life_dial_affordance_test.dart && flutter test`
Expected: PASS. Si un test existant de `life_dial` échoue sur le nombre de `Container`, l'ajuster en ciblant par `Key`.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/life_counter/zone/life_dial.dart test/widgets/life_counter/zone/life_dial_affordance_test.dart
git commit -m "feat(life-counter): rend les deux moities visibles et reactives"
```

---

## Task 6: Delta cumulé, lisible à distance de table

**Files:**
- Modify: `lib/providers/player_zone_notifier.dart`
- Create: `lib/widgets/life_counter/zone/pending_delta.dart`
- Modify: `lib/widgets/life_counter/player_zone.dart:430-440`
- Test: `test/providers/pending_delta_test.dart`

**Interfaces:**
- Consumes: `kDamageBufferWindow` (Tâche 2).
- Produces: `int pendingDelta` sur `PlayerZoneState` ; `void accumulate(int change)` et `void clearPendingDelta()` sur `PlayerZoneNotifier` ; `class PendingDelta extends StatelessWidget` prenant `{required int delta, required double totalFontSize}`.

**Qui appelle quoi :** `player_zone.dart` appelle `accumulate(change)` au même endroit où il appelle déjà `_showFloatingNumber(change)` (ligne 216), et monte `PendingDelta` dans la même pile que `LifeLog`. Les deux coexistent : `LifeLog` montre l'événement qui monte et s'efface, `PendingDelta` montre le cumul qui reste pendant la fenêtre. Ce sont deux informations différentes, et c'est la seconde qui manquait.

- [ ] **Step 1: Écrire le test**

```dart
// test/providers/pending_delta_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/widgets/life_counter/tuning.dart';

void main() {
  test('les changements successifs se cumulent', () {
    final notifier = PlayerZoneNotifier();
    notifier.accumulate(-3);
    notifier.accumulate(-4);
    expect(notifier.state.pendingDelta, -7);
  });

  test('un gain et une perte s annulent', () {
    final notifier = PlayerZoneNotifier();
    notifier.accumulate(5);
    notifier.accumulate(-5);
    expect(notifier.state.pendingDelta, 0);
  });

  test('le cumul est vidé à la fermeture de la fenêtre', () {
    fakeAsync((async) {
      final notifier = PlayerZoneNotifier();
      notifier.accumulate(-3);
      async.elapse(kDamageBufferWindow + const Duration(milliseconds: 50));
      expect(notifier.state.pendingDelta, 0);
    });
  });

  test('un nouveau changement relance la fenêtre', () {
    fakeAsync((async) {
      final notifier = PlayerZoneNotifier();
      notifier.accumulate(-3);
      async.elapse(kDamageBufferWindow ~/ 2);
      notifier.accumulate(-2);
      async.elapse(kDamageBufferWindow ~/ 2 + const Duration(milliseconds: 50));
      expect(notifier.state.pendingDelta, -5,
          reason: 'la fenêtre doit repartir à chaque changement');
    });
  });
}
```

Ajouter `fake_async` aux `dev_dependencies` du `pubspec.yaml` s'il n'y est pas, et importer `package:fake_async/fake_async.dart`.

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/providers/pending_delta_test.dart`
Expected: FAIL — `pendingDelta` et `accumulate` n'existent pas.

- [ ] **Step 3: Étendre l'état**

Dans `PlayerZoneState`, ajouter le champ `final int pendingDelta;`, avec `this.pendingDelta = 0` au constructeur et `pendingDelta: pendingDelta ?? this.pendingDelta` dans `copyWith`.

- [ ] **Step 4: Ajouter l'accumulation**

Dans `PlayerZoneNotifier` :

```dart
  Timer? _pendingDeltaTimer;

  /// Cumule un changement de vie dans la fenêtre courante.
  ///
  /// Distinct de `showFloatingNumber`, qui montre l'ÉVÉNEMENT — un nombre
  /// qui monte et s'efface. Ici on montre le BILAN : ce que le joueur a
  /// perdu ou gagné depuis le début de la salve, qui reste affiché tant que
  /// la salve dure. C'est l'information qu'on cherche quand trois personnes
  /// attaquent en même temps, et elle n'existait pas.
  void accumulate(int change) {
    _pendingDeltaTimer?.cancel();
    state = state.copyWith(pendingDelta: state.pendingDelta + change);
    _pendingDeltaTimer = Timer(kDamageBufferWindow, clearPendingDelta);
  }

  void clearPendingDelta() {
    _pendingDeltaTimer?.cancel();
    _pendingDeltaTimer = null;
    state = state.copyWith(pendingDelta: 0);
  }

  @override
  void dispose() {
    _pendingDeltaTimer?.cancel();
    super.dispose();
  }
```

Ajouter `import 'dart:async';` et `import '../widgets/life_counter/tuning.dart';`.

- [ ] **Step 5: Lancer, vérifier le succès**

Run: `flutter test test/providers/pending_delta_test.dart`
Expected: PASS.

- [ ] **Step 6: Créer le widget**

```dart
// lib/widgets/life_counter/zone/pending_delta.dart
// Bilan de la salve en cours, posé contre le total.
//
// Taille : la MOITIÉ du total (spec §1.8). Le delta est la deuxième
// information la plus importante de la zone, après le total lui-même ; il
// était auparavant rendu à 48 px fixes par `LifeLog`, donc illisible depuis
// l'autre bout de la table sur un grand écran, et disproportionné sur un
// petit.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

class PendingDelta extends StatelessWidget {
  const PendingDelta({
    super.key,
    required this.delta,
    required this.totalFontSize,
  });

  final int delta;
  final double totalFontSize;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) return const SizedBox.shrink();
    final isLoss = delta < 0;
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Text(
        isLoss ? '−${-delta}' : '+$delta',
        style: AppTextStyles.bold(
          fontSize: totalFontSize / 2,
          color: isLoss ? AppColors.feedbackDanger : AppColors.feedbackSuccess,
        ),
      ),
    );
  }
}
```

Si `AppColors.feedbackDanger` et `AppColors.feedbackSuccess` n'existent pas encore, les ajouter dans `app_colors.dart` avec les valeurs de la spec DA — `#FF7A6E` et `#6FD98F` — et NON les `AppColors.error` / `AppColors.success` existants, qui valent du Material partagé avec les couleurs de mana.

- [ ] **Step 7: Monter le widget**

Dans `player_zone.dart`, ligne 216, à côté de `_showFloatingNumber(change);` :

```dart
    _notifier.accumulate(change);
```

Puis, dans la rangée qui affiche le total (dans `buildContent`), placer `PendingDelta` juste après le `Text` du total, dans une `Row` avec `mainAxisAlignment: MainAxisAlignment.center` :

```dart
                      PendingDelta(
                        delta: ref
                            .watch(playerZoneNotifierProvider(widget.player.playerId))
                            .pendingDelta,
                        totalFontSize: lifeFontSize,
                      ),
```

en réutilisant la variable de taille de police déjà calculée pour le total.

- [ ] **Step 8: Lancer toute la suite**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/providers/player_zone_notifier.dart lib/widgets/life_counter/zone/pending_delta.dart lib/widgets/life_counter/player_zone.dart lib/theme/app_colors.dart test/providers/pending_delta_test.dart pubspec.yaml
git commit -m "feat(life-counter): affiche le bilan de la salve en cours"
```

---

## Task 7: Modales orientées vers leur siège

**Files:**
- Create: `lib/widgets/life_counter/zone/seated_sheet.dart`
- Modify: `lib/widgets/life_counter/zone/player_drawer.dart:94`
- Modify: `lib/widgets/life_counter/zone/counter_editor_dialog.dart:46`
- Test: `test/widgets/life_counter/zone/seated_sheet_test.dart`

**Interfaces:**
- Consumes: `TableSeat` (Tâche 3), `quarterTurns` du joueur (Tâche 4).
- Produces: `Future<T?> showSeatedSheet<T>({required BuildContext context, required int quarterTurns, required WidgetBuilder builder})`.

**Qui appelle quoi :** `player_drawer.dart` remplace son `showModalBottomSheet` par `showSeatedSheet`, et `counter_editor_dialog.dart` remplace son `showDialog`. Ce sont les deux seuls appelants. `player_zone.dart`, qui les invoque, leur passe `widget.player.quarterTurns` — il l'a déjà sous la main pour son `RotatedBox`.

- [ ] **Step 1: Écrire le test**

```dart
// test/widgets/life_counter/zone/seated_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/seated_sheet.dart';

void main() {
  testWidgets('la feuille porte la rotation de son siège', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      }),
    ));

    showSeatedSheet<void>(
      context: ctx,
      quarterTurns: 2,
      builder: (_) => const Text('contenu'),
    );
    await tester.pumpAndSettle();

    final rotated = tester.widget<RotatedBox>(find.ancestor(
      of: find.text('contenu'),
      matching: find.byType(RotatedBox),
    ));
    expect(rotated.quarterTurns, 2);
  });

  testWidgets('un siège du bas se comporte comme une feuille ordinaire',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      }),
    ));

    showSeatedSheet<void>(
      context: ctx,
      quarterTurns: 0,
      builder: (_) => const Text('contenu'),
    );
    await tester.pumpAndSettle();

    final rotated = tester.widget<RotatedBox>(find.ancestor(
      of: find.text('contenu'),
      matching: find.byType(RotatedBox),
    ));
    expect(rotated.quarterTurns, 0);
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/widgets/life_counter/zone/seated_sheet_test.dart`
Expected: FAIL — le fichier n'existe pas.

- [ ] **Step 3: Créer `seated_sheet.dart`**

```dart
// lib/widgets/life_counter/zone/seated_sheet.dart
// Surface modale qui appartient à un joueur, et non à l'écran.
//
// Avant : `player_drawer` ouvrait un `showModalBottomSheet` (toujours par
// le bas) et `counter_editor_dialog` un `showDialog` (toujours au centre).
// Ni l'un ni l'autre ne savait à quel siège il appartenait, donc le joueur
// d'en face saisissait ses dégâts de commandant sur un panneau à l'envers,
// ou faisait tourner le téléphone.
//
// Ici, la feuille prend la rotation de son siège et surgit depuis SON bord.
// Pour un joueur du bas (quarterTurns == 0), le comportement observable est
// exactement celui d'avant.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Ouvre [builder] orienté pour un siège à [quarterTurns] quarts de tour.
Future<T?> showSeatedSheet<T>({
  required BuildContext context,
  required int quarterTurns,
  required WidgetBuilder builder,
}) {
  final turns = quarterTurns % 4;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.overlayDark,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return RotatedBox(
        quarterTurns: turns,
        // Après rotation, le « bas » de l'enfant est le bord du siège :
        // aligner en bas suffit, la rotation place la feuille du bon côté
        // de l'écran. C'est pour cela qu'il n'y a pas de table de bords ici.
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: AppColors.dialogBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(top: false, child: builder(context)),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `flutter test test/widgets/life_counter/zone/seated_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Brancher `player_drawer.dart`**

Ligne 94, remplacer :

```dart
  return showSeatedSheet<void>(
    context: context,
    quarterTurns: quarterTurns,
    builder: (context) => drawerBody,
  );
```

où `drawerBody` est **exactement** le widget que le `builder` de
`showModalBottomSheet` construisait avant — déplacé tel quel, sans aucune
retouche de son contenu. Ne pas en profiter pour réorganiser le tiroir :
cette tâche ne change que la surface qui le porte, et une modification du
contenu rendrait toute régression indiscernable.

Retirer les paramètres propres à `showModalBottomSheet`
(`isScrollControlled`, `backgroundColor`, `shape`) : `showSeatedSheet` pose
déjà la couleur, le rayon et le `SafeArea`.

La fonction d'ouverture du tiroir gagne un paramètre `required int quarterTurns`, et `player_zone.dart` lui passe `widget.player.quarterTurns` à son site d'appel.

- [ ] **Step 6: Brancher `counter_editor_dialog.dart`**

Ligne 46, remplacer `showDialog<CounterType>` par `showSeatedSheet<CounterType>`, en lui passant le même `quarterTurns`, propagé depuis `player_zone.dart`.

- [ ] **Step 7: Lancer toute la suite**

Run: `flutter test && flutter analyze`
Expected: PASS. Des tests existants qui cherchaient un `BottomSheet` ou un `Dialog` doivent viser `find.byType(RotatedBox)` ou le contenu lui-même.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/life_counter/zone/seated_sheet.dart lib/widgets/life_counter/zone/player_drawer.dart lib/widgets/life_counter/zone/counter_editor_dialog.dart lib/widgets/life_counter/player_zone.dart test/widgets/life_counter/zone/seated_sheet_test.dart
git commit -m "feat(life-counter): modales orientees vers leur siege"
```

---

## Task 8: Mode réorganisation, flèches et presets

**Files:**
- Create: `lib/widgets/life_counter/zone/orientation_picker.dart`
- Create: `lib/widgets/life_counter/reorganise_bar.dart`
- Modify: `lib/widgets/life_counter/draggable_player_zone.dart`
- Modify: `lib/providers/game_session_notifier.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart`
- Test: `test/widgets/life_counter/reorganise_mode_test.dart`

**Interfaces:**
- Consumes: `updateRotation` et `seedRotationsFromSeats` (Tâche 4), `TableArrangement` (Tâche 3).
- Produces: `enum OrientationPreset { faceToFace, sides, circle, sameWay }` ; `void applyOrientationPreset(OrientationPreset preset)` sur `GameSessionNotifier` ; `class OrientationPicker extends StatelessWidget` prenant `{required int quarterTurns, required ValueChanged<int> onChanged}` ; `class ReorganiseBar extends StatelessWidget` prenant `{required ValueChanged<OrientationPreset> onPreset, required VoidCallback onDone}`.

**Qui appelle quoi :** `life_counter_page.dart` porte un champ `bool _isReorganising`, le passe à chaque `DraggablePlayerZone` via un nouveau paramètre `required bool enabled`, et monte `ReorganiseBar` en pied quand il vaut `true`. `DraggablePlayerZone` monte `OrientationPicker` sur sa zone quand `enabled` est vrai, et `OrientationPicker.onChanged` appelle `updateRotation(playerId, turns)`. `ReorganiseBar.onPreset` appelle `applyOrientationPreset`. Le bouton qui active le mode vit dans l'`ActionHub` et dans la bande d'actions, là où se trouvent déjà les neuf actions.

- [ ] **Step 1: Écrire le test**

```dart
// test/widgets/life_counter/reorganise_mode_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/draggable_player_zone.dart';

void main() {
  testWidgets('hors mode réorganisation, la zone ne se glisse pas',
      (tester) async {
    int reorders = 0;
    await tester.pumpWidget(MaterialApp(
      home: DraggablePlayerZone(
        index: 0,
        enabled: false,
        onReorder: (_, __) => reorders++,
        child: const SizedBox(width: 200, height: 200),
      ),
    ));

    await tester.drag(find.byType(DraggablePlayerZone), const Offset(0, 220));
    await tester.pumpAndSettle();
    expect(reorders, 0, reason: 'le glissement doit être inerte en mode jeu');
  });

  testWidgets('en mode réorganisation, le sélecteur d orientation apparaît',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DraggablePlayerZone(
        index: 0,
        enabled: true,
        onReorder: (_, __) {},
        child: const SizedBox(width: 200, height: 200),
      ),
    ));

    expect(find.byType(OrientationPicker), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/widgets/life_counter/reorganise_mode_test.dart`
Expected: FAIL — `enabled` n'est pas un paramètre de `DraggablePlayerZone`.

- [ ] **Step 3: Créer `orientation_picker.dart`**

```dart
// lib/widgets/life_counter/zone/orientation_picker.dart
// Quatre flèches : le bord vers lequel le joueur regarde.
//
// Remplace un bouton qui faisait tourner la zone d'un quart de tour par
// appui. Pour atteindre 270° il fallait taper trois fois, et rien
// n'indiquait où l'on allait. Ici, une touche suffit pour n'importe quelle
// orientation, et la flèche active dit où l'on est.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

class OrientationPicker extends StatelessWidget {
  const OrientationPicker({
    super.key,
    required this.quarterTurns,
    required this.onChanged,
  });

  final int quarterTurns;
  final ValueChanged<int> onChanged;

  /// Quarts de tour correspondant à chaque direction de regard.
  /// Même convention que `TableSeat.quarterTurns` : `RotatedBox` tourne dans
  /// le sens horaire, un joueur assis à gauche regarde vers la droite.
  static const Map<int, (IconData, String)> _directions = {
    0: (Icons.keyboard_arrow_down, 'Regarde vers le bas'),
    1: (Icons.keyboard_arrow_left, 'Regarde vers la gauche'),
    2: (Icons.keyboard_arrow_up, 'Regarde vers le haut'),
    3: (Icons.keyboard_arrow_right, 'Regarde vers la droite'),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final entry in _directions.entries)
          IconButton(
            // 48x48 minimum : c'est le defaut que cette refonte existe pour
            // eliminer, on ne le reintroduit pas ici.
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: entry.value.$2,
            onPressed: () => onChanged(entry.key),
            icon: Icon(
              entry.value.$1,
              color: entry.key == quarterTurns % 4
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Créer `reorganise_bar.dart`**

```dart
// lib/widgets/life_counter/reorganise_bar.dart
// Barre de mode : on sait qu'on réorganise, et comment en sortir.
//
// Avant, le réordonnancement était toujours actif : `DraggablePlayerZone`
// acceptait un glisser-déposer en pleine partie. Déplacer un joueur en
// croyant lui retirer un point de vie était non seulement possible, mais
// facile.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

enum OrientationPreset { faceToFace, sides, circle, sameWay }

const Map<OrientationPreset, String> kPresetLabels = {
  OrientationPreset.sides: 'Côtés',
  OrientationPreset.faceToFace: 'Face-à-face',
  OrientationPreset.circle: 'Cercle',
  OrientationPreset.sameWay: 'Même sens',
};

class ReorganiseBar extends StatelessWidget {
  const ReorganiseBar({
    super.key,
    required this.onPreset,
    required this.onDone,
  });

  final ValueChanged<OrientationPreset> onPreset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.drag_handle, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Réorganisation',
                  style: AppTextStyles.bold(
                      fontSize: 15, color: AppColors.primary)),
              const SizedBox(width: 10),
              Text('le décompte est suspendu',
                  style: AppTextStyles.text(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in kPresetLabels.entries)
                OutlinedButton(
                  onPressed: () => onPreset(entry.key),
                  child: Text(entry.value),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onDone, child: const Text('Terminé')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rendre `DraggablePlayerZone` conditionnel**

Ajouter `required this.enabled` et le champ `final bool enabled;`. Dans le `build`, n'envelopper dans `Draggable`/`DragTarget` que si `enabled` est vrai ; sinon rendre l'enfant nu. Quand `enabled` est vrai, empiler par-dessus l'enfant un voile `AppColors.overlayMedium`, une bordure en tirets, et `OrientationPicker`.

- [ ] **Step 6: Ajouter `applyOrientationPreset`**

Dans `game_session_notifier.dart` :

```dart
  /// Applique un agencement connu à toute la table.
  ///
  /// Les presets « Côtés », « Triangle » et « Cercle » avaient été supprimés
  /// au lot 6 sans mandat ; la spec table multijoueur v2 (§9) laissait leur
  /// sort en question ouverte. L'utilisateur les a redemandés le 18/10/2026.
  void applyOrientationPreset(OrientationPreset preset) {
    final players = state.players;
    final n = players.length;
    List<int> turns;
    switch (preset) {
      case OrientationPreset.sameWay:
        turns = List.filled(n, 0);
      case OrientationPreset.faceToFace:
        final top = n ~/ 2;
        turns = [for (int i = 0; i < n; i++) i < top ? 2 : 0];
      case OrientationPreset.sides:
        turns = [for (int i = 0; i < n; i++) i.isEven ? 1 : 3];
      case OrientationPreset.circle:
        // Un joueur par bord, dans l'ordre horaire bas → gauche → haut →
        // droite, qui est l'ordre de `TableSeat.quarterTurns`.
        turns = [for (int i = 0; i < n; i++) i % 4];
    }
    state = state.copyWith(players: [
      for (int i = 0; i < n; i++) players[i].copyWith(quarterTurns: turns[i]),
    ]);
  }
```

- [ ] **Step 7: Porter l'état dans la page**

Dans `_LifeCounterPageState`, ajouter `bool _isReorganising = false;`. Passer `enabled: _isReorganising` à chaque `DraggablePlayerZone` (ligne ~1038). Monter `ReorganiseBar` en pied de l'arbre quand `_isReorganising`, avec `onDone: () => setState(() => _isReorganising = false)` et `onPreset: (p) => _controller.applyOrientationPreset(p)`. L'action qui entre dans le mode est ajoutée à l'`ActionHub` et à la bande ; `kActionCount` passe de 9 à 10 dans `table_layout.dart`, sans quoi `kBandNeed` sous-estimera de nouveau la largeur réelle de la bande — c'est exactement le défaut documenté sur `kActionWidth`.

- [ ] **Step 8: Lancer toute la suite**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 9: Vérifier que le test est discriminant**

Forcer `enabled` à `true` dans `DraggablePlayerZone`, relancer, constater le FAIL du premier test, puis rétablir.

- [ ] **Step 10: Commit**

```bash
git add lib/widgets/life_counter/zone/orientation_picker.dart lib/widgets/life_counter/reorganise_bar.dart lib/widgets/life_counter/draggable_player_zone.dart lib/providers/game_session_notifier.dart lib/pages/life_counter/life_counter_page.dart lib/widgets/life_counter/layouts/table_layout.dart test/widgets/life_counter/reorganise_mode_test.dart
git commit -m "feat(life-counter): mode reorganisation explicite, fleches et presets"
```

---

## Hors de ce plan, et pourquoi

**Les 6 à 8 illustrations embarquées du §1.3 ne sont pas produites ici.**
`PlayerSkin.assetPath` existe, mais rien ne le lit, et toutes les entrées
de `kPlayerSkins` valent `null` à la fin de ce plan : les zones portent les
nouvelles couleurs de terrain, pas encore de fond illustré. Les visuels
sont un livrable de direction artistique, pas de code — et ils ne peuvent
pas être des arts de cartes Magic, qui appartiennent à Wizards of the Coast
et ne sont pas redistribuables dans le binaire.

Quand les fichiers existent, les déposer dans
`assets/images/player_skins/`, les déclarer dans `pubspec.yaml`, et
renseigner `assetPath` sur chaque entrée. Cela ne suffira PAS : aucun
code ne lit ce champ aujourd'hui. Le fond d'une zone vient de
`buildPlayerBackground` (`zone/player_skin_picker.dart`), qui ne connaît que
`Player.backgroundImagePath` et la couleur ; il faudra brancher un
consommateur qui passe de la teinte choisie à son `assetPath` (par exemple
au choix d'une couleur dans le sélecteur, ou au rendu du fond). Le champ est
posé dès la Tâche 1 pour fixer la forme des données, pas le câblage.

---

## Validation visuelle — bloquante

La suite verte ne clôt pas ce chantier. Un lot déplaçant des pixels a déjà
été reverté sur ce projet après 1 028 tests verts.

Avant de déclarer le chantier terminé, produire et EXAMINER ces captures :

- [ ] Table 4 joueurs, écran déplié : quatre quadrants égaux, hub au croisement.
- [ ] Table 4 joueurs, écran replié : colonne gauche à 90°, colonne droite à 270°, chiffres lisibles en travers de la table.
- [ ] Table 6 joueurs : colonnes latérales au cran `compact`, nom visible.
- [ ] Repères `−` / `+` sur une zone de chaque orientation.
- [ ] Moitié touchée éclaircie, doigt posé.
- [ ] Delta cumulé, en perte et en gain.
- [ ] Tiroir et dégâts de commandant ouverts depuis chacun des quatre sièges.
- [ ] Mode réorganisation : une capture dedans, une dehors.

**Le sens de rotation du §1.4 se confirme à l'œil sur le Pixel Fold.** Il est
conforme à la convention documentée de `TableSeat.quarterTurns` (`left => 1`,
`right => 3`), mais personne ne l'a encore vu avec quatre joueurs assis. Si
les colonnes se lisent à l'envers, c'est un échange de `1` et `3` dans
`_columnPairs`, et rien d'autre.
