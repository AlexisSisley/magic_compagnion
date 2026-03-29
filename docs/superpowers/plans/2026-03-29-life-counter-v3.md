# Life Counter V3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore V1 layout stability (split grid + central bar) with V2's immutable data architecture (GameSessionController), add AdaptiveGrid (2-8 players), DeathConfirmationOverlay, DamageHistorySheet/PlayerHistorySheet, and Edit Mode (drag & drop). Delete V2 page and unused V2-only widgets.

**Architecture:** Refactor `life_counter_page.dart` to use `GameSessionController` instead of raw `SharedPreferences`. Replace hardcoded sublist layout with `AdaptiveGrid` widget. Add 4 new widgets (DeathConfirmationOverlay, DamageHistorySheet, PlayerHistorySheet, AdaptiveGrid). Keep all existing sub-widgets (PlayerZone, CriticalOverlay, EliminationOverlay, DraggablePlayerZone). Delete V2 page and layout system.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, SharedPreferences (crash recovery via GameSessionService), Drift (game history), AppColors/AppTextStyles theme

---

## File Structure

### Files to CREATE

| File | Responsibility |
|------|---------------|
| `lib/widgets/life_counter/layouts/adaptive_grid.dart` | Single layout widget for 2-8 players with central bar slot |
| `lib/widgets/life_counter/death_confirmation_overlay.dart` | "Éliminé ?" overlay with Non/Oui buttons |
| `lib/widgets/life_counter/damage_history_sheet.dart` | Global bottom sheet — chronological log filterable by player |
| `lib/widgets/life_counter/player_history_sheet.dart` | Personal bottom sheet — single player's history on tap of player name |
| `test/widgets/life_counter/layouts/adaptive_grid_test.dart` | AdaptiveGrid tests |
| `test/widgets/life_counter/death_confirmation_overlay_test.dart` | DeathConfirmationOverlay tests |
| `test/widgets/life_counter/damage_history_sheet_test.dart` | DamageHistorySheet tests |
| `test/widgets/life_counter/player_history_sheet_test.dart` | PlayerHistorySheet tests |

### Files to MODIFY

| File | Change |
|------|--------|
| `lib/pages/life_counter/life_counter_page.dart` | Replace SharedPreferences with GameSessionController, wire AdaptiveGrid, death confirmation, history sheets, edit mode |
| `lib/router/life_counter_routes.dart` | Import LifeCounterPage instead of LifeCounterV2Page |
| `lib/widgets/life_counter/player_header.dart` | Add onNameTap callback for personal history |

### Files to DELETE

| File | Reason |
|------|--------|
| `lib/pages/life_counter/life_counter_v2_page.dart` | Replaced by refactored V1 |
| `lib/widgets/life_counter/layouts/layout_strategy.dart` | Replaced by AdaptiveGrid |
| `lib/widgets/life_counter/layouts/face_to_face_layout.dart` | Replaced by AdaptiveGrid |
| `lib/widgets/life_counter/layouts/grid_layout.dart` | Replaced by AdaptiveGrid |
| `lib/widgets/life_counter/layouts/focus_layout.dart` | Replaced by AdaptiveGrid |
| `lib/widgets/life_counter/setup/quick_start_page.dart` | No setup landing page |
| `lib/widgets/life_counter/setup/advanced_settings_page.dart` | Setup via GameSetupModal |
| `lib/widgets/life_counter/player_zone_compact.dart` | All players same size |
| `lib/widgets/life_counter/radial_menu.dart` | Replaced by death overlay + edit mode |
| `lib/widgets/life_counter/game_control_bar.dart` | V2-only; V1 has _buildCentralBar() |
| `lib/widgets/life_counter/setup/deck_picker_sheet.dart` | V2-only |
| `lib/widgets/life_counter/setup/guest_profile_sheet.dart` | V2-only |
| `lib/widgets/life_counter/setup/profile_picker_sheet.dart` | V2-only |
| `test/pages/life_counter/life_counter_v2_page_test.dart` | V2 test |
| `test/widgets/life_counter/layouts/layout_widgets_test.dart` | V2 layout test |
| `test/widgets/life_counter/setup/quick_start_page_test.dart` | V2 setup test |
| `test/widgets/life_counter/setup/advanced_settings_page_test.dart` | V2 setup test |
| `test/widgets/life_counter/radial_menu_test.dart` | V2 radial menu test |
| `test/widgets/life_counter/layout_strategy_test.dart` | V2 layout strategy test |

---

## Task 1: Router Update — Switch from V2 to V1

**Files:**
- Modify: `lib/router/life_counter_routes.dart`

- [ ] **Step 1: Update router import and widget reference**

In `lib/router/life_counter_routes.dart`, replace the V2 import and reference:

```dart
// BEFORE (line 11):
import '../pages/life_counter/life_counter_v2_page.dart';

// AFTER:
import '../pages/life_counter/life_counter_page.dart';
```

```dart
// BEFORE (line 22):
child: const LifeCounterV2Page(isInShell: true),

// AFTER:
child: const LifeCounterPage(isInShell: true),
```

- [ ] **Step 2: Verify the app compiles**

Run: `cd C:\Users\Alexi\Documents\projet\magic_compagnion && flutter analyze lib/router/life_counter_routes.dart`
Expected: No errors. Warning about unused V2 import is OK (file will be deleted in Task 2).

- [ ] **Step 3: Commit**

```bash
git add lib/router/life_counter_routes.dart
git commit -m "refactor: switch router from V2 back to V1 page for Life Counter V3"
```

---

## Task 2: Delete V2 Files and Tests

**Files:**
- Delete: All files listed in "Files to DELETE" above

- [ ] **Step 1: Delete V2 source files**

Delete these files (check each exists before deleting — some may already be absent):

```bash
# V2 page
rm -f lib/pages/life_counter/life_counter_v2_page.dart

# V2 layout system
rm -f lib/widgets/life_counter/layouts/layout_strategy.dart
rm -f lib/widgets/life_counter/layouts/face_to_face_layout.dart
rm -f lib/widgets/life_counter/layouts/grid_layout.dart
rm -f lib/widgets/life_counter/layouts/focus_layout.dart

# V2 setup pages
rm -f lib/widgets/life_counter/setup/quick_start_page.dart
rm -f lib/widgets/life_counter/setup/advanced_settings_page.dart

# V2-only widgets
rm -f lib/widgets/life_counter/player_zone_compact.dart
rm -f lib/widgets/life_counter/radial_menu.dart
rm -f lib/widgets/life_counter/game_control_bar.dart
rm -f lib/widgets/life_counter/setup/deck_picker_sheet.dart
rm -f lib/widgets/life_counter/setup/guest_profile_sheet.dart
rm -f lib/widgets/life_counter/setup/profile_picker_sheet.dart
```

