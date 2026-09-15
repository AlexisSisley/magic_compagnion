# Life Counter V4 — Lot 2 : Zone joueur — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer la zone joueur en surface minimale gestuelle — le chiffre de PV occupe tout, les compteurs partent dans un tiroir, et un mode ajustement sur appui long permet de saisir de gros montants.

**Architecture:** La zone perd ses modes de compteur ; elle n'affiche plus que les PV. Trois nouveaux widgets prennent en charge le geste (`LifeDial`), l'affichage d'état (`ConditionalHandle`) et tout le reste (`PlayerDrawer`). `PlayerZoneController` est réécrit pour ce modèle. `player_zone.dart` passe de 734 lignes à un assemblage.

**Tech Stack:** Flutter (SDK ^3.9.2), `flutter_riverpod` ^3.0.3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md` (§2.1 à §2.5, §2.7, §3.3)

## Global Constraints

- Dart SDK `^3.9.2`, `flutter_riverpod` `^3.0.3` — ne pas ajouter de dépendance.
- Branche à créer depuis `main` **après merge de la PR #2** (lot 1).
- Style maison des notifiers : `class XNotifier extends Notifier<T>` avec `T build()`, exposé par `NotifierProvider<XNotifier, T>(XNotifier.new)`. Référence : `lib/providers/collection_value_provider.dart:65` et `:194`.
- Couleurs et typographie : `AppColors` et `AppTextStyles` uniquement (`lib/theme/`). Aucune couleur littérale.
- `flutter analyze` propre sur les fichiers touchés ; `flutter test` vert (844 tests au départ).
- Pas de `// ignore_for_file:` ; seulement des `// ignore:` ciblés ligne à ligne.
- **`ref.watch(gameSessionNotifierProvider)` doit rester la toute première instruction de `build()`** dans `life_counter_page.dart` — un early-return au-dessus romprait la réactivité de toute la page en silence (avertissement en place depuis le lot 1).
- **Aucun nouveau hook `@visibleForTesting`.** Le lot 1 en a laissé quatre ; chaque responsabilité extraite doit en faire disparaître un, pas en ajouter.
- Messages de commit terminés par : `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

---

## Deux corrections à la spec, décidées avant rédaction

### `PlayerZoneController` est à réécrire, pas à brancher

La spec §3.3 annonce que `PlayerZone` « est branchée sur `PlayerZoneController` (déjà écrit, déjà testé) ». **C'est inexact.** Le contrôleur (`lib/controllers/player_zone_controller.dart`, 241 lignes) est bâti sur le modèle d'interaction V3, celui des **modes de compteur** :

- `enum CounterMode { life, poison, energy, commanderTax }` (`:10`)
- `setEditMode(CounterMode)` (`:83`)
- `triggerChange(...)` qui applique le changement au compteur actif (`:91-121`)
- `getDisplayValue(...)` qui fait afficher le compteur actif dans le gros chiffre (`:162-178`)
- `getModeColor` / `getModeIcon` (`:182-206`)

La zone V4 (spec §2.1) supprime cette mécanique : le chiffre n'affiche **que** les PV, et les compteurs vivent dans le tiroir. Le contrôleur ne peut donc pas être branché tel quel.

**Réutilisable :** `FloatingNumber` et son cycle de vie (`:14-28`, `:125-158`), et la rotation (`:211-233`). Soit environ 40 % du fichier. Le reste est supprimé, et la part correspondante de ses 202 lignes de tests avec.

La tâche 1 réécrit le contrôleur. L'argument économique de la spec §1 (« connecter le code déjà écrit ») reste valable pour `GameSetupController` et `StatsTab`, pas pour celui-ci.

### Le tiroir démarre au lot 2, pas au lot 3

La spec §2.5 déménage le menu radial dans le tiroir, parce que le mode ajustement lui prend son appui long. Or la spec §4 range le tiroir au lot 3. Le lot 2 retirerait donc au menu radial son geste sans lui donner de domicile.

**Décision :** le lot 2 construit la **coquille** du tiroir — compteurs (poison, énergie, taxe) et actions (monarque, éliminer, réinitialiser). Le lot 3 la remplit avec la grille de commander damage et la vue table. Le menu radial déménage une seule fois, rien n'est jeté, et chaque lot reste livrable seul.

---

## Carte des gestes visée

| Geste | Action | Tâche |
|---|---|---|
| Tap moitié gauche / droite | −1 / +1 | 2 |
| Maintien sur une moitié | Répétition accélérée | 2 |
| Appui long (centre) | Entrée en mode ajustement | 3 |
| Glissement vertical en mode ajustement | Molette | 3 |
| Boutons ±5 / ±10 en mode ajustement | Paliers | 3 |
| Glissement depuis la poignée | Ouverture du tiroir | 5 |
| Glissement sur l'en-tête | Rotation de la zone | 1 (conservé) |
| Deux doigts (global) | Vue table | **lot 3** |

---

## File Structure

**Créés :**

| Fichier | Responsabilité |
|---|---|
| `lib/widgets/life_counter/zone/life_dial.dart` | Surface de geste des PV : moitiés de tap, répétition au maintien, mode ajustement (molette + paliers). Ne connaît que `life` et un callback de delta. |
| `lib/widgets/life_counter/zone/conditional_handle.dart` | Poignée P2 : trait fin quand tout est à zéro, bandeau résumé sinon. Hauteur réservée en permanence. |
| `lib/widgets/life_counter/zone/player_drawer.dart` | Coquille du tiroir : compteurs et actions. Point d'entrée `showPlayerDrawer(...)`. |
| `test/widgets/life_counter/zone/life_dial_test.dart` | |
| `test/widgets/life_counter/zone/conditional_handle_test.dart` | |
| `test/widgets/life_counter/zone/player_drawer_test.dart` | |

**Modifiés :**

| Fichier | Nature |
|---|---|
| `lib/controllers/player_zone_controller.dart` | Réécrit pour la V4 (tâche 1). Déplacé vers `lib/providers/player_zone_notifier.dart`. |
| `lib/widgets/life_counter/player_zone.dart` | 734 → ~300 lignes : suppression de `CounterMode`, du minuteur de retour auto, de la logique de compteur (tâche 6). |
| `lib/pages/life_counter/life_counter_page.dart` | Le menu radial quitte l'appui long de la zone (tâche 5) ; `_currentFormat` devient dérivé (tâche 7). |
| `test/controllers/player_zone_controller_test.dart` | Réécrit et déplacé (tâche 1). |

**Supprimés :**

| Fichier | Raison |
|---|---|
| `lib/widgets/life_counter/counter_strip.dart` (119 l.) | La bande de modes de compteur n'existe plus dans la zone V4. Ses compteurs vivent dans le tiroir. |

---

## Task 1 : Réécrire `PlayerZoneController` pour la V4

**Files:**
- Create: `lib/providers/player_zone_notifier.dart`
- Create: `test/providers/player_zone_notifier_test.dart`
- Delete: `lib/controllers/player_zone_controller.dart`, `test/controllers/player_zone_controller_test.dart` (en fin de tâche uniquement)

**Interfaces:**
- Consumes: `AppColors` (`lib/theme/app_colors.dart`).
- Produces :
  - `class FloatingNumber { final int id; final String text; final Color color; double top; double opacity; }`
  - `class PlayerZoneState { final List<FloatingNumber> floatingNumbers; final int nextNumberId; final double rotationAccumulator; final bool isAdjusting; final double wheelAccumulator; }` avec `copyWith`
  - `class PlayerZoneNotifier extends Notifier<PlayerZoneState>` exposant :
    - `void showFloatingNumber(int delta)`
    - `void animateFloatingNumber(int id)` / `void removeFloatingNumber(int id)`
    - `void enterAdjustMode()` / `void exitAdjustMode()`
    - `int handleWheelDrag(double dy)` — renvoie le nombre de pas entiers à appliquer (0 si le seuil n'est pas atteint), en consommant l'accumulateur
    - `int? handleRotationDrag(double delta, int currentQuarterTurns)`
    - `int rotate90Degrees(int currentQuarterTurns)`
    - `void reset()`
  - `final playerZoneNotifierProvider = NotifierProvider.family<PlayerZoneNotifier, PlayerZoneState, int>(PlayerZoneNotifier.new);`
  - Constantes publiques : `PlayerZoneNotifier.rotationThreshold = 40.0`, `PlayerZoneNotifier.wheelPixelsPerUnit = 8.0`, `PlayerZoneNotifier.wheelAccelerationThreshold = 120.0`

> **Ce qui disparaît :** `CounterMode`, `setEditMode`, `triggerChange`, `getDisplayValue`, `getModeColor`, `getModeIcon`, `CounterChangeResult`. Ce sont les modes de compteur, que la zone V4 n'a plus.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/providers/player_zone_notifier_test.dart` :

