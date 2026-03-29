# Life Counter V3 — Design Spec

## Goal

Restore V1 stability and layout identity (central control bar, split grid) while integrating V2's data architecture (GameSessionController, LifeEvent, GameFormat) and adding three new features: adaptive grid for 2-8 players, death confirmation overlay, and damage history log. Delete V2 page and unused V2-only widgets.

## Context

The V2 rewrite introduced good data models but broke the layout (grid only handles 3-4 players, 5+ players go to an unusable "focus" mode) and the setup flow (QuickStartPage as landing slows access). The V1 layout is proven: split top/bottom with central bar works for any player count. This spec restores V1 as the main page, grafts V2's business logic onto it, and adds the requested features.

## Architecture

### Approach: V1 base + V2 graft + new features

Refactor `life_counter_page.dart` to use `GameSessionController` instead of raw `SharedPreferences` mutations. Keep the V1 layout pattern (split haut/bas + central bar) but replace the hardcoded sublist logic with `AdaptiveGrid`. Add new widgets for death confirmation and damage history.

### What we keep

| Component | Location | Role |
|-----------|----------|------|
| `life_counter_page.dart` | `lib/pages/life_counter/` | Main page — refactored to use GameSessionController |
| `GameSessionController` | `lib/controllers/` | Business logic (life, counters, commander damage, elimination, monarch, reorder) |
| `GameSession`, `PlayerState`, `LifeEvent` | `lib/models/game_session.dart` | Immutable game state with life event history |
| `GameFormat`, `PlayerConfig` | `lib/models/` | Format presets and player configuration |
| `GameSessionService` | `lib/services/` | Crash recovery via SharedPreferences snapshot |
| `PlayerZone` + sub-widgets | `lib/widgets/life_counter/` | PlayerHeader, LifeDisplay, LifeLog, CounterStrip |
| `CriticalOverlay` | `lib/widgets/life_counter/` | Animated border by critical level (safe/warning/danger/lethal) |
| `EliminationOverlay` | `lib/widgets/life_counter/` | 3-phase elimination animation (flash → cracks → dark+icon) |
| `DraggablePlayerZone` | `lib/widgets/life_counter/` | Long-press drag & drop wrapper |
| `FormatChip` | `lib/widgets/life_counter/setup/` | Shared format chip widget |
| `DiceRollAnimationDialog` | `lib/widgets/life_counter/` | Animated dice roll dialog |
| `GameSetupModal` | `lib/widgets/life_counter/` | V1 game setup bottom sheet |
| `AnimationService` | `lib/widgets/life_counter/animations/` | Critical level calculation |
| `StatsTab` | `lib/pages/life_counter/` | Game statistics tab |
| `game_history_*` pages | `lib/pages/life_counter/` | History detail pages |

### What we add

| Component | Location | Role |
|-----------|----------|------|
| `AdaptiveGrid` | `lib/widgets/life_counter/layouts/adaptive_grid.dart` | Single layout widget for 2-8 players with central bar slot |
| `DeathConfirmationOverlay` | `lib/widgets/life_counter/death_confirmation_overlay.dart` | Timer 2s → "Éliminé ?" overlay with Non/Oui |
| `DamageHistorySheet` | `lib/widgets/life_counter/damage_history_sheet.dart` | Global bottom sheet — chronological log filterable by player |
| `PlayerHistorySheet` | `lib/widgets/life_counter/player_history_sheet.dart` | Personal bottom sheet — single player's history on tap of player name |

### What we delete

| Component | Reason |
|-----------|--------|
| `life_counter_v2_page.dart` | Replaced by refactored V1 |
| `layout_strategy.dart` | LayoutResolver/LayoutType/GridLayoutConfig/FocusLayoutConfig replaced by AdaptiveGrid |
| `face_to_face_layout.dart` | Replaced by AdaptiveGrid |
| `grid_layout.dart` | Replaced by AdaptiveGrid |
| `focus_layout.dart` | Replaced by AdaptiveGrid |
| `quick_start_page.dart` | Landing is direct Life Counter; setup via GameSetupModal |
| `advanced_settings_page.dart` | Setup via GameSetupModal |
| `player_zone_compact.dart` | All players same size in AdaptiveGrid |
| `radial_menu.dart` | Replaced by death overlay + edit mode + existing commander damage sheet |
| `game_control_bar.dart` | V2-only control bar; V1 has its own `_buildCentralBar()` |
| `deck_picker_sheet.dart` | V2-only setup sheet |
| `guest_profile_sheet.dart` | V2-only setup sheet |
| `profile_picker_sheet.dart` | V2-only setup sheet |

### Router change

`life_counter_routes.dart` must point back to `LifeCounterPage` (not `LifeCounterV2Page`). After deletion of V2, this is the only page.

---

## Feature 1: Adaptive Grid

### Layout rule