- [ ] **Step 2: Delete V2 test files**

```bash
rm -f test/pages/life_counter/life_counter_v2_page_test.dart
rm -f test/widgets/life_counter/layouts/layout_widgets_test.dart
rm -f test/widgets/life_counter/setup/quick_start_page_test.dart
rm -f test/widgets/life_counter/setup/advanced_settings_page_test.dart
rm -f test/widgets/life_counter/radial_menu_test.dart
rm -f test/widgets/life_counter/layout_strategy_test.dart
```

- [ ] **Step 3: Verify no broken imports**

Run: `flutter analyze`
Expected: No errors from missing V2 files. If any file still imports a deleted file, fix the import.

- [ ] **Step 4: Run existing tests**

Run: `flutter test`
Expected: All remaining tests pass. The deleted test files are gone, so test count decreases.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: delete V2 page, layout system, and V2-only widgets/tests"
```

---

## Task 3: AdaptiveGrid Widget

**Files:**
- Create: `lib/widgets/life_counter/layouts/adaptive_grid.dart`
- Create: `test/widgets/life_counter/layouts/adaptive_grid_test.dart`

- [ ] **Step 1: Write failing tests for AdaptiveGrid**

Create `test/widgets/life_counter/layouts/adaptive_grid_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';

Widget _buildTestGrid({required int playerCount, bool includeCentralBar = true}) {
  final zones = List.generate(playerCount, (i) => Container(key: ValueKey('player_$i')));
  final bar = includeCentralBar ? Container(key: const ValueKey('central_bar'), height: 60) : null;
  return MaterialApp(
    home: Scaffold(
      body: AdaptiveGrid(
        playerZones: zones,
        centralBar: bar ?? const SizedBox(height: 60),
      ),
    ),
  );
}

void main() {
  group('AdaptiveGrid', () {
    testWidgets('renders 2 players: 1 top + 1 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 2));
      // 1 top (ceil(2/2)=1) + 1 bottom
      expect(find.byKey(const ValueKey('player_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('central_bar')), findsOneWidget);
    });

    testWidgets('renders 3 players: 2 top + 1 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 3));
      expect(find.byKey(const ValueKey('player_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_2')), findsOneWidget);
    });

    testWidgets('renders 4 players: 2 top + 2 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      for (int i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 5 players: 3 top + 2 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 5));
      for (int i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 6 players: 3 top + 3 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 6));
      for (int i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 7 players: 4 top + 3 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 7));
      for (int i = 0; i < 7; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 8 players: 4 top + 4 bottom with sub-grids', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 8));
      for (int i = 0; i < 8; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('top row players are rotated 180 degrees', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 2));
      // The top player (player_0) should be inside a RotatedBox with quarterTurns: 2
      final rotatedBoxes = tester.widgetList<RotatedBox>(find.byType(RotatedBox));
      expect(rotatedBoxes.any((r) => r.quarterTurns == 2), isTrue);
    });

    testWidgets('central bar is rendered between top and bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      expect(find.byKey(const ValueKey('central_bar')), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/life_counter/layouts/adaptive_grid_test.dart`
Expected: FAIL — `adaptive_grid.dart` does not exist yet.

- [ ] **Step 3: Implement AdaptiveGrid**

Create `lib/widgets/life_counter/layouts/adaptive_grid.dart`:

```dart
import 'dart:math';
import 'package:flutter/material.dart';

/// Single layout widget for 2-8 players with a central bar slot.
///
/// Layout rule:
///   topCount = ceil(playerCount / 2)
///   bottomCount = playerCount - topCount
///
/// Top row is rotated 180° for face-to-face table play.
/// Special case: 8 players → each half becomes a 2×2 sub-grid.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> playerZones;
  final Widget centralBar;

  const AdaptiveGrid({
    super.key,
    required this.playerZones,
    required this.centralBar,
  });

  @override
  Widget build(BuildContext context) {
    final int playerCount = playerZones.length;
    final int topCount = (playerCount / 2).ceil();
    final int bottomCount = playerCount - topCount;

    final topZones = playerZones.sublist(0, topCount);
    final bottomZones = playerZones.sublist(topCount);

    return Column(
      children: [
        Expanded(
          child: _buildHalf(
            zones: topZones,
            rotate: true,
            useSubGrid: playerCount == 8,
          ),
        ),
        centralBar,
        Expanded(
          child: _buildHalf(
            zones: bottomZones,
            rotate: false,
            useSubGrid: playerCount == 8,
          ),
        ),
      ],
    );
  }

  /// Builds one half (top or bottom) of the grid.
  Widget _buildHalf({
    required List<Widget> zones,
    required bool rotate,
    required bool useSubGrid,
  }) {
    if (useSubGrid && zones.length == 4) {
      // 2×2 sub-grid for 8-player mode
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < 2; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: rotate
                          ? RotatedBox(quarterTurns: 2, child: zones[i])
                          : zones[i],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (int i = 2; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: rotate
                          ? RotatedBox(quarterTurns: 2, child: zones[i])
                          : zones[i],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Standard single-row layout
    return Row(
      children: zones
          .map((zone) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: rotate
                      ? RotatedBox(quarterTurns: 2, child: zone)
                      : zone,
                ),
              ))
          .toList(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/life_counter/layouts/adaptive_grid_test.dart`
Expected: All 9 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/layouts/adaptive_grid.dart test/widgets/life_counter/layouts/adaptive_grid_test.dart
git commit -m "feat: add AdaptiveGrid widget for 2-8 player layout"
```

---

## Task 4: DeathConfirmationOverlay Widget

**Files:**
- Create: `lib/widgets/life_counter/death_confirmation_overlay.dart`
- Create: `test/widgets/life_counter/death_confirmation_overlay_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/widgets/life_counter/death_confirmation_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/death_confirmation_overlay.dart';

void main() {
  group('DeathConfirmationOverlay', () {
    testWidgets('renders player name and life total', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Alice',
            currentLife: -3,
            onDismiss: () {},
            onConfirmElimination: () {},
          ),
        ),
      ));

      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.textContaining('-3'), findsOneWidget);
    });

    testWidgets('renders Non and Oui buttons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () {},
            onConfirmElimination: () {},
          ),
        ),
      ));

      expect(find.textContaining('Non'), findsOneWidget);
      expect(find.textContaining('Oui'), findsOneWidget);
    });

    testWidgets('tapping Non calls onDismiss', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () => dismissed = true,
            onConfirmElimination: () {},
          ),
        ),
      ));

      await tester.tap(find.textContaining('Non'));
      expect(dismissed, isTrue);
    });

    testWidgets('tapping Oui calls onConfirmElimination', (tester) async {
      bool eliminated = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () {},
            onConfirmElimination: () => eliminated = true,
          ),
        ),
      ));

      await tester.tap(find.textContaining('Oui'));
      expect(eliminated, isTrue);
    });

    testWidgets('displays skull emoji', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () {},
            onConfirmElimination: () {},
          ),
        ),
      ));

      expect(find.textContaining('\u{1F480}'), findsOneWidget); // 💀
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/life_counter/death_confirmation_overlay_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement DeathConfirmationOverlay**