```dart
// test/providers/player_zone_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  PlayerZoneNotifier notifierFor(int playerId) =>
      container.read(playerZoneNotifierProvider(playerId).notifier);

  PlayerZoneState stateFor(int playerId) =>
      container.read(playerZoneNotifierProvider(playerId));

  group('mode ajustement', () {
    test('démarre hors mode ajustement', () {
      expect(stateFor(0).isAdjusting, isFalse);
    });

    test('enterAdjustMode puis exitAdjustMode', () {
      notifierFor(0).enterAdjustMode();
      expect(stateFor(0).isAdjusting, isTrue);
      notifierFor(0).exitAdjustMode();
      expect(stateFor(0).isAdjusting, isFalse);
    });

    test('exitAdjustMode vide l\'accumulateur de molette', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      n.handleWheelDrag(5.0); // sous le seuil, reste dans l'accumulateur
      expect(stateFor(0).wheelAccumulator, isNot(0.0));
      n.exitAdjustMode();
      expect(stateFor(0).wheelAccumulator, 0.0);
    });
  });

  group('molette', () {
    test('sous le seuil ne produit aucun pas', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      expect(n.handleWheelDrag(5.0), 0);
    });

    test('un glissement vers le haut produit des pas positifs', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      // 8 px par unité, glissement vers le haut = dy négatif = +PV
      expect(n.handleWheelDrag(-24.0), 3);
    });

    test('un glissement vers le bas produit des pas négatifs', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      expect(n.handleWheelDrag(24.0), -3);
    });

    test('le reste est conservé entre deux appels', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      expect(n.handleWheelDrag(-12.0), 1); // 12 px = 1 pas, reste 4 px
      expect(n.handleWheelDrag(-4.0), 1);  // 4 + 4 = 8 px = 1 pas
    });

    test('accélère au-delà du seuil d\'accélération', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      final lent = n.handleWheelDrag(-80.0);
      n.exitAdjustMode();
      n.enterAdjustMode();
      final rapide = n.handleWheelDrag(-160.0);
      expect(rapide, greaterThan(lent * 2),
          reason: 'au-delà du seuil, la molette doit accélérer, pas rester linéaire');
    });

    test('ne produit rien hors mode ajustement', () {
      expect(notifierFor(0).handleWheelDrag(-100.0), 0);
    });
  });

  group('nombres flottants', () {
    test('showFloatingNumber empile avec le bon texte et des ids croissants', () {
      final n = notifierFor(0);
      n.showFloatingNumber(3);
      n.showFloatingNumber(-5);
      final numbers = stateFor(0).floatingNumbers;
      expect(numbers.map((f) => f.text).toList(), ['+3', '-5']);
      expect(numbers.map((f) => f.id).toList(), [0, 1]);
    });

    test('removeFloatingNumber retire le bon', () {
      final n = notifierFor(0);
      n.showFloatingNumber(1);
      n.showFloatingNumber(2);
      n.removeFloatingNumber(0);
      expect(stateFor(0).floatingNumbers.single.text, '+2');
    });
  });

  group('rotation', () {
    test('rotate90Degrees boucle sur 4', () {
      expect(notifierFor(0).rotate90Degrees(3), 0);
    });

    test('le glissement sous le seuil ne tourne pas', () {
      expect(notifierFor(0).handleRotationDrag(10.0, 0), isNull);
    });

    test('le glissement au-delà du seuil tourne et remet l\'accumulateur à zéro', () {
      final n = notifierFor(0);
      expect(n.handleRotationDrag(50.0, 0), 1);
      expect(stateFor(0).rotationAccumulator, 0.0);
    });

    test('un glissement négatif tourne dans l\'autre sens sans passer en négatif', () {
      expect(notifierFor(0).handleRotationDrag(-50.0, 0), 3);
    });
  });

  test('les instances sont indépendantes par playerId', () {
    notifierFor(0).enterAdjustMode();
    expect(stateFor(0).isAdjusting, isTrue);
    expect(stateFor(1).isAdjusting, isFalse);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/providers/player_zone_notifier_test.dart`
Expected: FAIL à la compilation — `player_zone_notifier.dart` n'existe pas.

- [ ] **Step 3: Écrire le notifier**

Créer `lib/providers/player_zone_notifier.dart` :

```dart
// lib/providers/player_zone_notifier.dart
// État local d'une zone joueur : nombres flottants, rotation, mode ajustement.
//
// Remplace lib/controllers/player_zone_controller.dart, bâti sur les modes de
// compteur (life/poison/energy/commanderTax) que la zone V4 n'a plus : le
// chiffre n'affiche que les PV, les compteurs vivent dans le tiroir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Un nombre flottant (+3 / −5) qui monte et s'efface.
class FloatingNumber {
  final int id;
  final String text;
  final Color color;
  double top;
  double opacity;

  FloatingNumber({
    required this.id,
    required this.text,
    required this.color,
    this.top = 20.0,
    this.opacity = 1.0,
  });
}

class PlayerZoneState {
  final List<FloatingNumber> floatingNumbers;
  final int nextNumberId;
  final double rotationAccumulator;
  final bool isAdjusting;
  final double wheelAccumulator;

  const PlayerZoneState({
    this.floatingNumbers = const [],
    this.nextNumberId = 0,
    this.rotationAccumulator = 0.0,
    this.isAdjusting = false,
    this.wheelAccumulator = 0.0,
  });

  PlayerZoneState copyWith({
    List<FloatingNumber>? floatingNumbers,
    int? nextNumberId,
    double? rotationAccumulator,
    bool? isAdjusting,
    double? wheelAccumulator,
  }) {
    return PlayerZoneState(
      floatingNumbers: floatingNumbers ?? this.floatingNumbers,
      nextNumberId: nextNumberId ?? this.nextNumberId,
      rotationAccumulator: rotationAccumulator ?? this.rotationAccumulator,
      isAdjusting: isAdjusting ?? this.isAdjusting,
      wheelAccumulator: wheelAccumulator ?? this.wheelAccumulator,
    );
  }
}

class PlayerZoneNotifier extends Notifier<PlayerZoneState> {
  /// Glissement horizontal cumulé, en pixels, avant de tourner d'un quart.
  static const double rotationThreshold = 40.0;

  /// Pixels de glissement vertical pour un point de vie, en vitesse normale.
  static const double wheelPixelsPerUnit = 8.0;

  /// Au-delà de ce déplacement (px) dans un seul geste, la molette accélère.
  static const double wheelAccelerationThreshold = 120.0;

  @override
  PlayerZoneState build() => const PlayerZoneState();

  // --- Mode ajustement ---

  void enterAdjustMode() {
    state = state.copyWith(isAdjusting: true, wheelAccumulator: 0.0);
  }

  void exitAdjustMode() {
    state = state.copyWith(isAdjusting: false, wheelAccumulator: 0.0);
  }

  /// Consomme un glissement vertical et renvoie le nombre de points à appliquer.
  ///
  /// `dy` suit la convention Flutter : négatif vers le haut. Un glissement vers
  /// le haut ajoute des PV, d'où l'inversion de signe.
  /// Renvoie 0 tant que le seuil d'un point n'est pas atteint ; le reste est
  /// conservé pour l'appel suivant, sans quoi une série de petits glissements
  /// ne produirait jamais rien.
  int handleWheelDrag(double dy) {
    if (!state.isAdjusting) return 0;

    final accumulated = state.wheelAccumulator + (-dy);
    final magnitude = accumulated.abs();

    // Au-delà du seuil, chaque pixel supplémentaire compte double : un grand
    // geste doit couvrir une grosse perte de PV sans traverser l'écran.
    final double effective = magnitude <= wheelAccelerationThreshold
        ? magnitude
        : wheelAccelerationThreshold + (magnitude - wheelAccelerationThreshold) * 2;

    final steps = (effective / wheelPixelsPerUnit).floor();
    if (steps == 0) {
      state = state.copyWith(wheelAccumulator: accumulated);
      return 0;
    }

    final consumed = steps * wheelPixelsPerUnit;
    final remaining = magnitude <= wheelAccelerationThreshold
        ? magnitude - consumed
        : 0.0; // après accélération, on repart à zéro : le reste n'a plus de sens
    state = state.copyWith(
      wheelAccumulator: accumulated.isNegative ? -remaining : remaining,
    );
    return accumulated.isNegative ? -steps : steps;
  }

  // --- Nombres flottants ---

  void showFloatingNumber(int delta) {
    final text = delta > 0 ? '+$delta' : '$delta';
    final color = delta > 0 ? AppColors.accentGreen : AppColors.accentRed;
    final id = state.nextNumberId;
    state = state.copyWith(
      floatingNumbers: [
        ...state.floatingNumbers,
        FloatingNumber(id: id, text: text, color: color),
      ],
      nextNumberId: id + 1,
    );
  }

  void animateFloatingNumber(int id) {
    final updated = state.floatingNumbers.map((n) {
      if (n.id == id) {
        n.top = -50.0;
        n.opacity = 0.0;
      }
      return n;
    }).toList();
    state = state.copyWith(floatingNumbers: updated);
  }

  void removeFloatingNumber(int id) {
    state = state.copyWith(
      floatingNumbers: state.floatingNumbers.where((n) => n.id != id).toList(),
    );
  }

  // --- Rotation ---

  int rotate90Degrees(int currentQuarterTurns) => (currentQuarterTurns + 1) % 4;

  int? handleRotationDrag(double delta, int currentQuarterTurns) {
    final accumulated = state.rotationAccumulator + delta;
    if (accumulated.abs() <= rotationThreshold) {
      state = state.copyWith(rotationAccumulator: accumulated);
      return null;
    }
    final direction = accumulated > 0 ? 1 : -1;
    var next = (currentQuarterTurns + direction) % 4;
    if (next < 0) next += 4;
    state = state.copyWith(rotationAccumulator: 0.0);
    return next;
  }

  void reset() {
    state = const PlayerZoneState();
  }
}

final playerZoneNotifierProvider =
    NotifierProvider.family<PlayerZoneNotifier, PlayerZoneState, int>(
  PlayerZoneNotifier.new,
);
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/providers/player_zone_notifier_test.dart`
Expected: PASS (16 tests)