The screen is split into three horizontal bands: top player zone, central bar, bottom player zone. Players are distributed evenly between top and bottom, with the top row rotated 180° for face-to-face table play.

```
topCount = ceil(playerCount / 2)
bottomCount = playerCount - topCount
```

| Players | Top (180°) | Bottom | Columns top | Columns bottom |
|---------|-----------|--------|-------------|----------------|
| 2 | 1 | 1 | 1 | 1 |
| 3 | 1 | 2 | 1 | 2 |
| 4 | 2 | 2 | 2 | 2 |
| 5 | 2 | 3 | 2 | 3 |
| 6 | 3 | 3 | 3 | 3 |
| 7 | 3 | 4 | 3 | 4 |
| 8 | 4 | 4 | 2×2 grid | 2×2 grid |

For 8 players: each half becomes a 2×2 sub-grid (2 columns × 2 rows) rather than a single row of 4, to keep zones large enough on phone screens.

### AdaptiveGrid widget API

```dart
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> playerZones; // length = playerCount
  final Widget centralBar;

  // Builds Column([topHalf, centralBar, bottomHalf])
  // topHalf = Row of RotatedBox(quarterTurns: 2, child: zone) for each top player
  // bottomHalf = Row of zones for each bottom player
  // Special case: 8 players = 2×2 sub-grids
}
```

### Central bar

Restored from V1 with additions. Icons left to right:

| Icon | Action | New? |
|------|--------|------|
| ⟲ (refresh) | Reset game | V1 |
| 🎲 (casino) | Dice selector | V1 |
| ▶ / timer | Pick starter / show timer / end game | V1 |
| 📜 (history) | Open DamageHistorySheet | **New** |
| 🔧 (build) | Toggle edit mode (drag & drop) | **New** |
| ⚙ (people) | Game setup modal | V1 |

When edit mode is active, the 🔧 icon gets a highlight (primary color background) and each PlayerZone is wrapped in `DraggablePlayerZone`.

---

## Feature 2: Death Confirmation

### Trigger conditions

The overlay triggers when a player's life total stays at ≤ 0 for 2 continuous seconds. If life goes back above 0 during the 2s window, the timer resets and no overlay appears.

Additionally, elimination can be triggered manually at any time via long press on a player zone → "Éliminer" option. This handles cases where a player dies from commander damage (21+), poison (10+), or other effects without hitting 0 life.

### Behavior

1. **Life ≤ 0**: zone pulses red (existing CriticalOverlay `lethal` level). Controls +/- remain fully active. A 2-second timer starts.

2. **After 2 seconds at ≤ 0**: `DeathConfirmationOverlay` appears over the player zone:
   - Text: "💀 {PlayerName} est à {life} PV — Éliminé ?"
   - Two buttons: "Non — corriger" (green) and "Oui — éliminé" (red)
   - The overlay does NOT block +/- controls on other player zones

3. **If "Non"**: overlay dismisses. A `_dismissedDeathOverlay` set tracks this player — the overlay will NOT appear again for this player during this game (to avoid nagging). The player can still be eliminated manually via long press.

4. **If "Oui"**: calls `GameSessionController.eliminatePlayer()`. The zone shows `EliminationOverlay` (existing 3-phase animation). The zone is grayed out with 💀 icon. Two actions remain available on eliminated zones:
   - Reset (via central bar) resets all players including eliminated ones
   - Long press → "Annuler élimination" to undo

### DeathConfirmationOverlay widget

```dart
class DeathConfirmationOverlay extends StatelessWidget {
  final String playerName;
  final int currentLife;
  final VoidCallback onDismiss; // "Non"
  final VoidCallback onConfirmElimination; // "Oui"
}
```

The 2-second timer logic lives in the parent (`life_counter_page.dart`), not in the widget. The parent manages a `Map<int, Timer> _deathTimers` and a `Set<int> _dismissedDeathOverlay`.

---

## Feature 3: Damage History

### Data source

`LifeEvent` already exists in `game_session.dart` with `delta`, `source`, and `timestamp`. The `GameSessionController.updateLife()` already creates `LifeEvent` entries in `PlayerState.lifeHistory`. This feature only needs UI to display them.

### Global history (DamageHistorySheet)

Accessed via 📜 button in central bar. Opens a modal bottom sheet.

Content:
- Header: "📜 Damage Log"
- Filter chips: "Tous" + one chip per player (colored dot + name). Tap to filter.
- Chronological list (newest first) of all LifeEvents across all players:
  - Player color dot + name
  - Delta (red for negative, green for positive, bold)
  - Source label: "Générique" (null source), "Commander ({name})" (source starts with "Commander:"), "Poison", "Energy"
  - Timestamp formatted as MM:SS from game start

```dart
class DamageHistorySheet extends StatelessWidget {
  final GameSession session;
  final int? filterPlayerId; // null = all
  final void Function(int?) onFilterChanged;
}
```

### Personal history (PlayerHistorySheet)