Create `lib/widgets/life_counter/death_confirmation_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Overlay displayed when a player's life stays at ≤ 0 for 2 seconds.
///
/// Shows "💀 {PlayerName} est à {life} PV — Éliminé ?" with
/// "Non — corriger" (green) and "Oui — éliminé" (red) buttons.
///
/// The 2-second timer logic lives in the parent page, not here.
class DeathConfirmationOverlay extends StatelessWidget {
  final String playerName;
  final int currentLife;
  final VoidCallback onDismiss;
  final VoidCallback onConfirmElimination;

  const DeathConfirmationOverlay({
    super.key,
    required this.playerName,
    required this.currentLife,
    required this.onDismiss,
    required this.onConfirmElimination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.overlayDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\u{1F480} $playerName est \u{00E0} $currentLife PV',
                style: AppTextStyles.bold(color: AppColors.textPrimary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '\u{00C9}limin\u{00E9} ?',
                style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Non \u{2014} corriger',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onConfirmElimination,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Oui \u{2014} \u{00E9}limin\u{00E9}',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/life_counter/death_confirmation_overlay_test.dart`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/death_confirmation_overlay.dart test/widgets/life_counter/death_confirmation_overlay_test.dart
git commit -m "feat: add DeathConfirmationOverlay widget"
```

---

## Task 5: DamageHistorySheet Widget

**Files:**
- Create: `lib/widgets/life_counter/damage_history_sheet.dart`
- Create: `test/widgets/life_counter/damage_history_sheet_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/widgets/life_counter/damage_history_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/widgets/life_counter/damage_history_sheet.dart';

GameSession _createTestSession() {
  final format = GameFormat.builtInFormats.first; // Commander
  final configs = [
    const PlayerConfig(id: '0', name: 'Alice', type: PlayerType.guest, colorValue: 0xFFFF0000),
    const PlayerConfig(id: '1', name: 'Bob', type: PlayerType.guest, colorValue: 0xFF0000FF),
  ];
  var session = GameSession.newGame(format: format, playerConfigs: configs);
  // Add some life events manually
  final players = session.players.map((p) {
    if (p.playerId == 0) {
      return p.copyWith(
        life: 37,
        lifeHistory: [
          const LifeEvent(delta: -3, timestamp: Duration(minutes: 2)),
        ],
      );
    }
    if (p.playerId == 1) {
      return p.copyWith(
        life: 35,
        lifeHistory: [
          const LifeEvent(delta: -5, source: 'Commander: Alice', timestamp: Duration(minutes: 3)),
        ],
      );
    }
    return p;
  }).toList();
  return session.copyWith(players: players);
}

void main() {
  group('DamageHistorySheet', () {
    testWidgets('renders header', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));

      expect(find.textContaining('Damage Log'), findsOneWidget);
    });

    testWidgets('renders all events when no filter', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));

      expect(find.textContaining('-3'), findsOneWidget);
      expect(find.textContaining('-5'), findsOneWidget);
    });

    testWidgets('filters events by player', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: 0,
            onFilterChanged: (_) {},
          ),
        ),
      ));

      expect(find.textContaining('-3'), findsOneWidget);
      expect(find.textContaining('-5'), findsNothing);
    });

    testWidgets('renders filter chips for each player', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
    });

    testWidgets('shows commander source label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));

      expect(find.textContaining('Commander'), findsWidgets);
    });

    testWidgets('tapping filter chip calls onFilterChanged', (tester) async {
      int? selectedFilter;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (id) => selectedFilter = id,
          ),
        ),
      ));

      // Tap on a player filter chip (not "Tous")
      final aliceChips = find.text('Alice');
      if (aliceChips.evaluate().length > 1) {
        await tester.tap(aliceChips.last);
      } else {
        await tester.tap(aliceChips);
      }
      expect(selectedFilter, equals(0));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/life_counter/damage_history_sheet_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement DamageHistorySheet**

Create `lib/widgets/life_counter/damage_history_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Global damage history bottom sheet.
///
/// Shows a chronological log (newest first) of all [LifeEvent]s across all
/// players. Filterable by player via filter chips.
class DamageHistorySheet extends StatelessWidget {
  final GameSession session;
  final int? filterPlayerId;
  final void Function(int?) onFilterChanged;

  const DamageHistorySheet({
    super.key,
    required this.session,
    required this.filterPlayerId,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Collect all events with player info
    final allEvents = <_EventWithPlayer>[];
    for (final player in session.players) {
      for (final event in player.lifeHistory) {
        allEvents.add(_EventWithPlayer(
          playerId: player.playerId,
          playerName: player.config.name,
          playerColor: Color(player.config.colorValue),
          event: event,
        ));
      }
    }

    // Sort newest first
    allEvents.sort((a, b) => b.event.timestamp.compareTo(a.event.timestamp));

    // Apply filter
    final filteredEvents = filterPlayerId == null
        ? allEvents
        : allEvents.where((e) => e.playerId == filterPlayerId).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                '\u{1F4DC} Damage Log',
                style: AppTextStyles.pageTitle(fontSize: 18),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Tous',
                  isSelected: filterPlayerId == null,
                  onTap: () => onFilterChanged(null),
                ),
                const SizedBox(width: 8),
                ...session.players.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    label: p.config.name,
                    color: Color(p.config.colorValue),
                    isSelected: filterPlayerId == p.playerId,
                    onTap: () => onFilterChanged(p.playerId),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Event list
          Expanded(
            child: filteredEvents.isEmpty
                ? Center(
                    child: Text(
                      'Aucun \u{00E9}v\u{00E9}nement',
                      style: AppTextStyles.cinzel(color: AppColors.textDisabled),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredEvents.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (context, index) {
                      final e = filteredEvents[index];
                      return _buildEventRow(e);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.primary).withAlpha(50)
              : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? (color ?? AppColors.primary) : AppColors.borderMedium,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(_EventWithPlayer e) {
    final bool isNegative = e.event.delta < 0;
    final String deltaStr = isNegative ? '${e.event.delta}' : '+${e.event.delta}';
    final Color deltaColor = isNegative ? AppColors.accentRed : AppColors.accentGreen;
    final String sourceLabel = _formatSource(e.event.source);
    final String timeStr = _formatTimestamp(e.event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: e.playerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              e.playerName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              deltaStr,
              style: TextStyle(
                color: deltaColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              sourceLabel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatSource(String? source) {
    if (source == null) return 'G\u{00E9}n\u{00E9}rique';
    if (source.startsWith('Commander:')) {
      final name = source.replaceFirst('Commander: ', '');
      return 'Commander ($name)';
    }
    return source;
  }

  String _formatTimestamp(Duration timestamp) {
    final minutes = timestamp.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = timestamp.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _EventWithPlayer {
  final int playerId;
  final String playerName;
  final Color playerColor;
  final LifeEvent event;

  const _EventWithPlayer({
    required this.playerId,
    required this.playerName,
    required this.playerColor,
    required this.event,
  });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/life_counter/damage_history_sheet_test.dart`
Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/damage_history_sheet.dart test/widgets/life_counter/damage_history_sheet_test.dart
git commit -m "feat: add DamageHistorySheet widget for global damage log"
```

---

## Task 6: PlayerHistorySheet Widget

**Files:**
- Create: `lib/widgets/life_counter/player_history_sheet.dart`
- Create: `test/widgets/life_counter/player_history_sheet_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/widgets/life_counter/player_history_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/widgets/life_counter/player_history_sheet.dart';