Run: `flutter test`
Expected: PASS — l'ancien contrôleur est encore là et intact, personne ne le consomme.

- [ ] **Step 5: Supprimer l'ancien contrôleur**

Vérifier d'abord qu'il n'a aucun consommateur :

```bash
grep -rn "PlayerZoneController\|player_zone_controller" lib/ test/
```

Attendu : seulement sa définition et son fichier de test. `lib/widgets/life_counter/player_zone.dart` déclare son **propre** `enum CounterMode` (`:25`) et ne l'importe pas — vérifier que le `grep` le confirme. Si un autre consommateur apparaît, s'arrêter et le signaler.

```bash
git rm lib/controllers/player_zone_controller.dart
git rm test/controllers/player_zone_controller_test.dart
```

Run: `flutter analyze` — Expected: aucune erreur, aucun import orphelin.
Run: `flutter test` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: rewrite PlayerZoneController as PlayerZoneNotifier for V4

L'ancien contrôleur était bâti sur les modes de compteur (life/poison/
energy/commanderTax) que la zone V4 supprime : le chiffre n'affiche plus
que les PV et les compteurs partent dans le tiroir. Les nombres flottants
et la rotation sont conservés ; le mode ajustement et la molette arrivent.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 : `LifeDial` — moitiés de tap et répétition au maintien

**Files:**
- Create: `lib/widgets/life_counter/zone/life_dial.dart`
- Create: `test/widgets/life_counter/zone/life_dial_test.dart`

**Interfaces:**
- Consumes: `playerZoneNotifierProvider` (tâche 1).
- Produces :
  ```dart
  class LifeDial extends ConsumerStatefulWidget {
    const LifeDial({
      super.key,
      required this.playerId,
      required this.life,
      required this.onDelta,
      this.pendingDelta = 0,
      this.textColor,
    });
    final int playerId;
    final int life;
    final void Function(int delta) onDelta;
    final int pendingDelta;
    final Color? textColor;
  }
  ```
  Constantes publiques : `LifeDial.holdRepeatInitialDelay = Duration(milliseconds: 400)`, `LifeDial.holdRepeatMinInterval = Duration(milliseconds: 60)`.

> `onDelta` est appelé avec `-1` ou `+1` par tap. Le widget n'applique rien lui-même : il émet des deltas. L'accumulation (le buffer de 2 s) reste dans `life_counter_page.dart`, inchangée depuis le lot 1.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/widgets/life_counter/zone/life_dial_test.dart` :

```dart
// test/widgets/life_counter/zone/life_dial_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