Accessed via tap on player name in `PlayerHeader`. Opens a modal bottom sheet.

Content:
- Header: "{PlayerName} — Historique" with player color
- Same list format as global but filtered to this player only
- Shows running life total after each event (computed from starting life + cumulative deltas)

```dart
class PlayerHistorySheet extends StatelessWidget {
  final PlayerState playerState;
  final int startingLife;
}
```

---

## Feature 4: Edit Mode (Drag & Drop)

### Activation

Toggle via 🔧 icon in central bar. A boolean `_isEditMode` in page state.

### Visual feedback when active

- 🔧 icon gets primary color background circle
- Each PlayerZone is wrapped in `DraggablePlayerZone` (existing widget: long press 1s to drag, swap on drop)
- A subtle label "Mode édition" appears above the central bar (small, semi-transparent)

### When inactive

- 🔧 icon has no highlight
- PlayerZones are NOT wrapped in DraggablePlayerZone (no drag possible)
- No "Mode édition" label

### Reorder callback

On reorder, calls `GameSessionController.reorderPlayers()` which updates the player order in the session. The grid re-renders with new order.

---

## Refactoring: V1 page → GameSessionController

The main refactoring task is migrating `life_counter_page.dart` from direct `SharedPreferences` + mutable `Player` objects to `GameSessionController` + immutable `PlayerState`.

### Key changes

1. **State**: Replace `List<Player> _players` with `GameSessionController _controller` + `GameSession? _session`. Rebuild `_legacyPlayers` list from session for PlayerZone compatibility (same bridge pattern as V2 page, proven to work).

2. **Life updates**: Replace `setState(() => player.life += change)` with `_controller.updateLife(playerId, delta, gameDuration: _gameDuration)` followed by `setState(() => _session = _controller.session)`.

3. **Save/Load**: Replace individual SharedPreferences reads/writes with `GameSessionService.saveSnapshot()` / `loadSnapshot()`. Keep SharedPreferences for `playerCount` and `startingLife` defaults.

4. **Game setup**: `GameSetupModal` continues to work — its `onGameStart(life, profiles)` callback now calls `_controller.startNewGame()` with generated `PlayerConfig` list.

5. **End game**: `_finalizeGameSave()` builds `GameHistoryItem` from `_session` (same as V2 page implementation).

### Legacy Player bridge

PlayerZone expects a `Player` object. Build it from `PlayerState`:

```dart
Player _toLegacyPlayer(int index, PlayerState ps) {
  return Player(
    id: index,
    name: ps.config.name,
    life: ps.life,
    colorValue: ps.config.colorValue,
    backgroundImagePath: null,
    commanderDamageReceived: ps.commanderDamageReceived,
    poison: ps.counters['poison'] ?? 0,
    energy: ps.counters['energy'] ?? 0,
    commanderCastCount: ps.counters['commander_tax'] ?? 0,
    isMonarch: ps.isMonarch,
    quarterTurns: ps.quarterTurns,
  );
}
```

---

## Landing screen

The Life Counter IS the landing screen (tab0 via `lifeCounterShellRoute`). On first launch or after a reset, the page shows the game grid immediately with default settings (4 players, 40 life, Commander format). No setup page in the way. The user taps ⚙ to change settings if needed.

Crash recovery: on init, check `GameSessionService.hasActiveGame()`. If yes, restore from snapshot. If no, start fresh with defaults.

---

## Testing strategy

Each new widget gets unit tests:
- `AdaptiveGrid`: verify correct split for 2, 3, 4, 5, 6, 7, 8 players. Verify top row is rotated. Verify 8-player sub-grid.
- `DeathConfirmationOverlay`: verify buttons render, callbacks fire.
- `DamageHistorySheet`: verify events render, filter works.
- `PlayerHistorySheet`: verify single-player events render with running total.
- Integration: verify death flow (life → 0 → 2s → overlay → confirm → eliminated).
- Integration: verify edit mode toggle wraps/unwraps DraggablePlayerZone.

Existing tests for CriticalOverlay, EliminationOverlay, DraggablePlayerZone, PlayerZone, DiceRollAnimationDialog remain unchanged.

V2-specific tests are deleted along with V2 files:
- `test/pages/life_counter/life_counter_v2_page_test.dart`
- `test/widgets/life_counter/layouts/layout_widgets_test.dart`
- `test/widgets/life_counter/setup/quick_start_page_test.dart`
- `test/widgets/life_counter/setup/advanced_settings_page_test.dart`
- `test/widgets/life_counter/radial_menu_test.dart`

---

## Out of scope

- Commander damage tracking UI improvements (existing bottom sheet is sufficient)
- Multiple commander support UI (model supports it, UI deferred)
- Custom format creation UI (model supports it, UI deferred)
- Deck linking in player setup (model supports it, UI deferred)
- Profile persistence across games (existing ProfileService handles this)