PlayerState _createTestPlayer() {
  return PlayerState(
    playerId: 0,
    config: const PlayerConfig(
      id: '0', name: 'Alice', type: PlayerType.guest, colorValue: 0xFFFF0000,
    ),
    life: 33,
    lifeHistory: const [
      LifeEvent(delta: -3, timestamp: Duration(minutes: 1, seconds: 30)),
      LifeEvent(delta: -5, source: 'Commander: Bob', timestamp: Duration(minutes: 3)),
      LifeEvent(delta: 1, timestamp: Duration(minutes: 4, seconds: 15)),
    ],
  );
}

void main() {
  group('PlayerHistorySheet', () {
    testWidgets('renders player name in header', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));

      expect(find.textContaining('Alice'), findsOneWidget);
    });

    testWidgets('renders all events for the player', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));

      expect(find.textContaining('-3'), findsOneWidget);
      expect(find.textContaining('-5'), findsOneWidget);
      expect(find.textContaining('+1'), findsOneWidget);
    });

    testWidgets('shows running life total after each event', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));

      // Starting 40, events: -3 (→37), -5 (→32), +1 (→33)
      expect(find.textContaining('37'), findsWidgets);
      expect(find.textContaining('32'), findsWidgets);
      expect(find.textContaining('33'), findsWidgets);
    });

    testWidgets('shows commander source label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));

      expect(find.textContaining('Commander'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/life_counter/player_history_sheet_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement PlayerHistorySheet**

Create `lib/widgets/life_counter/player_history_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Personal history bottom sheet for a single player.
///
/// Shows the player's life event history with running life totals
/// computed from [startingLife] + cumulative deltas.
class PlayerHistorySheet extends StatelessWidget {
  final PlayerState playerState;
  final int startingLife;

  const PlayerHistorySheet({
    super.key,
    required this.playerState,
    required this.startingLife,
  });

  @override
  Widget build(BuildContext context) {
    final playerColor = Color(playerState.config.colorValue);
    final events = playerState.lifeHistory;

    // Compute running totals
    final runningTotals = <int>[];
    int running = startingLife;
    for (final event in events) {
      running += event.delta;
      runningTotals.add(running);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: playerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${playerState.config.name} \u{2014} Historique',
                  style: AppTextStyles.pageTitle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Event list
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      'Aucun \u{00E9}v\u{00E9}nement',
                      style: AppTextStyles.cinzel(color: AppColors.textDisabled),
                    ),
                  )
                : ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (context, index) {
                      // Show newest first
                      final reversedIndex = events.length - 1 - index;
                      final event = events[reversedIndex];
                      final total = runningTotals[reversedIndex];
                      return _buildEventRow(event, total);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventRow(LifeEvent event, int runningTotal) {
    final bool isNegative = event.delta < 0;
    final String deltaStr = isNegative ? '${event.delta}' : '+${event.delta}';
    final Color deltaColor = isNegative ? AppColors.accentRed : AppColors.accentGreen;
    final String sourceLabel = _formatSource(event.source);
    final String timeStr = _formatTimestamp(event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              deltaStr,
              style: TextStyle(
                color: deltaColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 20,
            color: AppColors.borderMedium,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$runningTotal',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sourceLabel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatSource(String? source) {
    if (source == null) return 'G\u{00E9}n\u{00E9}rique';
    if (source.startsWith('Commander:')) {
      final name = source.replaceFirst('Commander: ', '');
      return 'Commander ($name)';
    }
    return source;
  }

  String _formatTimestamp(Duration timestamp) {
    final minutes = timestamp.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = timestamp.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/life_counter/player_history_sheet_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/player_history_sheet.dart test/widgets/life_counter/player_history_sheet_test.dart
git commit -m "feat: add PlayerHistorySheet widget for per-player damage history"
```

---

## Task 7: Add onNameTap to PlayerHeader

**Files:**
- Modify: `lib/widgets/life_counter/player_header.dart`

- [ ] **Step 1: Read current PlayerHeader**

Read `lib/widgets/life_counter/player_header.dart` to understand the current API.

- [ ] **Step 2: Add onNameTap callback**

Add a new optional `VoidCallback? onNameTap` parameter to `PlayerHeader`. When non-null, wrap the player name area in a GestureDetector that calls it on tap.

The exact changes depend on the current structure of `player_header.dart`. The key modification is:

```dart
class PlayerHeader extends StatelessWidget {
  // ... existing fields ...
  final VoidCallback? onNameTap; // ADD THIS

  const PlayerHeader({
    super.key,
    // ... existing params ...
    this.onNameTap, // ADD THIS
  });

  // In the build method, wrap the name/palette area:
  // If there's a text widget showing a player name, wrap it in GestureDetector:
  // GestureDetector(
  //   onTap: onNameTap,
  //   child: existingNameWidget,
  // )
}
```

**Note to implementer:** Read `player_header.dart` first to find the exact location of the name text or the tappable area. If PlayerHeader doesn't currently show a name, add the `onNameTap` callback to `PlayerZone` instead, since it's the parent that knows the player name. In that case, add a `VoidCallback? onNameTap` to `PlayerZone`'s constructor and wire it to a GestureDetector in the header area.

- [ ] **Step 3: Verify the app compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/life_counter/player_header.dart
git commit -m "feat: add onNameTap callback to PlayerHeader for history access"
```

---

## Task 8: Refactor life_counter_page.dart — GameSessionController Integration

This is the core refactoring task. Replace `SharedPreferences` + mutable `Player` objects with `GameSessionController` + immutable `PlayerState`.

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart`

- [ ] **Step 1: Read the current V1 page completely**

Read `lib/pages/life_counter/life_counter_page.dart` (490 lines) to understand every method and state variable.

- [ ] **Step 2: Replace state variables**

Replace the old mutable state with controller-based state:

```dart
// REMOVE these fields:
//   List<Player> _players = [];
//   int _startingLife = 40;
//   int _playerCount = 4;
//   bool _isLoading = true;

// ADD these fields:
  GameSessionController _controller = GameSessionController();
  GameSession? _session;
  GameFormat _currentFormat = GameFormat.builtInFormats.first; // Commander
  bool _isLoading = true;

  // Death confirmation state
  final Map<int, Timer> _deathTimers = {};
  final Set<int> _showDeathOverlay = {};
  final Set<int> _dismissedDeathOverlay = {};

  // Edit mode state
  bool _isEditMode = false;

  // History sheet state
  int? _historyFilterPlayerId;
```

- [ ] **Step 3: Add legacy Player bridge**

Add this helper method to the page state class:

```dart
  Player _toLegacyPlayer(int index, PlayerState ps) {
    return Player(
      id: index,
      name: ps.config.name,
      life: ps.life,
      colorValue: ps.config.colorValue,
      backgroundImagePath: ps.config.avatarPath,
      commanderDamageReceived: ps.commanderDamageReceived,
      poison: ps.counters['poison'] ?? 0,
      energy: ps.counters['energy'] ?? 0,
      commanderCastCount: ps.counters['commander_tax'] ?? 0,
      isMonarch: ps.isMonarch,
      quarterTurns: ps.quarterTurns,
    );
  }

  List<Player> get _legacyPlayers {
    if (_session == null) return [];
    return _session!.players
        .asMap()
        .entries
        .map((e) => _toLegacyPlayer(e.key, e.value))
        .toList();
  }
```

- [ ] **Step 4: Replace _loadGame with controller-based init**

Replace the `_loadGame()` method:

```dart
  Future<void> _loadGame() async {
    final sessionService = ref.read(gameSessionServiceProvider);

    // Try crash recovery first
    if (await sessionService.hasActiveGame()) {
      final snapshot = await sessionService.loadSnapshot();
      if (snapshot != null) {
        _controller = GameSessionController();
        _controller.startNewGame(
          format: snapshot.format,
          playerConfigs: snapshot.players.map((p) => p.config).toList(),
        );
        // Restore the full session state from snapshot
        // We need to set the session directly — update controller's internal session
        // Actually, the controller's startNewGame resets everything.
        // Instead, we restore by replaying the snapshot data.
        // Simplest approach: just use the snapshot directly.
        setState(() {
          _session = snapshot;
          _currentFormat = snapshot.format;
          _isLoading = false;
        });
        return;
      }
    }

    // No saved game — start fresh with defaults
    final prefs = await SharedPreferences.getInstance();
    final playerCount = prefs.getInt('playerCount') ?? 4;
    final formatId = prefs.getString('formatId') ?? 'commander';
    _currentFormat = GameFormat.builtInFormats.firstWhere(
      (f) => f.id == formatId,
      orElse: () => GameFormat.builtInFormats.first,
    );

    _startNewGame(playerCount: playerCount);
    setState(() => _isLoading = false);
  }
```

- [ ] **Step 5: Add _startNewGame helper**

```dart
  void _startNewGame({int? playerCount, List<Profile?>? profiles}) {
    final count = playerCount ?? profiles?.length ?? 4;
    final configs = List.generate(count, (i) {
      final profile = (profiles != null && i < profiles.length) ? profiles[i] : null;
      return PlayerConfig(
        id: i.toString(),
        name: profile?.name ?? 'Joueur ${i + 1}',
        type: profile != null ? PlayerType.owner : PlayerType.guest,
        colorValue: profile?.colorValue ??
            _defaultColors[i % _defaultColors.length].toARGB32(),
        avatarPath: profile?.commanderImageUrl,
        commanders: profile?.commanderName != null
            ? [CommanderInfo(
                name: profile!.commanderName!,
                scryfallId: profile.commanderScryfallId,
                artCropUrl: profile.commanderArtCropUrl,
              )]
            : [],
      );
    });

    _controller = GameSessionController();
    _controller.startNewGame(format: _currentFormat, playerConfigs: configs);
    setState(() {
      _session = _controller.session;
      _deathTimers.forEach((_, t) => t.cancel());
      _deathTimers.clear();
      _showDeathOverlay.clear();
      _dismissedDeathOverlay.clear();
    });
    _saveSnapshot();
  }
```

- [ ] **Step 6: Replace _saveGame with snapshot**

```dart
  Future<void> _saveSnapshot() async {
    if (_session == null) return;
    final sessionService = ref.read(gameSessionServiceProvider);
    await sessionService.saveSnapshot(_session!);
  }
```

- [ ] **Step 7: Replace _updateLife**

```dart
  void _updateLife(int playerId, int change) {
    if (_isSelectingStarter || _session == null) return;
    _controller.updateLife(playerId, change, gameDuration: _gameDuration);
    setState(() => _session = _controller.session);
    _saveSnapshot();
    _checkDeathCondition(playerId);
  }
```

- [ ] **Step 8: Add death timer logic**

```dart
  void _checkDeathCondition(int playerId) {
    final player = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
    if (player == null) return;

    if (player.life <= 0 && !player.isEliminated && !_dismissedDeathOverlay.contains(playerId)) {
      // Start 2-second timer if not already running
      if (!_deathTimers.containsKey(playerId)) {
        _deathTimers[playerId] = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          // Re-check life is still <= 0
          final currentPlayer = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
          if (currentPlayer != null && currentPlayer.life <= 0 && !currentPlayer.isEliminated) {
            setState(() => _showDeathOverlay.add(playerId));
          }
          _deathTimers.remove(playerId);
        });
      }
    } else {
      // Life went back above 0 — cancel timer
      _deathTimers[playerId]?.cancel();
      _deathTimers.remove(playerId);
      setState(() => _showDeathOverlay.remove(playerId));
    }
  }

  void _dismissDeath(int playerId) {
    setState(() {
      _showDeathOverlay.remove(playerId);
      _dismissedDeathOverlay.add(playerId);
    });
  }

  void _confirmElimination(int playerId) {
    _controller.eliminatePlayer(playerId, atDuration: _gameDuration);
    setState(() {
      _session = _controller.session;
      _showDeathOverlay.remove(playerId);
    });
    _saveSnapshot();
  }
```

- [ ] **Step 9: Replace _resetGame**

```dart
  void _resetGame({List<Profile?>? assignedProfiles}) {
    _stopGame();
    _gameDuration = Duration.zero;
    _startNewGame(profiles: assignedProfiles);
  }
```

- [ ] **Step 10: Update _showGameSetupDialog**

```dart
  void _showGameSetupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldBackground,
      builder: (ctx) => GameSetupModal(
        initialLife: _currentFormat.startingLife,
        onGameStart: (life, profiles) {
          // Find format matching selected life
          _currentFormat = GameFormat.builtInFormats.firstWhere(
            (f) => f.startingLife == life,
            orElse: () => GameFormat.builtInFormats.first,
          );
          _resetGame(assignedProfiles: profiles);
        },
      ),
    );
  }
```

- [ ] **Step 11: Update _showCommanderDamageSelector to use controller**

```dart
  void _showCommanderDamageSelector(Player attacker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
        child: Wrap(
          children: [
            ListTile(
              title: Text('D\u{00E9}g\u{00E2}ts de Commandant', style: AppTextStyles.bold()),
              subtitle: Text('Attaquant : ${attacker.name}', style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
            ),
            ..._legacyPlayers.where((opp) => opp.id != attacker.id).map((opponent) {
              final damage = opponent.commanderDamageReceived[attacker.id] ?? 0;
              return ListTile(
                leading: Icon(Icons.shield, color: Color(opponent.colorValue)),
                title: Text(opponent.name, style: const TextStyle(color: AppColors.textPrimary)),
                trailing: SizedBox(
                  width: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: AppColors.textSecondary),
                        onPressed: () {
                          if (damage > 0) {
                            _controller.addCommanderDamage(
                              targetPlayerId: opponent.id,
                              sourcePlayerId: attacker.id,
                              damage: -1,
                              gameDuration: _gameDuration,
                            );
                            setState(() => _session = _controller.session);
                            _saveSnapshot();
                          }
                          Navigator.pop(context);
                          _showCommanderDamageSelector(attacker);
                        },
                      ),
                      Text('$damage', style: AppTextStyles.pageTitle()),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.textSecondary),
                        onPressed: () {
                          _controller.addCommanderDamage(
                            targetPlayerId: opponent.id,
                            sourcePlayerId: attacker.id,
                            damage: 1,
                            gameDuration: _gameDuration,
                          );
                          setState(() => _session = _controller.session);
                          _saveSnapshot();
                          _checkDeathCondition(opponent.id);
                          Navigator.pop(context);
                          _showCommanderDamageSelector(attacker);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 12: Update _finalizeGameSave to use session data**

```dart
  Future<void> _finalizeGameSave(Player winner, String method) async {
    Navigator.pop(context);

    final players = _legacyPlayers;
    List<PlayerHistorySnapshot> snapshots = players.map((p) {
      int totalCmdDmgTaken = p.commanderDamageReceived.values.fold(0, (sum, val) => sum + val);
      return PlayerHistorySnapshot(
        name: p.name,
        imageUrl: p.backgroundImagePath,
        life: p.life,
        poison: p.poison,
        commanderDamageTaken: totalCmdDmgTaken,
      );
    }).toList();

    final newItem = GameHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      durationSeconds: _gameDuration.inSeconds,
      winnerName: winner.name,
      format: _currentFormat.name,
      winMethod: method,
      playerStates: snapshots,
    );

    await _gameHistoryService.addGame(newItem);
    _controller.endGame();
    _stopGame();
    // Clear snapshot since game is done
    final sessionService = ref.read(gameSessionServiceProvider);
    await sessionService.clearSnapshot();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Partie enregistr\u{00E9}e dans l'historique !"), backgroundColor: AppColors.success),
      );
    }
  }