Future<List<int>> pumpDial(
  WidgetTester tester, {
  int life = 40,
  int pendingDelta = 0,
}) async {
  final deltas = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: LifeDial(
              playerId: 0,
              life: life,
              pendingDelta: pendingDelta,
              onDelta: deltas.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return deltas;
}

void main() {
  testWidgets('affiche les points de vie', (tester) async {
    await pumpDial(tester, life: 34);
    expect(find.text('34'), findsOneWidget);
  });

  testWidgets('un tap à gauche retire un point', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));
    await tester.tapAt(Offset(dial.left + dial.width * 0.25, dial.center.dy));
    await tester.pumpAndSettle();
    expect(deltas, [-1]);
  });

  testWidgets('un tap à droite ajoute un point', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));
    await tester.tapAt(Offset(dial.left + dial.width * 0.75, dial.center.dy));
    await tester.pumpAndSettle();
    expect(deltas, [1]);
  });

  testWidgets('le maintien répète, et de plus en plus vite', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    final gesture = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    // Premier delta immédiat, puis répétition après le délai initial.
    await tester.pump(const Duration(milliseconds: 500));
    final apresDelaiInitial = deltas.length;

    await tester.pump(const Duration(milliseconds: 500));
    final apresUneSeconde = deltas.length;

    await gesture.up();
    await tester.pumpAndSettle();

    expect(apresDelaiInitial, greaterThanOrEqualTo(2),
        reason: 'le maintien doit répéter après le délai initial');
    expect(apresUneSeconde - apresDelaiInitial,
        greaterThan(apresDelaiInitial),
        reason: 'la répétition doit accélérer, pas rester à cadence constante');
    expect(deltas.every((d) => d == -1), isTrue);
  });

  testWidgets('relâcher arrête la répétition', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    final gesture = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
    final figé = deltas.length;

    await tester.pump(const Duration(seconds: 1));
    expect(deltas.length, figé, reason: 'plus aucun delta après le relâchement');
  });

  testWidgets('le badge de dégâts en attente s\'affiche quand il est non nul',
      (tester) async {
    await pumpDial(tester, life: 40, pendingDelta: -5);
    expect(find.text('-5'), findsOneWidget);
  });

  testWidgets('aucun badge quand le delta en attente est nul', (tester) async {
    await pumpDial(tester, life: 40, pendingDelta: 0);
    expect(find.text('0'), findsNothing);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/life_dial_test.dart`
Expected: FAIL à la compilation — `life_dial.dart` n'existe pas.

- [ ] **Step 3: Écrire le widget**

Créer `lib/widgets/life_counter/zone/life_dial.dart` :

```dart
// lib/widgets/life_counter/zone/life_dial.dart
// Surface de geste des points de vie (spec §2.1).
//
// Le chiffre occupe toute la zone. Tap à gauche = −1, à droite = +1, maintien
// = répétition accélérée. Le widget n'applique rien : il émet des deltas, que
// life_counter_page accumule dans son buffer de 2 s.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/theme/app_colors.dart';

class LifeDial extends ConsumerStatefulWidget {
  const LifeDial({
    super.key,
    required this.playerId,
    required this.life,
    required this.onDelta,
    this.pendingDelta = 0,
    this.textColor,
  });

  final int playerId;
  final int life;
  final void Function(int delta) onDelta;
  final int pendingDelta;
  final Color? textColor;

  /// Délai avant que le maintien ne commence à répéter.
  static const Duration holdRepeatInitialDelay = Duration(milliseconds: 400);

  /// Cadence la plus rapide que la répétition puisse atteindre.
  static const Duration holdRepeatMinInterval = Duration(milliseconds: 60);

  @override
  ConsumerState<LifeDial> createState() => _LifeDialState();
}

class _LifeDialState extends ConsumerState<LifeDial> {
  Timer? _repeatTimer;
  int _repeatCount = 0;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _emit(int delta) {
    HapticFeedback.selectionClick();
    widget.onDelta(delta);
  }

  void _startHold(int delta) {
    _emit(delta);
    _repeatCount = 0;
    _repeatTimer?.cancel();
    _repeatTimer = Timer(LifeDial.holdRepeatInitialDelay, () => _repeat(delta));
  }

  /// Répétition accélérée : l'intervalle se resserre à chaque coup, jusqu'à
  /// [LifeDial.holdRepeatMinInterval]. Sans accélération, retirer 8 points au
  /// maintien serait plus lent que huit taps.
  void _repeat(int delta) {
    if (!mounted) return;
    _emit(delta);
    _repeatCount++;
    final ms = (260 - _repeatCount * 20)
        .clamp(LifeDial.holdRepeatMinInterval.inMilliseconds, 260);
    _repeatTimer = Timer(Duration(milliseconds: ms), () => _repeat(delta));
  }

  void _stopHold() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatCount = 0;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.textColor ?? AppColors.textPrimary;

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            Expanded(child: _half(-1)),
            Expanded(child: _half(1)),
          ],
        ),
        IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${widget.life}',
                  style: TextStyle(
                    fontSize: 88,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -3,
                    color: color,
                  ),
                ),
              ),
              if (widget.pendingDelta != 0)
                Text(
                  widget.pendingDelta > 0
                      ? '+${widget.pendingDelta}'
                      : '${widget.pendingDelta}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: widget.pendingDelta > 0
                        ? AppColors.accentGreen
                        : AppColors.accentRed,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _half(int delta) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(delta),
      onTapUp: (_) => _stopHold(),
      onTapCancel: _stopHold,
      child: const SizedBox.expand(),
    );
  }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/zone/life_dial_test.dart`
Expected: PASS (7 tests)

Run: `flutter analyze lib/widgets/life_counter/zone/life_dial.dart`
Expected: aucune erreur.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/zone/life_dial.dart test/widgets/life_counter/zone/life_dial_test.dart
git commit -m "feat: add LifeDial with tap halves and accelerating hold-repeat

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 : Mode ajustement — molette et paliers

**Files:**
- Modify: `lib/widgets/life_counter/zone/life_dial.dart`
- Modify: `test/widgets/life_counter/zone/life_dial_test.dart`

**Interfaces:**
- Consumes: `PlayerZoneNotifier.enterAdjustMode/exitAdjustMode/handleWheelDrag` (tâche 1), `LifeDial` (tâche 2).
- Produces : aucun changement de signature publique. `LifeDial` gagne un comportement interne : l'appui long entre en mode ajustement.

> **Spec §2.5 :** l'appui long fait basculer la zone en mode ajustement. Les paliers ±5/±10 apparaissent et le glissement pilote la molette **dans toute la zone**. On relâche, on sort du mode.

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter dans `test/widgets/life_counter/zone/life_dial_test.dart` :

```dart
  group('mode ajustement', () {
    testWidgets('les paliers sont cachés au repos', (tester) async {
      await pumpDial(tester);
      expect(find.text('-10'), findsNothing);
      expect(find.text('+10'), findsNothing);
    });

    testWidgets('l\'appui long fait apparaître les paliers', (tester) async {
      await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      expect(find.text('-10'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
    });

    testWidgets('un palier émet son delta', (tester) async {
      final deltas = await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      await tester.tap(find.text('-10'));
      await tester.pumpAndSettle();
      expect(deltas, contains(-10));
    });

    testWidgets('le glissement vertical en mode ajustement émet des deltas',
        (tester) async {
      final deltas = await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();

      // 8 px par point : 40 px vers le bas = −5.
      await tester.drag(find.byType(LifeDial), const Offset(0, 40));
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty);
      expect(deltas.reduce((a, b) => a + b), lessThan(0),
          reason: 'glisser vers le bas doit retirer des PV');
    });

    testWidgets('le glissement ne fait rien hors mode ajustement',
        (tester) async {
      final deltas = await pumpDial(tester);
      await tester.drag(find.byType(LifeDial), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(deltas, isEmpty,
          reason: 'hors mode ajustement, un glissement vertical appartient au '
              'tiroir et à la rotation, pas à la molette');
    });

    testWidgets('un tap hors des paliers sort du mode', (tester) async {
      await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      expect(find.text('+10'), findsOneWidget);

      final dial = tester.getRect(find.byType(LifeDial));
      await tester.tapAt(Offset(dial.center.dx, dial.top + 12));
      await tester.pumpAndSettle();
      expect(find.text('+10'), findsNothing);
    });
  });
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/life_dial_test.dart`
Expected: FAIL — les paliers n'existent pas, l'appui long ne fait rien.

- [ ] **Step 3: Implémenter le mode ajustement**

Dans `lib/widgets/life_counter/zone/life_dial.dart` :

Remplacer le corps de `build()` pour lire l'état d'ajustement et brancher les gestes :

```dart
  @override
  Widget build(BuildContext context) {
    final color = widget.textColor ?? AppColors.textPrimary;
    final isAdjusting =
        ref.watch(playerZoneNotifierProvider(widget.playerId)).isAdjusting;
    final notifier =
        ref.read(playerZoneNotifierProvider(widget.playerId).notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        notifier.enterAdjustMode();
      },
      // La molette n'existe qu'en mode ajustement : hors de ce mode, le
      // glissement vertical appartient au tiroir et à la rotation (spec §2.5).
      onVerticalDragUpdate: isAdjusting
          ? (details) {
              final steps = notifier.handleWheelDrag(details.delta.dy);
              if (steps != 0) _emit(steps);
            }
          : null,
      onVerticalDragEnd: isAdjusting ? (_) {} : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!isAdjusting)
            Row(
              children: [
                Expanded(child: _half(-1)),
                Expanded(child: _half(1)),
              ],
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: notifier.exitAdjustMode,
              child: const SizedBox.expand(),
            ),
          IgnorePointer(child: _readout(color)),
          if (isAdjusting)
            Align(
              alignment: Alignment.bottomCenter,
              child: _stepRow(),
            ),
        ],
      ),
    );
  }

  Widget _readout(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${widget.life}',
            style: TextStyle(
              fontSize: 88,
              fontWeight: FontWeight.w200,
              letterSpacing: -3,
              color: color,
            ),
          ),
        ),
        if (widget.pendingDelta != 0)
          Text(
            widget.pendingDelta > 0
                ? '+${widget.pendingDelta}'
                : '${widget.pendingDelta}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: widget.pendingDelta > 0
                  ? AppColors.accentGreen
                  : AppColors.accentRed,
            ),
          ),
      ],
    );
  }

  /// Paliers ±5 / ±10 (spec §2.4). Ils couvrent les montants ronds ; la molette
  /// couvre le reste.
  Widget _stepRow() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final delta in const [-10, -5, 5, 10])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _emit(delta),
                  child: Container(
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: delta < 0
                            ? AppColors.accentRed
                            : AppColors.accentGreen,
                      ),
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

Ajouter l'import `import 'package:magic_companion/providers/player_zone_notifier.dart';`.

Dans `dispose()`, sortir du mode pour ne pas laisser un état d'ajustement derrière une zone démontée :

```dart
  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }
```

> Ne pas appeler `ref` dans `dispose()` — c'est interdit sur un `ConsumerState` et le lot 1 s'est fait prendre dessus. Le mode ajustement est un état par `playerId` qui sera réinitialisé au prochain `enterAdjustMode` ; le laisser à `true` est sans effet puisque rien ne le lit quand la zone n'est pas montée.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/zone/life_dial_test.dart`
Expected: PASS (13 tests)

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/zone/life_dial.dart test/widgets/life_counter/zone/life_dial_test.dart
git commit -m "feat: add adjustment mode with wheel and step buttons

Appui long -> mode ajustement : les paliers +/-5 et +/-10 apparaissent et le
glissement vertical pilote la molette. Hors de ce mode, le glissement reste
au tiroir et a la rotation.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 : `ConditionalHandle` — la poignée qui se tait

**Files:**
- Create: `lib/widgets/life_counter/zone/conditional_handle.dart`
- Create: `test/widgets/life_counter/zone/conditional_handle_test.dart`

**Interfaces:**
- Consumes: rien des tâches précédentes.
- Produces :
  ```dart
  class CounterSummary {
    const CounterSummary({this.poison = 0, this.energy = 0, this.commanderTax = 0, this.worstCommanderDamage = 0});
    final int poison;
    final int energy;
    final int commanderTax;
    final int worstCommanderDamage;
    bool get isCalm => poison == 0 && energy == 0 && commanderTax == 0 && worstCommanderDamage == 0;
  }

  class ConditionalHandle extends StatelessWidget {
    const ConditionalHandle({super.key, required this.summary, this.onTap});
    final CounterSummary summary;
    final VoidCallback? onTap;
    static const double reservedHeight = 30.0;
  }
  ```

> **Spec §2.2 :** tous compteurs à zéro, un simple trait de 3 px ; dès qu'un compteur bouge, la poignée s'épaissit en bandeau résumé. **La hauteur est réservée dès le départ et laissée vide à l'état calme** — sans quoi le chiffre de PV se recalerait en cours de partie et sautillerait à 8 joueurs.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/widgets/life_counter/zone/conditional_handle_test.dart` :