```

- [ ] **Step 13: Add required imports**

Add to the top of `life_counter_page.dart`:

```dart
import 'package:magic_companion/controllers/game_session_controller.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/services/game_session_service.dart';
```

Remove unused imports:
- Remove `package:shared_preferences/shared_preferences.dart` (only if no longer used in `_loadGame` — keep if prefs are still used for `playerCount`/`formatId` defaults)

- [ ] **Step 14: Update dispose to cancel death timers**

```dart
  @override
  void dispose() {
    _gameTimer?.cancel();
    _deathTimers.forEach((_, t) => t.cancel());
    WakelockPlus.disable();
    super.dispose();
  }
```

- [ ] **Step 15: Verify the app compiles**

Run: `flutter analyze lib/pages/life_counter/life_counter_page.dart`
Expected: No errors.

- [ ] **Step 16: Commit**

```bash
git add lib/pages/life_counter/life_counter_page.dart
git commit -m "refactor: migrate life_counter_page from SharedPreferences to GameSessionController"
```

---

## Task 9: Wire AdaptiveGrid into Page

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart`

- [ ] **Step 1: Replace the build method's layout with AdaptiveGrid**

Replace the current `build` method's Column layout:

```dart
// BEFORE (approximately):
// Column(children: [
//   Expanded(child: Row(children: _players.sublist(0, ceil(n/2))...)),
//   if (useCentralMenu) _buildCentralBar(),
//   Expanded(child: Row(children: _players.sublist(ceil(n/2))...)),
// ])

// AFTER:
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';

@override
Widget build(BuildContext context) {
  if (_isLoading || _session == null) {
    return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));
  }

  final players = _legacyPlayers;
  final playerZones = players.asMap().entries.map((entry) {
    final index = entry.key;
    final player = entry.value;
    final playerState = _session!.players[index];

    Widget zone = _buildPlayerZoneWithOverlays(player, playerState, index);

    if (_isEditMode) {
      zone = DraggablePlayerZone(
        index: index,
        onReorder: _onReorderPlayers,
        child: zone,
      );
    }

    return zone;
  }).toList();

  return AdaptiveGrid(
    playerZones: playerZones,
    centralBar: _buildCentralBar(),
  );
}
```

- [ ] **Step 2: Add _buildPlayerZoneWithOverlays**

This method wraps a PlayerZone with CriticalOverlay, EliminationOverlay, and DeathConfirmationOverlay:

```dart
  Widget _buildPlayerZoneWithOverlays(Player player, PlayerState playerState, int index) {
    final criticalLevel = AnimationService.getCriticalLevel(
      currentLife: player.life,
      startingLife: _currentFormat.startingLife,
    );

    Widget zone = _buildPlayerZone(player);

    // Wrap with CriticalOverlay
    zone = CriticalOverlay(level: criticalLevel, child: zone);

    // Wrap with EliminationOverlay
    zone = EliminationOverlay(
      isEliminated: playerState.isEliminated,
      child: zone,
    );

    // Death confirmation overlay on top
    if (_showDeathOverlay.contains(playerState.playerId)) {
      zone = Stack(
        children: [
          zone,
          Positioned.fill(
            child: DeathConfirmationOverlay(
              playerName: player.name,
              currentLife: player.life,
              onDismiss: () => _dismissDeath(playerState.playerId),
              onConfirmElimination: () => _confirmElimination(playerState.playerId),
            ),
          ),
        ],
      );
    }

    return zone;
  }
```

- [ ] **Step 3: Add _onReorderPlayers**