```dart
// test/widgets/life_counter/zone/conditional_handle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';

Future<void> pumpHandle(WidgetTester tester, CounterSummary summary) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: ConditionalHandle(summary: summary),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('isCalm est vrai quand tout est à zéro', () {
    expect(const CounterSummary().isCalm, isTrue);
    expect(const CounterSummary(poison: 1).isCalm, isFalse);
    expect(const CounterSummary(worstCommanderDamage: 7).isCalm, isFalse);
  });

  testWidgets('à l\'état calme, la poignée n\'affiche aucun chiffre',
      (tester) async {
    await pumpHandle(tester, const CounterSummary());
    expect(find.textContaining('0'), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('un compteur non nul fait apparaître le résumé', (tester) async {
    await pumpHandle(tester, const CounterSummary(poison: 3));
    expect(find.textContaining('3'), findsOneWidget);
  });

  testWidgets('n\'affiche que les compteurs non nuls', (tester) async {
    await pumpHandle(
      tester,
      const CounterSummary(poison: 3, worstCommanderDamage: 12),
    );
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.textContaining('12'), findsOneWidget);
    // L'énergie et la taxe sont à zéro : elles ne doivent pas apparaître.
    expect(find.textContaining('⚡'), findsNothing);
  });

  testWidgets('la hauteur est identique au repos et en alerte', (tester) async {
    await pumpHandle(tester, const CounterSummary());
    final calme = tester.getSize(find.byType(ConditionalHandle)).height;

    await pumpHandle(tester, const CounterSummary(poison: 3, energy: 2));
    final alerte = tester.getSize(find.byType(ConditionalHandle)).height;

    expect(alerte, calme,
        reason: 'la hauteur est réservée : le chiffre de PV ne doit jamais se '
            'recaler en cours de partie');
    expect(calme, ConditionalHandle.reservedHeight);
  });

  testWidgets('le tap déclenche le callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConditionalHandle(
            summary: const CounterSummary(poison: 1),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ConditionalHandle));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/conditional_handle_test.dart`
Expected: FAIL à la compilation.

- [ ] **Step 3: Écrire le widget**

Créer `lib/widgets/life_counter/zone/conditional_handle.dart` :

```dart
// lib/widgets/life_counter/zone/conditional_handle.dart
// Poignée conditionnelle (spec §2.2).
//
// Trait fin quand tous les compteurs sont à zéro ; bandeau résumé dès que l'un
// bouge. Le changement de forme est lui-même un signal : le joueur voit du coin
// de l'œil qu'il lui est arrivé quelque chose, sans lire un chiffre.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Ce qui menace un joueur, condensé.
class CounterSummary {
  const CounterSummary({
    this.poison = 0,
    this.energy = 0,
    this.commanderTax = 0,
    this.worstCommanderDamage = 0,
  });

  final int poison;
  final int energy;
  final int commanderTax;

  /// Le plus gros total de dégâts de commandant reçu d'une seule source.
  final int worstCommanderDamage;

  bool get isCalm =>
      poison == 0 &&
      energy == 0 &&
      commanderTax == 0 &&
      worstCommanderDamage == 0;
}

class ConditionalHandle extends StatelessWidget {
  const ConditionalHandle({super.key, required this.summary, this.onTap});

  final CounterSummary summary;
  final VoidCallback? onTap;

  /// Hauteur réservée en permanence, calme ou non. Sans réservation, la zone
  /// changerait de hauteur utile en cours de partie et le chiffre de PV
  /// sauterait — visible surtout à 8 joueurs sur petit écran.
  static const double reservedHeight = 30.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: reservedHeight,
        child: summary.isCalm ? _grip() : _band(),
      ),
    );
  }

  Widget _grip() {
    return Center(
      child: Container(
        width: 34,
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.greyShade800,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _band() {
    final parts = <Widget>[
      if (summary.poison > 0)
        _chip('☠', summary.poison, AppColors.accentGreen),
      if (summary.worstCommanderDamage > 0)
        _chip('⚔', summary.worstCommanderDamage, AppColors.accentRed),
      if (summary.energy > 0) _chip('⚡', summary.energy, AppColors.accent),
      if (summary.commanderTax > 0)
        _chip('⬆', summary.commanderTax, AppColors.amber),
    ];

    return Container(
      decoration: BoxDecoration(
        // greyShade800 est un getter (app_colors.dart:180), pas une constante :
        // ce BoxDecoration ne peut donc pas etre const.
        border: Border(top: BorderSide(color: AppColors.greyShade800)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: parts,
      ),
    );
  }

  Widget _chip(String glyph, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '$glyph $value',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/zone/conditional_handle_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/zone/conditional_handle.dart test/widgets/life_counter/zone/conditional_handle_test.dart
git commit -m "feat: add ConditionalHandle with reserved height

Trait fin quand tout est a zero, bandeau resume des qu'un compteur bouge.
La hauteur est reservee en permanence pour que le chiffre de PV ne se
recale jamais en cours de partie.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 : `PlayerDrawer` — la coquille du tiroir, et le menu radial y déménage

**Files:**
- Create: `lib/widgets/life_counter/zone/player_drawer.dart`
- Create: `test/widgets/life_counter/zone/player_drawer_test.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart` (retrait du `onLongPressStart` qui ouvre le menu radial)

**Interfaces:**
- Consumes: `showRadialMenu` n'est plus utilisé ; ses trois actions sont reprises telles quelles.
- Produces :
  ```dart
  Future<void> showPlayerDrawer({
    required BuildContext context,
    required String playerName,
    required Map<String, int> counters,
    required bool isMonarch,
    required bool isEliminated,
    required void Function(String counterId, int delta) onCounterDelta,
    required VoidCallback onToggleMonarch,
    required VoidCallback onEliminate,
    required VoidCallback onResetCounters,
  });
  ```

> **Périmètre :** la coquille seulement — compteurs et actions. La grille de commander damage et la vue table arrivent au lot 3. Le tiroir est un `showModalBottomSheet`.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/widgets/life_counter/zone/player_drawer_test.dart` :

```dart
// test/widgets/life_counter/zone/player_drawer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/player_drawer.dart';

class _Captured {
  final counterDeltas = <MapEntry<String, int>>[];
  var monarchToggled = false;
  var eliminated = false;
  var reset = false;
}

Future<_Captured> openDrawer(
  WidgetTester tester, {
  Map<String, int> counters = const {'poison': 0, 'energy': 0, 'commander_tax': 0},
  bool isMonarch = false,
  bool isEliminated = false,
}) async {
  final captured = _Captured();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPlayerDrawer(
              context: context,
              playerName: 'Alexis',
              counters: counters,
              isMonarch: isMonarch,
              isEliminated: isEliminated,
              onCounterDelta: (id, d) =>
                  captured.counterDeltas.add(MapEntry(id, d)),
              onToggleMonarch: () => captured.monarchToggled = true,
              onEliminate: () => captured.eliminated = true,
              onResetCounters: () => captured.reset = true,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('affiche le nom du joueur et les trois compteurs',
      (tester) async {
    await openDrawer(tester);
    expect(find.text('Alexis'), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);
    expect(find.text('Énergie'), findsOneWidget);
    expect(find.text('Taxe de commandant'), findsOneWidget);
  });

  testWidgets('incrémenter un compteur émet son delta', (tester) async {
    final captured = await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('counter-poison-plus')));
    await tester.pumpAndSettle();
    expect(captured.counterDeltas, [const MapEntry('poison', 1)]);
  });

  testWidgets('décrémenter un compteur émet son delta', (tester) async {
    final captured = await openDrawer(tester, counters: {'poison': 2});
    await tester.tap(find.byKey(const ValueKey('counter-poison-minus')));
    await tester.pumpAndSettle();
    expect(captured.counterDeltas, [const MapEntry('poison', -1)]);
  });

  testWidgets('l\'action monarque appelle son callback', (tester) async {
    final captured = await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    await tester.pumpAndSettle();
    expect(captured.monarchToggled, isTrue);
    expect(captured.eliminated, isFalse);
    expect(captured.reset, isFalse);
  });

  testWidgets('l\'action éliminer appelle son callback', (tester) async {
    final captured = await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-eliminate')));
    await tester.pumpAndSettle();
    expect(captured.eliminated, isTrue);
    expect(captured.monarchToggled, isFalse);
  });

  testWidgets('l\'action réinitialiser appelle son callback', (tester) async {
    final captured = await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-reset')));
    await tester.pumpAndSettle();
    expect(captured.reset, isTrue);
    expect(captured.eliminated, isFalse);
  });

  testWidgets('une action ferme le tiroir', (tester) async {
    await openDrawer(tester);
    expect(find.text('Alexis'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    await tester.pumpAndSettle();
    expect(find.text('Alexis'), findsNothing,
        reason: 'le tiroir se referme avant de déclencher l\'action');
  });

  testWidgets('l\'action monarque change de libellé selon l\'état',
      (tester) async {
    await openDrawer(tester, isMonarch: false);
    expect(find.text('Monarque'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // ferme le sheet
    await tester.pumpAndSettle();

    await openDrawer(tester, isMonarch: true);
    expect(find.text('Retirer le monarque'), findsOneWidget);
  });

  testWidgets('l\'action éliminer devient annuler pour un joueur éliminé',
      (tester) async {
    await openDrawer(tester, isEliminated: true);
    expect(find.text('Annuler l\'élimination'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/player_drawer_test.dart`