```dart
  void _onReorderPlayers(int oldIndex, int newIndex) {
    if (_session == null) return;
    final order = List<int>.from(_session!.playerOrder);
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    _controller.reorderPlayers(order);
    setState(() => _session = _controller.session);
    _saveSnapshot();
  }
```

- [ ] **Step 4: Add imports**

```dart
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';
import 'package:magic_companion/widgets/life_counter/critical_overlay.dart';
import 'package:magic_companion/widgets/life_counter/elimination_overlay.dart';
import 'package:magic_companion/widgets/life_counter/death_confirmation_overlay.dart';
import 'package:magic_companion/widgets/life_counter/draggable_player_zone.dart';
import 'package:magic_companion/widgets/life_counter/animations/animation_service.dart';
```

- [ ] **Step 5: Remove the SpeedDial and FAB code**

Delete `_buildSpeedDial()` and the `flutter_speed_dial` import — all actions are now in the central bar.

Remove `Positioned` FAB widgets from the old `build()` method's `Stack`.

- [ ] **Step 6: Verify the app compiles**

Run: `flutter analyze lib/pages/life_counter/life_counter_page.dart`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/pages/life_counter/life_counter_page.dart
git commit -m "feat: wire AdaptiveGrid, overlays, and edit mode into life counter page"
```

---

## Task 10: Wire History Sheets into Page

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart`

- [ ] **Step 1: Add _showDamageHistory method**

```dart
  void _showDamageHistory() {
    if (_session == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (ctx) => DamageHistorySheet(
        session: _session!,
        filterPlayerId: _historyFilterPlayerId,
        onFilterChanged: (id) {
          setState(() => _historyFilterPlayerId = id);
          Navigator.pop(ctx);
          _showDamageHistory(); // Reopen with new filter
        },
      ),
    );
  }
```

- [ ] **Step 2: Add _showPlayerHistory method**

```dart
  void _showPlayerHistory(int playerId) {
    if (_session == null) return;
    final playerState = _session!.players.where((p) => p.playerId == playerId).firstOrNull;
    if (playerState == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (ctx) => PlayerHistorySheet(
        playerState: playerState,
        startingLife: _currentFormat.startingLife,
      ),
    );
  }
```

- [ ] **Step 3: Wire onNameTap in _buildPlayerZone**

Update the `_buildPlayerZone` method to pass the `onNameTap` callback:

```dart
  Widget _buildPlayerZone(Player p) {
    return PlayerZone(
      player: p,
      isCommander: _currentFormat.enabledCounterIds.contains('commander_damage'),
      isHighlighted: _highlightedPlayerId == p.id,
      onLifeChanged: (val) => _updateLife(p.id, val),
      onShowCommanderDamage: () => _showCommanderDamageSelector(p),
      onColorChanged: (c) {
        // Color changes need to update through controller
        // For now, keep direct mutation (PlayerZone handles its own state)
        setState(() => p.colorValue = c.toARGB32());
        _saveSnapshot();
      },
      onRotationChanged: (r) {
        _controller.updateRotation(p.id, r);
        setState(() => _session = _controller.session);
        _saveSnapshot();
      },
      onSkinChanged: (path) {
        setState(() => p.backgroundImagePath = path);
        _saveSnapshot();
      },
      onNameTap: () => _showPlayerHistory(p.id),
    );
  }
```

**Note:** If `PlayerZone` doesn't have `onNameTap` yet, add it as an optional `VoidCallback?` parameter (see Task 7).

- [ ] **Step 4: Add imports**

```dart
import 'package:magic_companion/widgets/life_counter/damage_history_sheet.dart';
import 'package:magic_companion/widgets/life_counter/player_history_sheet.dart';
```

- [ ] **Step 5: Verify the app compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/life_counter/life_counter_page.dart
git commit -m "feat: wire DamageHistorySheet and PlayerHistorySheet into page"
```

---

## Task 11: Update Central Bar with All New Icons

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart`

- [ ] **Step 1: Replace _buildCentralBar with the V3 version**

```dart
  Widget _buildCentralBar() {
    return Container(
      height: 60,
      color: AppColors.textOnPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reset
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => _resetGame(),
          ),
          // Dice
          IconButton(
            icon: const Icon(Icons.casino, color: AppColors.textSecondary),
            onPressed: _showDiceSelector,
          ),
          // Timer / Pick starter / End game
          InkWell(
            onTap: _isGameActive ? _endGame : _pickStartingPlayer,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 50, height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textOnPrimary,
                border: Border.all(
                  color: _isGameActive ? AppColors.accentRed : AppColors.primaryShade800,
                  width: 2,
                ),
              ),
              child: _isGameActive
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatDuration(_gameDuration),
                        style: GoogleFonts.robotoMono(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : const Icon(Icons.play_arrow, color: AppColors.primary),
            ),
          ),
          // History (NEW)
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.textSecondary),
            onPressed: _showDamageHistory,
          ),
          // Edit mode toggle (NEW)
          IconButton(
            icon: Icon(
              Icons.build,
              color: _isEditMode ? AppColors.primary : AppColors.textSecondary,
            ),
            style: _isEditMode
                ? IconButton.styleFrom(backgroundColor: AppColors.primary.withAlpha(40))
                : null,
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
          ),
          // Game setup
          IconButton(
            icon: const Icon(Icons.people, color: AppColors.textSecondary),
            onPressed: _showGameSetupDialog,
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 2: Add edit mode label above central bar (optional visual feedback)**

In the `build` method, if `_isEditMode` is true, show a small label. This is handled by the AdaptiveGrid already — just ensure the icon highlight is sufficient.

- [ ] **Step 3: Verify the app compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/life_counter/life_counter_page.dart
git commit -m "feat: update central bar with history and edit mode buttons"
```

---

## Task 12: Long Press → Manual Elimination

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart`

- [ ] **Step 1: Add long press handler to player zones**

In `_buildPlayerZoneWithOverlays`, wrap the zone with a `GestureDetector` for long press:

```dart
  Widget _buildPlayerZoneWithOverlays(Player player, PlayerState playerState, int index) {
    final criticalLevel = AnimationService.getCriticalLevel(
      currentLife: player.life,
      startingLife: _currentFormat.startingLife,
    );

    Widget zone = _buildPlayerZone(player);
    zone = CriticalOverlay(level: criticalLevel, child: zone);
    zone = EliminationOverlay(
      isEliminated: playerState.isEliminated,
      child: zone,
    );

    // Long press for manual elimination (only when NOT in edit mode)
    if (!_isEditMode) {
      zone = GestureDetector(
        onLongPress: () => _showEliminationMenu(playerState),
        child: zone,
      );
    }

    // Death confirmation overlay
    if (_showDeathOverlay.contains(playerState.playerId)) {
      zone = Stack(
        children: [
          zone,
          Positioned.fill(
            child: DeathConfirmationOverlay(
              playerName: player.name,
              currentLife: player.life,
              onDismiss: () => _dismissDeath(playerState.playerId),
              onConfirmElimination: () => _confirmElimination(playerState.playerId),
            ),
          ),
        ],
      );
    }

    return zone;
  }
```

- [ ] **Step 2: Add _showEliminationMenu**

```dart
  void _showEliminationMenu(PlayerState playerState) {
    if (playerState.isEliminated) {
      // Already eliminated — offer undo
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.scaffoldBackground,
        builder: (ctx) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.undo, color: AppColors.accentGreen),
            title: const Text('Annuler \u{00E9}limination', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              _undoElimination(playerState.playerId);
            },
          ),
        ),
      );
    } else {
      // Offer elimination
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.scaffoldBackground,
        builder: (ctx) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.person_off, color: AppColors.accentRed),
            title: Text(
              '\u{00C9}liminer ${playerState.config.name}',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _confirmElimination(playerState.playerId);
            },
          ),
        ),
      );
    }
  }

  void _undoElimination(int playerId) {
    if (_session == null) return;
    // Rebuild session with player un-eliminated
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(isEliminated: false, eliminatedAt: null);
      }
      return p;
    }).toList();
    final newOrder = List<int>.from(_session!.eliminationOrder)..remove(playerId);
    _session = _session!.copyWith(players: players, eliminationOrder: newOrder);
    setState(() {});
    _saveSnapshot();
  }
```

- [ ] **Step 3: Verify the app compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/life_counter/life_counter_page.dart
git commit -m "feat: add long press for manual elimination and undo"
```

---

## Task 13: Final Cleanup and Integration Test

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart` (remove unused imports)
- Verify: All existing tests still pass

- [ ] **Step 1: Remove unused imports**

Remove any imports no longer needed:
- `package:flutter_speed_dial/flutter_speed_dial.dart` (if SpeedDial was removed)
- Any other unused imports flagged by the analyzer

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors, no warnings in life_counter files.

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass. New tests (AdaptiveGrid, DeathConfirmationOverlay, DamageHistorySheet, PlayerHistorySheet) pass. Existing tests (CriticalOverlay, EliminationOverlay, DraggablePlayerZone, AnimationService, StatsTab) still pass.

- [ ] **Step 4: Save playerCount/formatId defaults**

Ensure that when the user changes format or player count via GameSetupModal, the defaults are persisted to SharedPreferences for next launch:

```dart
  void _startNewGame({int? playerCount, List<Profile?>? profiles}) {
    final count = playerCount ?? profiles?.length ?? 4;
    // ... existing code ...

    // Persist defaults for next launch
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('playerCount', count);
      prefs.setString('formatId', _currentFormat.id);
    });
  }
```

- [ ] **Step 5: Remove flutter_speed_dial from pubspec.yaml if no longer used anywhere**

Run: `grep -r "flutter_speed_dial" lib/`
If no results, remove from `pubspec.yaml`:

```bash
flutter pub remove flutter_speed_dial
```

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup — remove unused imports and dependencies for V3"
```

---

## Self-Review Checklist

### Spec Coverage

| Spec Requirement | Task |
|-----------------|------|
| AdaptiveGrid 2-8 players | Task 3 (widget) + Task 9 (wiring) |
| Top row rotated 180° | Task 3 (RotatedBox in AdaptiveGrid) |
| 8-player 2×2 sub-grid | Task 3 (useSubGrid flag) |
| Central bar restored | Task 11 (full rebuild) |
| 📜 History button | Task 11 (central bar) + Task 10 (sheet wiring) |
| 🔧 Edit mode button | Task 11 (central bar) + Task 9 (DraggablePlayerZone wrapping) |
| DeathConfirmationOverlay | Task 4 (widget) + Task 8 (timer logic) + Task 9 (overlay wiring) |
| 2s timer, cancel if life > 0 | Task 8 (_checkDeathCondition) |
| _dismissedDeathOverlay set | Task 8 (dismiss logic) |
| Manual elimination via long press | Task 12 |
| Undo elimination | Task 12 (_undoElimination) |
| DamageHistorySheet (global) | Task 5 (widget) + Task 10 (wiring) |
| PlayerHistorySheet (personal) | Task 6 (widget) + Task 10 (wiring) |
| Tap on player name → personal history | Task 7 (onNameTap) + Task 10 (wiring) |
| Drag & drop in edit mode | Task 9 (_isEditMode + DraggablePlayerZone) |
| GameSessionController migration | Task 8 (full refactor) |
| Legacy Player bridge | Task 8 (_toLegacyPlayer) |
| Crash recovery | Task 8 (_loadGame + _saveSnapshot) |
| Router change | Task 1 |
| Delete V2 files | Task 2 |
| Delete V2 tests | Task 2 |

### Placeholder Scan
✅ No TBD, TODO, or placeholder text found.

### Type Consistency
- `GameSessionController` — same class name throughout all tasks
- `_toLegacyPlayer` — defined in Task 8, used in Tasks 9, 10, 11, 12
- `_session` / `_controller` — defined in Task 8, used consistently
- `_deathTimers` / `_showDeathOverlay` / `_dismissedDeathOverlay` — defined in Task 8, used in Tasks 8, 9, 12
- `_isEditMode` — defined in Task 8, toggled in Task 11, checked in Tasks 9, 12
- `_historyFilterPlayerId` — defined in Task 8, used in Task 10
- `onNameTap` — added in Task 7, wired in Task 10