Expected: FAIL à la compilation.

- [ ] **Step 3: Écrire le tiroir**

Créer `lib/widgets/life_counter/zone/player_drawer.dart` :

```dart
// lib/widgets/life_counter/zone/player_drawer.dart
// Le tiroir du joueur (spec §2.7) : tout ce qui n'est pas les points de vie.
//
// Lot 2 — la coquille : compteurs et actions (ces dernières reprises du menu
// radial, qui perd son appui long au profit du mode ajustement, spec §2.5).
// Lot 3 y ajoutera la grille de dégâts de commandant.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

const _counterLabels = <String, String>{
  'poison': 'Poison',
  'energy': 'Énergie',
  'commander_tax': 'Taxe de commandant',
};

const _counterIcons = <String, IconData>{
  'poison': Icons.science,
  'energy': Icons.flash_on,
  'commander_tax': Icons.local_police,
};

Future<void> showPlayerDrawer({
  required BuildContext context,
  required String playerName,
  required Map<String, int> counters,
  required bool isMonarch,
  required bool isEliminated,
  required void Function(String counterId, int delta) onCounterDelta,
  required VoidCallback onToggleMonarch,
  required VoidCallback onEliminate,
  required VoidCallback onResetCounters,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.greyShade800,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetCtx) => _PlayerDrawerBody(
      playerName: playerName,
      counters: counters,
      isMonarch: isMonarch,
      isEliminated: isEliminated,
      onCounterDelta: onCounterDelta,
      onToggleMonarch: () {
        Navigator.of(sheetCtx).pop();
        onToggleMonarch();
      },
      onEliminate: () {
        Navigator.of(sheetCtx).pop();
        onEliminate();
      },
      onResetCounters: () {
        Navigator.of(sheetCtx).pop();
        onResetCounters();
      },
    ),
  );
}

class _PlayerDrawerBody extends StatefulWidget {
  const _PlayerDrawerBody({
    required this.playerName,
    required this.counters,
    required this.isMonarch,
    required this.isEliminated,
    required this.onCounterDelta,
    required this.onToggleMonarch,
    required this.onEliminate,
    required this.onResetCounters,
  });

  final String playerName;
  final Map<String, int> counters;
  final bool isMonarch;
  final bool isEliminated;
  final void Function(String counterId, int delta) onCounterDelta;
  final VoidCallback onToggleMonarch;
  final VoidCallback onEliminate;
  final VoidCallback onResetCounters;

  @override
  State<_PlayerDrawerBody> createState() => _PlayerDrawerBodyState();
}

class _PlayerDrawerBodyState extends State<_PlayerDrawerBody> {
  /// Copie locale : le tiroir reste ouvert pendant qu'on incrémente, et doit
  /// refléter le changement immédiatement sans attendre un rebuild de la page.
  late final Map<String, int> _values = Map<String, int>.from(widget.counters);

  void _bump(String id, int delta) {
    setState(() {
      _values[id] = ((_values[id] ?? 0) + delta).clamp(0, 99);
    });
    widget.onCounterDelta(id, delta);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(widget.playerName, style: AppTextStyles.cardTitle()),
            const SizedBox(height: 14),
            for (final id in _counterLabels.keys) _counterRow(id),
            const Divider(height: 26),
            _action(
              key: const ValueKey('action-monarch'),
              icon: Icons.star,
              label: widget.isMonarch ? 'Retirer le monarque' : 'Monarque',
              color: AppColors.amber,
              onTap: widget.onToggleMonarch,
            ),
            _action(
              key: const ValueKey('action-eliminate'),
              icon: widget.isEliminated ? Icons.undo : Icons.person_off,
              label: widget.isEliminated
                  ? 'Annuler l\'élimination'
                  : 'Éliminer',
              color: AppColors.accentRed,
              onTap: widget.onEliminate,
            ),
            _action(
              key: const ValueKey('action-reset'),
              icon: Icons.restart_alt,
              label: 'Réinitialiser les compteurs',
              color: AppColors.textSecondary,
              onTap: widget.onResetCounters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterRow(String id) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_counterIcons[id], size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_counterLabels[id]!, style: AppTextStyles.body()),
          ),
          IconButton(
            key: ValueKey('counter-$id-minus'),
            icon: const Icon(Icons.remove),
            color: AppColors.textSecondary,
            onPressed: () => _bump(id, -1),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${_values[id] ?? 0}',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle(),
            ),
          ),
          IconButton(
            key: ValueKey('counter-$id-plus'),
            icon: const Icon(Icons.add),
            color: AppColors.textSecondary,
            onPressed: () => _bump(id, 1),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTextStyles.body()),
      onTap: onTap,
    );
  }
}
```

> `AppTextStyles` expose des **méthodes**, pas des constantes : `cardTitle({Color? color, double? fontSize})` et `body({Color? color, double? fontSize})` (`lib/theme/app_text_styles.dart:53` et `:95`). Les appeler avec leurs parenthèses. Ne pas introduire de `TextStyle` littéral.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/zone/player_drawer_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Retirer le menu radial de l'appui long**

Dans `lib/pages/life_counter/life_counter_page.dart`, supprimer le `GestureDetector` dont le `onLongPressStart` appelle `_showRadialMenuForPlayer` (repérer par contenu — la zone entourée s'appelle `zone`). La méthode `_showRadialMenuForPlayer` et l'import de `radial_menu.dart` deviennent morts : les supprimer aussi.

Vérifier :

```bash
grep -rn "showRadialMenu\|radial_menu" lib/ test/
```

Attendu : seulement `lib/widgets/life_counter/radial_menu.dart` lui-même et son test. **Ne pas supprimer le composant** : la spec §2.5 précise qu'il est conservé, seul son point d'invocation change. Il reste disponible pour un usage ultérieur.

Run: `flutter test` — Expected: PASS. Si `test/widgets/life_counter/` contient un test qui monte le menu radial depuis la page, l'adapter.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add PlayerDrawer shell and free the long press

Le tiroir accueille les compteurs et les trois actions de l'ancien menu
radial (monarque / eliminer / reset), qui perd son appui long au profit du
mode ajustement. Le composant RadialMenu est conserve, seul son point
d'invocation disparait.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 6 : Assembler `PlayerZone`

**Files:**
- Modify: `lib/widgets/life_counter/player_zone.dart` (734 → ~300 lignes)
- Delete: `lib/widgets/life_counter/counter_strip.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart` (câblage du tiroir)

**Interfaces:**
- Consumes: `LifeDial` (tâches 2-3), `ConditionalHandle` + `CounterSummary` (tâche 4), `showPlayerDrawer` (tâche 5), `playerZoneNotifierProvider` (tâche 1).
- Produces : `PlayerZone` garde sa signature publique actuelle, **moins** `onStatChanged` (remplacé par `onCounterDelta`) :
  ```dart
  final void Function(String counterId, int delta)? onCounterDelta;
  final VoidCallback? onOpenDrawer;
  ```

> **Ce qui disparaît de `player_zone.dart` :** `enum CounterMode` (`:25`), `_editMode` (`:69`), `_resetModeTimer` et `_resetAutoReturnTimer` (`:211-217`), `_setEditMode` (`:202`), `_getModeColor` / `_getModeIcon`, la logique de `_triggerChange` qui mute `widget.player.poison/energy/commanderCastCount` en place (`:170-172`), et l'usage de `CounterStrip`.
>
> **Ce qui reste :** l'en-tête (palette, rotation, tap sur le nom), l'image de fond et la galerie de commandants, les animations pulse/shake/glow, les nombres flottants.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/widgets/life_counter/player_zone_test.dart` (le fichier n'existe pas — `player_zone.dart` n'a jamais eu de test) :

```dart
// test/widgets/life_counter/player_zone_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

/// `commanderDamageReceived` est **requis** dans le constructeur de `Player`
/// (`lib/models/player_model.dart:30`) — ne pas l'omettre.
Player buildPlayer({int life = 40, int poison = 0, int energy = 0}) {
  return Player(
    id: 0,
    name: 'Alexis',
    life: life,
    colorValue: 0xFF880000,
    commanderDamageReceived: const {},
    poison: poison,
    energy: energy,
  );
}

Future<List<int>> pumpZone(WidgetTester tester, Player player) async {
  final deltas = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            height: 340,
            child: PlayerZone(
              player: player,
              onLifeChanged: deltas.add,
              onShowCommanderDamage: () {},
              onColorChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return deltas;
}

void main() {
  testWidgets('la zone affiche les PV et rien d\'autre au calme',
      (tester) async {
    await pumpZone(tester, buildPlayer(life: 34));
    expect(find.text('34'), findsOneWidget);
    expect(find.byType(LifeDial), findsOneWidget);
    expect(find.byType(ConditionalHandle), findsOneWidget);
  });

  testWidgets('un tap à gauche remonte un delta négatif', (tester) async {
    final deltas = await pumpZone(tester, buildPlayer());
    final dial = tester.getRect(find.byType(LifeDial));
    await tester.tapAt(Offset(dial.left + dial.width * 0.25, dial.center.dy));
    await tester.pumpAndSettle();
    expect(deltas, [-1]);
  });

  testWidgets('la poignée reste muette quand aucun compteur ne bouge',
      (tester) async {
    await pumpZone(tester, buildPlayer(poison: 0, energy: 0));
    final handle = tester.widget<ConditionalHandle>(
      find.byType(ConditionalHandle),
    );
    expect(handle.summary.isCalm, isTrue);
  });

  testWidgets('la poignée parle dès qu\'un compteur bouge', (tester) async {
    await pumpZone(tester, buildPlayer(poison: 3));
    final handle = tester.widget<ConditionalHandle>(
      find.byType(ConditionalHandle),
    );
    expect(handle.summary.isCalm, isFalse);
    expect(handle.summary.poison, 3);
  });

  testWidgets('la hauteur du chiffre ne change pas quand un compteur apparaît',
      (tester) async {
    await pumpZone(tester, buildPlayer(poison: 0));
    final calme = tester.getRect(find.byType(LifeDial));

    await pumpZone(tester, buildPlayer(poison: 3));
    final alerte = tester.getRect(find.byType(LifeDial));

    expect(alerte.height, calme.height,
        reason: 'la hauteur de la poignée est réservée : le chiffre ne bouge pas');
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/player_zone_test.dart`
Expected: FAIL — `PlayerZone` affiche encore la bande de compteurs et n'utilise ni `LifeDial` ni `ConditionalHandle`.

- [ ] **Step 3: Réécrire `PlayerZone`**

Dans `lib/widgets/life_counter/player_zone.dart` :

- supprimer `enum CounterMode`, `_editMode`, `_resetModeTimer`, `_resetAutoReturnTimer`, `_setEditMode`, `_getModeColor`, `_getModeIcon`, l'import de `counter_strip.dart` et l'usage de `CounterStrip` ;
- remplacer `_triggerChange` par une simple émission : la zone ne mute plus le `Player` en place, elle remonte le delta ;
- remplacer le corps central par `LifeDial` et la bande basse par `ConditionalHandle` :

```dart
    // Corps central : le chiffre occupe tout (spec §2.1).
    Widget body = Column(
      children: [
        PlayerHeader(
          name: widget.player.name,
          isMonarch: widget.player.isMonarch,
          onNameTap: widget.onNameTap,
          onPaletteTap: _showColorPicker,
          onRotate: _rotate90Degrees,
          onRotationDrag: _handleRotationDrag,
        ),
        Expanded(
          child: LifeDial(
            playerId: widget.player.id,
            life: widget.player.life,
            onDelta: widget.onLifeChanged,
          ),
        ),
        ConditionalHandle(
          summary: CounterSummary(
            poison: widget.player.poison,
            energy: widget.player.energy,
            commanderTax: widget.player.commanderCastCount,
            worstCommanderDamage: widget.player.commanderDamageReceived.values
                .fold<int>(0, (max, v) => v > max ? v : max),
          ),
          onTap: widget.onOpenDrawer,
        ),
      ],
    );
```

- remplacer le paramètre `onStatChanged` par `onCounterDelta` et ajouter `onOpenDrawer` :

```dart
  /// Émis quand un compteur change depuis le tiroir.
  final void Function(String counterId, int delta)? onCounterDelta;

  /// Ouverture du tiroir (tap ou glissement depuis la poignée).
  final VoidCallback? onOpenDrawer;
```

Supprimer la bande de compteurs :

```bash
git rm lib/widgets/life_counter/counter_strip.dart
```

Si `test/widgets/life_counter/` contient un test de `CounterStrip`, le supprimer également.

Dans `lib/pages/life_counter/life_counter_page.dart`, `_buildPlayerZone` passe les deux nouveaux callbacks. `onOpenDrawer` appelle `showPlayerDrawer` avec les compteurs du `PlayerState`, et branche les trois actions sur les méthodes existantes (`_controller.toggleMonarch`, l'élimination et son annulation, la remise à zéro des compteurs) — celles-là mêmes que `_showRadialMenuForPlayer` appelait avant sa suppression en tâche 5.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/player_zone_test.dart`
Expected: PASS (5 tests)

Run: `flutter test`
Expected: PASS

Run: `wc -l lib/widgets/life_counter/player_zone.dart`
Expected: nettement sous 500 lignes. Si le fichier dépasse encore 500, dire dans le rapport ce qui l'occupe — la galerie de commandants et la recherche d'artwork (`_ArtworkSearchModal`, ~120 lignes) sont les candidats à extraire.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: strip PlayerZone down to life only

La zone n'affiche plus que les PV : les modes de compteur, le minuteur de
retour automatique et la bande CounterStrip disparaissent au profit de
LifeDial, ConditionalHandle et du tiroir.

Premiers tests de PlayerZone — le fichier n'en avait aucun.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 7 : Solder les deux points parqués du lot 1

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart`
- Create: `lib/widgets/life_counter/snapshot_writer.dart`
- Test: `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Consumes: `GameSessionService` (`lib/services/game_session_service.dart`).
- Produces :
  ```dart
  class SnapshotWriter {
    SnapshotWriter(this._service, {Duration debounce = const Duration(milliseconds: 500)});
    void schedule(GameSession session);
    Future<void> flushNow();
    Future<void> cancelPending();
    void disposeAndFlush();
  }
  ```

> Ces deux points ont été parqués avec décision à la fin du lot 1. Ils sont soldés ici parce que le lot 2 touche déjà la page.

**Point 1 — `_currentFormat` non réactif.** Le champ est une copie locale de `_session!.format`, écrite à deux endroits (restauration de snapshot, `onGameStart` du setup) et lue en une vingtaine. Aucun chemin actuel ne peut le faire diverger, mais c'est le dernier état dérivé de la session encore détenu par la page. Le remplacer par un getter : `GameFormat get _currentFormat => _session?.format ?? GameFormat.builtInFormats.first;`, et supprimer les deux écritures.

**Point 2 — les trois champs de snapshot.** `_snapshotDebounce`, `_pendingSnapshotSession` et `_inFlightSnapshotWrite` répondent chacun à un problème que le précédent ne couvrait pas, avec ~35 lignes de commentaire pour une seule responsabilité. Les encapsuler dans `SnapshotWriter`, testable seul. **Le comportement ne change pas** : mêmes garanties de débounce, de flush au démontage et d'attente de l'écriture en vol avant effacement — c'est un déplacement, pas une refonte.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `test/widgets/life_counter/snapshot_writer_test.dart` :

```dart
// test/widgets/life_counter/snapshot_writer_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/services/game_session_service.dart';
import 'package:magic_companion/widgets/life_counter/snapshot_writer.dart';

class _RecordingService implements GameSessionService {
  final saved = <GameSession>[];
  var cleared = 0;
  Completer<void>? gate;

  @override
  Future<void> saveSnapshot(GameSession session) async {
    saved.add(session);
    if (gate != null) await gate!.future;
  }

  @override
  Future<GameSession?> loadSnapshot() async => null;

  @override
  Future<bool> hasActiveGame() async => false;

  @override
  Future<void> clearSnapshot() async => cleared++;
}

GameSession sessionWithLife(int life) {
  final base = GameSession.newGame(
    format: GameFormat.builtInFormats.first,
    playerConfigs: [
      PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
      PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
    ],
  );
  return base.copyWith(
    players: [base.players[0].copyWith(life: life), base.players[1]],
  );
}

void main() {
  test('une rafale ne produit qu\'une écriture, avec le dernier état',
      () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(milliseconds: 20));

    for (var life = 39; life >= 30; life--) {
      writer.schedule(sessionWithLife(life));
    }
    expect(service.saved, isEmpty, reason: 'rien avant expiration du débounce');

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(service.saved, hasLength(1));
    expect(service.saved.single.players[0].life, 30);
  });

  test('flushNow écrit immédiatement sans attendre le débounce', () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(seconds: 10));
    writer.schedule(sessionWithLife(35));
    await writer.flushNow();
    expect(service.saved, hasLength(1));
    expect(service.saved.single.players[0].life, 35);
  });

  test('cancelPending attend une écriture déjà en vol', () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(milliseconds: 10));
    service.gate = Completer<void>();

    writer.schedule(sessionWithLife(33));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.saved, hasLength(1), reason: 'l\'écriture est partie');

    var cancelDone = false;
    final cancel = writer.cancelPending().then((_) => cancelDone = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cancelDone, isFalse,
        reason: 'cancelPending doit attendre l\'écriture en vol, sinon un '
            'effacement pourrait précéder une écriture retardataire');

    service.gate!.complete();
    await cancel;
    expect(cancelDone, isTrue);
  });

  test('cancelPending empêche une écriture programmée non encore partie',
      () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(milliseconds: 50));
    writer.schedule(sessionWithLife(31));
    await writer.cancelPending();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(service.saved, isEmpty);
  });

  test('disposeAndFlush écrit ce qui était en attente', () async {
    final service = _RecordingService();
    final writer =
        SnapshotWriter(service, debounce: const Duration(seconds: 10));
    writer.schedule(sessionWithLife(29));
    writer.disposeAndFlush();
    await Future<void>.delayed(Duration.zero);
    expect(service.saved, hasLength(1));
    expect(service.saved.single.players[0].life, 29);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/snapshot_writer_test.dart`
Expected: FAIL à la compilation — `snapshot_writer.dart` n'existe pas.

- [ ] **Step 3: Écrire `SnapshotWriter` et brancher la page**

Créer `lib/widgets/life_counter/snapshot_writer.dart` :

```dart
// lib/widgets/life_counter/snapshot_writer.dart
// Écriture différée du snapshot de partie.
//
// Rassemble ce qui vivait en trois champs de LifeCounterPage :
//   - le Timer de débounce (les mutations arrivent par rafales, un tap = une
//     mutation, et sérialiser la session à chaque fois coûte une I/O par tap) ;
//   - la session capturée à l'ordonnancement, pour que le démontage n'ait pas
//     à relire un provider (interdit dans dispose sur un ConsumerState) ;
//   - le Future de l'écriture déjà partie, que Timer.cancel() ne peut plus
//     rattraper et qu'un effacement de fin de partie doit attendre, sans quoi
//     une écriture retardataire ressusciterait la partie terminée.

import 'dart:async';

import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/services/game_session_service.dart';

class SnapshotWriter {
  SnapshotWriter(this._service, {this.debounce = const Duration(milliseconds: 500)});

  final GameSessionService _service;
  final Duration debounce;

  Timer? _timer;
  GameSession? _pending;
  Future<void>? _inFlight;

  /// Programme une écriture. Seule la dernière d'une rafale part.
  void schedule(GameSession session) {
    _pending = session;
    _timer?.cancel();
    _timer = Timer(debounce, _flush);
  }

  /// Écrit tout de suite ce qui est en attente, sans attendre le débounce.
  Future<void> flushNow() async {
    _timer?.cancel();
    _timer = null;
    _flush();
    await _inFlight;
  }

  /// Annule ce qui est programmé **et** attend ce qui est déjà parti.
  ///
  /// L'attente est le point important : sans elle, un effacement de fin de
  /// partie pourrait précéder une écriture en vol, qui ressusciterait alors
  /// la partie terminée au prochain lancement.
  Future<void> cancelPending() async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    await _inFlight;
  }

  /// À appeler depuis `dispose()` : synchrone, l'écriture part sans être
  /// attendue. Ne touche à aucun provider.
  void disposeAndFlush() {
    _timer?.cancel();
    _timer = null;
    _flush();
  }

  void _flush() {
    final session = _pending;
    _pending = null;
    if (session == null) return;

    // Le champ est renseigné avant tout point de suspension : en Dart, l'appel
    // d'une fonction async ne suspend pas l'appelant avant son premier await
    // interne, donc personne ne peut observer _inFlight à null entre les deux.
    final write = _service.saveSnapshot(session);
    _inFlight = write;
    write.whenComplete(() {
      if (identical(_inFlight, write)) _inFlight = null;
    });
  }
}
```

Dans `lib/pages/life_counter/life_counter_page.dart` :

- remplacer les trois champs et les méthodes `_saveSnapshot` / `_flushSnapshot` par un unique `late final SnapshotWriter _snapshotWriter;`, initialisé dans `initState()` juste après `_sessionService` ;
- `_saveSnapshot()` devient `_snapshotWriter.schedule(_session!)` (avec la garde `if (_session == null) return;`) ;
- `dispose()` appelle `_snapshotWriter.disposeAndFlush()` ;
- le chemin de fin de partie appelle `await _snapshotWriter.cancelPending()` avant `clearSnapshot()` ;
- remplacer le champ `_currentFormat` par `GameFormat get _currentFormat => _session?.format ?? GameFormat.builtInFormats.first;` et supprimer ses deux affectations.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/snapshot_writer_test.dart`
Expected: PASS (5 tests)

Run: `flutter test`
Expected: PASS — les tests de débounce, de flush au démontage et de course posés au lot 1 dans `test/pages/life_counter/life_counter_page_test.dart` doivent **rester verts sans modification**. S'ils cassent, le comportement a changé : c'est un défaut, pas un test à ajuster.

Vérifier que les champs ont bien disparu :

```bash
grep -n "_snapshotDebounce\|_pendingSnapshotSession\|_inFlightSnapshotWrite\|_currentFormat = " lib/pages/life_counter/life_counter_page.dart
```

Attendu : sortie vide.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract SnapshotWriter and derive _currentFormat

Solde les deux points parques a la fin du lot 1. Les trois champs de
snapshot et leurs 35 lignes de commentaire deviennent une classe testable
seule ; _currentFormat devient un getter derive de la session, supprimant
le dernier etat derive encore detenu par la page.

Comportement inchange : les tests de debounce, de flush au demontage et de
course poses au lot 1 restent verts sans modification.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Critères de sortie du lot

- [ ] `flutter test` vert sur toute la suite.
- [ ] `flutter analyze` sans erreur ni avertissement sur les fichiers touchés.
- [ ] `grep -rn "CounterMode" lib/` ne retourne rien.
- [ ] `grep -rn "counter_strip" lib/ test/` ne retourne rien.
- [ ] `grep -n "_currentFormat = \|_snapshotDebounce\|_pendingSnapshotSession\|_inFlightSnapshotWrite" lib/pages/life_counter/life_counter_page.dart` ne retourne rien.
- [ ] `wc -l lib/widgets/life_counter/player_zone.dart` est nettement sous 500.
- [ ] Aucun nouveau hook `@visibleForTesting` : `grep -c "@visibleForTesting" lib/pages/life_counter/life_counter_page.dart` est ≤ 4.
- [ ] **Vérification manuelle — saisie.** Partie à 4 : taper ±1 de chaque côté, maintenir pour vérifier l'accélération, appui long pour le mode ajustement, molette sur un gros montant, paliers, relâcher.
- [ ] **Vérification manuelle — poignée.** Le chiffre de PV ne se recale pas quand un compteur passe de 0 à 1, y compris à 8 joueurs.
- [ ] **Vérification manuelle — tiroir.** Ouverture depuis la poignée ; monarque, élimination et réinitialisation se comportent comme l'ancien menu radial.

## Ce que ce lot ne fait pas

- **La vue table** (geste à deux doigts, spec §2.3) — lot 3.
- **La grille de commander damage dans le tiroir** et **l'attribution à la volée** (spec §2.6) — lot 3.
- **Le toggle « Timer de partie »** du setup — lot 4, où `GameSetupModal` est remplacé.
- **Les compteurs personnalisés** (spec §3.5) — lot 5. Le tiroir de la tâche 5 code les trois compteurs en dur ; c'est le lot 5 qui les rendra dynamiques via `CounterType`.
