# Life Counter v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the life counter system with adaptive layouts, dramatic animations, format presets, owner/guest profiles, drag & drop zones, and game stats analytics.

**Architecture:** Refactoring progressif en 6 couches du module life counter existant. Chaque couche produit du code testable et fonctionnel. Les modeles de donnees sont poses en premier (Drift tables + domain models), puis les widgets sont decomposes, le setup flow est reconstruit, les animations sont ajoutees, le layout adaptatif est branche, et enfin les stats sont calculees.

**Tech Stack:** Flutter/Dart, Riverpod (Notifier + StateNotifier), Drift (SQLite), GoRouter, SharedPreferences (crash recovery)

**Design spec:** `docs/superpowers/specs/2026-03-29-life-counter-v2-design.md`

---

## File Structure

### New Files

```
lib/models/
  game_format.dart              — GameFormat model + built-in presets
  counter_type.dart             — CounterType model + built-in counters
  player_config.dart            — PlayerConfig (owner/guest) + CommanderInfo
  game_session.dart             — GameSession, PlayerState, LifeEvent
  game_stats.dart               — Computed stats models (PlayerStats, DeckStats, etc.)

lib/services/
  game_session_service.dart     — Crash recovery (SharedPreferences snapshot)
  game_format_service.dart      — CRUD for custom formats (Drift)
  counter_type_service.dart     — CRUD for custom counters (Drift)
  player_config_service.dart    — CRUD for player configs (Drift)
  stats_service.dart            — Stats computation from game history

lib/controllers/
  game_session_controller.dart  — GameSessionNotifier (active game state)

lib/providers/
  game_session_provider.dart    — Providers for game session, formats, counters, configs
  stats_provider.dart           — StatsProvider (AsyncNotifier)

lib/widgets/life_counter/
  player_header.dart            — Name, avatar, commander artwork, color
  life_display.dart             — PV display + boutons +/-
  life_log.dart                 — Floating history of recent changes
  counter_strip.dart            — Swipeable counter strip
  critical_overlay.dart         — Border animation based on life thresholds
  elimination_overlay.dart      — Death animation + skull overlay
  radial_menu.dart              — Long press radial menu (Monarch, Cmd Dmg, Eliminate, Reset)
  player_zone_compact.dart      — Compact player zone for Focus layout adversaries
  game_control_bar.dart         — Floating bar (dice, timer, switch layout, settings, end)

lib/widgets/life_counter/layouts/
  layout_strategy.dart          — Abstract LayoutStrategy + LayoutResolver
  face_to_face_layout.dart      — 2 players layout
  grid_layout.dart              — 3-4 players layout
  focus_layout.dart             — 5-8 players layout

lib/widgets/life_counter/setup/
  quick_start_page.dart         — Format chips + player count + launch
  advanced_settings_page.dart   — Collapsible sections for full config
  deck_picker_sheet.dart        — Owner deck selection bottom sheet
  guest_profile_sheet.dart      — Guest profile edit bottom sheet
  profile_picker_sheet.dart     — Saved profiles bottom sheet

lib/widgets/life_counter/animations/
  animation_service.dart        — Centralized animation config resolver
  particle_effect.dart          — Golden particles for massive gains
  crack_effect.dart             — Elimination crack CustomPainter

lib/pages/life_counter/
  stats_tab.dart                — Stats tab alongside history

test/models/
  game_format_test.dart
  counter_type_test.dart
  player_config_test.dart
  game_session_test.dart
  game_stats_test.dart

test/services/
  game_session_service_test.dart
  game_format_service_test.dart
  stats_service_test.dart

test/controllers/
  game_session_controller_test.dart

test/widgets/life_counter/
  life_display_test.dart
  counter_strip_test.dart
  animation_service_test.dart
  layout_strategy_test.dart
```

### Modified Files

```
lib/data/database/app_database.dart   — Add new tables, bump schema to 2
lib/providers/service_providers.dart   — Add new service providers
lib/controllers/game_setup_controller.dart — Enrich with GameFormat support
lib/pages/life_counter/life_counter_page.dart — Use GameSession, new layouts
lib/widgets/life_counter/player_zone.dart — Refactor to compose sub-widgets
lib/widgets/life_counter/game_setup_modal.dart — Replace with quick start flow
lib/models/game_history_model.dart     — Enrich PlayerHistorySnapshot
lib/providers/game_history_provider.dart — Enrich with stats support
```

---

## Task 1: GameFormat Model + Built-in Presets

**Files:**
- Create: `lib/models/game_format.dart`
- Test: `test/models/game_format_test.dart`

- [ ] **Step 1: Write failing tests for GameFormat**

```dart
// test/models/game_format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/models/game_format.dart';

void main() {
  group('GameFormat', () {
    test('creates a valid format with all fields', () {
      final format = GameFormat(
        id: 'commander',
        name: 'Commander',
        startingLife: 40,
        minPlayers: 2,
        maxPlayers: 8,
        maxCommanders: 2,
        enabledCounterIds: ['poison', 'energy', 'commander_tax', 'commander_damage'],
        isBuiltIn: true,
      );

      expect(format.id, 'commander');
      expect(format.name, 'Commander');
      expect(format.startingLife, 40);
      expect(format.minPlayers, 2);
      expect(format.maxPlayers, 8);
      expect(format.maxCommanders, 2);
      expect(format.enabledCounterIds, hasLength(4));
      expect(format.isBuiltIn, true);
    });

    test('copyWith preserves values when not specified', () {
      final format = GameFormat(
        id: 'commander',
        name: 'Commander',
        startingLife: 40,
        minPlayers: 2,
        maxPlayers: 8,
        maxCommanders: 2,
        enabledCounterIds: ['poison'],
        isBuiltIn: true,
      );
      final copied = format.copyWith(startingLife: 30);
      expect(copied.name, 'Commander');
      expect(copied.startingLife, 30);
      expect(copied.maxCommanders, 2);
    });

    test('toJson and fromJson roundtrip', () {
      final format = GameFormat(
        id: 'custom-1',
        name: 'My Format',
        startingLife: 25,
        minPlayers: 2,
        maxPlayers: 6,
        maxCommanders: 3,
        enabledCounterIds: ['poison', 'energy'],
        isBuiltIn: false,
      );
      final json = format.toJson();
      final restored = GameFormat.fromJson(json);
      expect(restored.id, format.id);
      expect(restored.name, format.name);
      expect(restored.startingLife, format.startingLife);
      expect(restored.maxCommanders, format.maxCommanders);
      expect(restored.enabledCounterIds, format.enabledCounterIds);
      expect(restored.isBuiltIn, false);
    });
  });

  group('GameFormat.builtInFormats', () {
    test('contains all 6 presets', () {
      expect(GameFormat.builtInFormats, hasLength(6));
    });

    test('Commander preset has correct values', () {
      final commander = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
      expect(commander.startingLife, 40);
      expect(commander.maxPlayers, 8);
      expect(commander.maxCommanders, 2);
      expect(commander.enabledCounterIds, contains('commander_damage'));
    });

    test('Standard preset has 0 commanders', () {
      final standard = GameFormat.builtInFormats.firstWhere((f) => f.id == 'standard');
      expect(standard.startingLife, 20);
      expect(standard.maxCommanders, 0);
      expect(standard.maxPlayers, 2);
    });

    test('Custom preset has unlimited commanders', () {
      final custom = GameFormat.builtInFormats.firstWhere((f) => f.id == 'custom');
      expect(custom.maxCommanders, -1); // -1 means unlimited
      expect(custom.startingLife, 20);
    });

    test('all presets are marked isBuiltIn', () {
      for (final format in GameFormat.builtInFormats) {
        expect(format.isBuiltIn, true, reason: '${format.name} should be built-in');
      }
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/game_format_test.dart`
Expected: FAIL — `game_format.dart` does not exist.

- [ ] **Step 3: Implement GameFormat model**

```dart
// lib/models/game_format.dart

class GameFormat {
  final String id;
  final String name;
  final int startingLife;
  final int minPlayers;
  final int maxPlayers;
  final int maxCommanders; // -1 = unlimited
  final List<String> enabledCounterIds;
  final bool isBuiltIn;

  const GameFormat({
    required this.id,
    required this.name,
    required this.startingLife,
    required this.minPlayers,
    required this.maxPlayers,
    required this.maxCommanders,
    required this.enabledCounterIds,
    this.isBuiltIn = false,
  });

  GameFormat copyWith({
    String? id,
    String? name,
    int? startingLife,
    int? minPlayers,
    int? maxPlayers,
    int? maxCommanders,
    List<String>? enabledCounterIds,
    bool? isBuiltIn,
  }) {
    return GameFormat(
      id: id ?? this.id,
      name: name ?? this.name,
      startingLife: startingLife ?? this.startingLife,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      maxCommanders: maxCommanders ?? this.maxCommanders,
      enabledCounterIds: enabledCounterIds ?? this.enabledCounterIds,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startingLife': startingLife,
    'minPlayers': minPlayers,
    'maxPlayers': maxPlayers,
    'maxCommanders': maxCommanders,
    'enabledCounterIds': enabledCounterIds,
    'isBuiltIn': isBuiltIn,
  };

  factory GameFormat.fromJson(Map<String, dynamic> json) => GameFormat(
    id: json['id'] as String,
    name: json['name'] as String,
    startingLife: json['startingLife'] as int,
    minPlayers: json['minPlayers'] as int,
    maxPlayers: json['maxPlayers'] as int,
    maxCommanders: json['maxCommanders'] as int,
    enabledCounterIds: (json['enabledCounterIds'] as List).cast<String>(),
    isBuiltIn: json['isBuiltIn'] as bool? ?? false,
  );

  /// All built-in format presets
  static const List<GameFormat> builtInFormats = [
    GameFormat(
      id: 'commander',
      name: 'Commander',
      startingLife: 40,
      minPlayers: 2,
      maxPlayers: 8,
      maxCommanders: 2,
      enabledCounterIds: ['poison', 'energy', 'commander_tax', 'commander_damage'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'duel_commander',
      name: 'Duel Commander',
      startingLife: 30,
      minPlayers: 2,
      maxPlayers: 2,
      maxCommanders: 2,
      enabledCounterIds: ['poison', 'commander_damage'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'standard',
      name: 'Standard',
      startingLife: 20,
      minPlayers: 2,
      maxPlayers: 2,
      maxCommanders: 0,
      enabledCounterIds: ['poison', 'energy'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'oathbreaker',
      name: 'Oathbreaker',
      startingLife: 20,
      minPlayers: 2,
      maxPlayers: 6,
      maxCommanders: 1,
      enabledCounterIds: ['poison', 'energy'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'brawl',
      name: 'Brawl',
      startingLife: 25,
      minPlayers: 2,
      maxPlayers: 4,
      maxCommanders: 1,
      enabledCounterIds: ['poison', 'energy', 'commander_damage'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'custom',
      name: 'Custom',
      startingLife: 20,
      minPlayers: 2,
      maxPlayers: 8,
      maxCommanders: -1,
      enabledCounterIds: ['poison', 'energy', 'commander_tax', 'commander_damage'],
      isBuiltIn: true,
    ),
  ];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/game_format_test.dart`
Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/game_format.dart test/models/game_format_test.dart
git commit -m "feat: add GameFormat model with built-in presets (Commander, Standard, Duel, Oathbreaker, Brawl, Custom)"
```

---

## Task 2: CounterType Model + Built-in Counters

**Files:**
- Create: `lib/models/counter_type.dart`
- Test: `test/models/counter_type_test.dart`

- [ ] **Step 1: Write failing tests for CounterType**

```dart
// test/models/counter_type_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/models/counter_type.dart';

void main() {
  group('CounterType', () {
    test('creates a valid counter', () {
      final counter = CounterType(
        id: 'poison',
        name: 'Poison',
        emoji: '☠️',
        color: 0xFF4CAF50,
        isBuiltIn: true,
        maxValue: 10,
      );

      expect(counter.id, 'poison');
      expect(counter.name, 'Poison');
      expect(counter.maxValue, 10);
      expect(counter.isBuiltIn, true);
    });

    test('custom counter has no maxValue', () {
      final counter = CounterType(
        id: 'storm',
        name: 'Storm Count',
        emoji: '⚡',
        color: 0xFFFF9800,
        isBuiltIn: false,
      );

      expect(counter.maxValue, isNull);
      expect(counter.isBuiltIn, false);
    });

    test('copyWith preserves values', () {
      final counter = CounterType(
        id: 'poison',
        name: 'Poison',
        emoji: '☠️',
        color: 0xFF4CAF50,
        isBuiltIn: true,
        maxValue: 10,
      );
      final copied = counter.copyWith(name: 'Infect');
      expect(copied.id, 'poison');
      expect(copied.name, 'Infect');
      expect(copied.maxValue, 10);
    });

    test('toJson and fromJson roundtrip', () {
      final counter = CounterType(
        id: 'custom-1',
        name: 'Rad',
        emoji: '☢️',
        color: 0xFFFF5722,
        isBuiltIn: false,
        maxValue: null,
      );
      final json = counter.toJson();
      final restored = CounterType.fromJson(json);
      expect(restored.id, counter.id);
      expect(restored.name, counter.name);
      expect(restored.emoji, counter.emoji);
      expect(restored.maxValue, isNull);
    });
  });

  group('CounterType.builtInCounters', () {
    test('contains 4 built-in counters', () {
      expect(CounterType.builtInCounters, hasLength(4));
    });

    test('all built-in counters have isBuiltIn true', () {
      for (final c in CounterType.builtInCounters) {
        expect(c.isBuiltIn, true, reason: '${c.name} should be built-in');
      }
    });

    test('poison has maxValue 10', () {
      final poison = CounterType.builtInCounters.firstWhere((c) => c.id == 'poison');
      expect(poison.maxValue, 10);
    });

    test('energy has no maxValue', () {
      final energy = CounterType.builtInCounters.firstWhere((c) => c.id == 'energy');
      expect(energy.maxValue, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/counter_type_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement CounterType model**

```dart
// lib/models/counter_type.dart

class CounterType {
  final String id;
  final String name;
  final String emoji;
  final int color; // ARGB int
  final bool isBuiltIn;
  final int? maxValue; // null = unlimited

  const CounterType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.isBuiltIn = false,
    this.maxValue,
  });

  CounterType copyWith({
    String? id,
    String? name,
    String? emoji,
    int? color,
    bool? isBuiltIn,
    int? maxValue,
  }) {
    return CounterType(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      maxValue: maxValue ?? this.maxValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'color': color,
    'isBuiltIn': isBuiltIn,
    'maxValue': maxValue,
  };

  factory CounterType.fromJson(Map<String, dynamic> json) => CounterType(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    color: json['color'] as int,
    isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    maxValue: json['maxValue'] as int?,
  );

  static const List<CounterType> builtInCounters = [
    CounterType(
      id: 'poison',
      name: 'Poison',
      emoji: '☠️',
      color: 0xFF4CAF50,
      isBuiltIn: true,
      maxValue: 10,
    ),
    CounterType(
      id: 'energy',
      name: 'Energy',
      emoji: '⚡',
      color: 0xFFFF9800,
      isBuiltIn: true,
    ),
    CounterType(
      id: 'commander_tax',
      name: 'Commander Tax',
      emoji: '💰',
      color: 0xFFFFEB3B,
      isBuiltIn: true,
    ),
    CounterType(
      id: 'commander_damage',
      name: 'Commander Damage',
      emoji: '⚔️',
      color: 0xFFF44336,
      isBuiltIn: true,
    ),
  ];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/counter_type_test.dart`
Expected: All 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/counter_type.dart test/models/counter_type_test.dart
git commit -m "feat: add CounterType model with built-in counters (Poison, Energy, Commander Tax, Commander Damage)"
```

---

## Task 3: PlayerConfig Model (Owner vs Guest)

**Files:**
- Create: `lib/models/player_config.dart`
- Test: `test/models/player_config_test.dart`

- [ ] **Step 1: Write failing tests for PlayerConfig**

```dart
// test/models/player_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/models/player_config.dart';

void main() {
  group('CommanderInfo', () {
    test('creates with name only', () {
      final info = CommanderInfo(name: 'Atraxa');
      expect(info.name, 'Atraxa');
      expect(info.scryfallId, isNull);
      expect(info.artCropUrl, isNull);
    });

    test('toJson and fromJson roundtrip', () {
      final info = CommanderInfo(
        name: 'Korvold',
        scryfallId: 'abc-123',
        artCropUrl: 'https://example.com/art.jpg',
      );
      final json = info.toJson();
      final restored = CommanderInfo.fromJson(json);
      expect(restored.name, 'Korvold');
      expect(restored.scryfallId, 'abc-123');
      expect(restored.artCropUrl, 'https://example.com/art.jpg');
    });
  });

  group('PlayerConfig', () {
    test('creates owner config with linked deck', () {
      final config = PlayerConfig(
        id: 'owner-1',
        name: 'Alex',
        type: PlayerType.owner,
        colorValue: 0xFF0D47A1,
        linkedDeckId: 'deck-atraxa',
        commanders: [],
      );

      expect(config.type, PlayerType.owner);
      expect(config.linkedDeckId, 'deck-atraxa');
      expect(config.isOwner, true);
      expect(config.isGuest, false);
    });

    test('creates guest config with manual commanders', () {
      final config = PlayerConfig(
        id: 'guest-1',
        name: 'Max',
        type: PlayerType.guest,
        colorValue: 0xFFB71C1C,
        commanders: [
          CommanderInfo(name: 'Prossh', scryfallId: 'prossh-123'),
        ],
      );

      expect(config.type, PlayerType.guest);
      expect(config.linkedDeckId, isNull);
      expect(config.commanders, hasLength(1));
      expect(config.isOwner, false);
      expect(config.isGuest, true);
    });

    test('copyWith preserves values', () {
      final config = PlayerConfig(
        id: 'guest-1',
        name: 'Max',
        type: PlayerType.guest,
        colorValue: 0xFFB71C1C,
        commanders: [CommanderInfo(name: 'Prossh')],
      );
      final copied = config.copyWith(name: 'Maxime');
      expect(copied.id, 'guest-1');
      expect(copied.name, 'Maxime');
      expect(copied.commanders, hasLength(1));
    });

    test('toJson and fromJson roundtrip', () {
      final config = PlayerConfig(
        id: 'guest-2',
        name: 'Sarah',
        type: PlayerType.guest,
        colorValue: 0xFF4A148C,
        avatarPath: '/path/to/avatar.png',
        commanders: [
          CommanderInfo(name: 'Atraxa', scryfallId: 'atraxa-456'),
          CommanderInfo(name: 'Thrasios'),
        ],
      );
      final json = config.toJson();
      final restored = PlayerConfig.fromJson(json);
      expect(restored.id, 'guest-2');
      expect(restored.name, 'Sarah');
      expect(restored.type, PlayerType.guest);
      expect(restored.avatarPath, '/path/to/avatar.png');
      expect(restored.commanders, hasLength(2));
      expect(restored.commanders[0].name, 'Atraxa');
      expect(restored.commanders[1].name, 'Thrasios');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/player_config_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement PlayerConfig model**

```dart
// lib/models/player_config.dart

enum PlayerType { owner, guest }

class CommanderInfo {
  final String name;
  final String? scryfallId;
  final String? artCropUrl;

  const CommanderInfo({
    required this.name,
    this.scryfallId,
    this.artCropUrl,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'scryfallId': scryfallId,
    'artCropUrl': artCropUrl,
  };

  factory CommanderInfo.fromJson(Map<String, dynamic> json) => CommanderInfo(
    name: json['name'] as String,
    scryfallId: json['scryfallId'] as String?,
    artCropUrl: json['artCropUrl'] as String?,
  );
}

class PlayerConfig {
  final String id;
  final String name;
  final PlayerType type;
  final int colorValue;
  final String? avatarPath;
  final String? linkedDeckId;
  final List<CommanderInfo> commanders;

  const PlayerConfig({
    required this.id,
    required this.name,
    required this.type,
    this.colorValue = 0xFF2196F3,
    this.avatarPath,
    this.linkedDeckId,
    this.commanders = const [],
  });

  bool get isOwner => type == PlayerType.owner;
  bool get isGuest => type == PlayerType.guest;

  PlayerConfig copyWith({
    String? id,
    String? name,
    PlayerType? type,
    int? colorValue,
    String? avatarPath,
    String? linkedDeckId,
    List<CommanderInfo>? commanders,
  }) {
    return PlayerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      avatarPath: avatarPath ?? this.avatarPath,
      linkedDeckId: linkedDeckId ?? this.linkedDeckId,
      commanders: commanders ?? this.commanders,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'colorValue': colorValue,
    'avatarPath': avatarPath,
    'linkedDeckId': linkedDeckId,
    'commanders': commanders.map((c) => c.toJson()).toList(),
  };

  factory PlayerConfig.fromJson(Map<String, dynamic> json) => PlayerConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    type: PlayerType.values.firstWhere((t) => t.name == json['type']),
    colorValue: json['colorValue'] as int? ?? 0xFF2196F3,
    avatarPath: json['avatarPath'] as String?,
    linkedDeckId: json['linkedDeckId'] as String?,
    commanders: (json['commanders'] as List?)
        ?.map((c) => CommanderInfo.fromJson(c as Map<String, dynamic>))
        .toList() ?? [],
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/player_config_test.dart`
Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/player_config.dart test/models/player_config_test.dart
git commit -m "feat: add PlayerConfig model with Owner/Guest types and CommanderInfo"
```

---

## Task 4: GameSession + PlayerState + LifeEvent Models

**Files:**
- Create: `lib/models/game_session.dart`
- Test: `test/models/game_session_test.dart`

- [ ] **Step 1: Write failing tests for GameSession**

```dart
// test/models/game_session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/models/game_format.dart';
import 'package:magic_compagnion/models/player_config.dart';
import 'package:magic_compagnion/models/game_session.dart';

void main() {
  final commanderFormat = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

  group('LifeEvent', () {
    test('creates with all fields', () {
      final event = LifeEvent(
        delta: -5,
        source: 'Commander: Atraxa',
        timestamp: const Duration(minutes: 3, seconds: 22),
      );
      expect(event.delta, -5);
      expect(event.source, 'Commander: Atraxa');
      expect(event.timestamp.inSeconds, 202);
    });

    test('toJson and fromJson roundtrip', () {
      final event = LifeEvent(
        delta: 3,
        timestamp: const Duration(seconds: 120),
      );
      final json = event.toJson();
      final restored = LifeEvent.fromJson(json);
      expect(restored.delta, 3);
      expect(restored.source, isNull);
      expect(restored.timestamp.inSeconds, 120);
    });
  });

  group('PlayerState', () {
    test('creates with default values', () {
      final config = PlayerConfig(
        id: 'p1',
        name: 'Alex',
        type: PlayerType.owner,
      );
      final state = PlayerState(
        playerId: 0,
        config: config,
        life: 40,
      );

      expect(state.life, 40);
      expect(state.counters, isEmpty);
      expect(state.commanderDamageReceived, isEmpty);
      expect(state.isEliminated, false);
      expect(state.isMonarch, false);
      expect(state.lifeHistory, isEmpty);
    });

    test('copyWith updates life and preserves rest', () {
      final config = PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner);
      final state = PlayerState(playerId: 0, config: config, life: 40);
      final updated = state.copyWith(life: 35);
      expect(updated.life, 35);
      expect(updated.config.name, 'Alex');
      expect(updated.playerId, 0);
    });

    test('addLifeEvent appends to history', () {
      final config = PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner);
      final state = PlayerState(playerId: 0, config: config, life: 40);
      final event = LifeEvent(delta: -3, timestamp: const Duration(seconds: 60));
      final updated = state.copyWith(
        life: 37,
        lifeHistory: [...state.lifeHistory, event],
      );
      expect(updated.lifeHistory, hasLength(1));
      expect(updated.lifeHistory.first.delta, -3);
    });
  });

  group('GameSession', () {
    test('creates a new session from format', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
        PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
        PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
      ];

      final session = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: configs,
      );

      expect(session.format.id, 'commander');
      expect(session.players, hasLength(4));
      expect(session.players[0].life, 40);
      expect(session.players[0].config.name, 'Alex');
      expect(session.isActive, false);
      expect(session.eliminationOrder, isEmpty);
      expect(session.playerOrder, [0, 1, 2, 3]);
    });

    test('toJson and fromJson roundtrip', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: configs,
      );

      final json = session.toJson();
      final restored = GameSession.fromJson(json);

      expect(restored.id, session.id);
      expect(restored.format.id, 'commander');
      expect(restored.players, hasLength(2));
      expect(restored.players[0].config.name, 'Alex');
      expect(restored.players[1].life, 40);
    });

    test('eliminatePlayer marks player and records order', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final updated = session.eliminatePlayer(1, atDuration: const Duration(minutes: 10));

      expect(updated.players[1].isEliminated, true);
      expect(updated.players[1].eliminatedAt, const Duration(minutes: 10));
      expect(updated.eliminationOrder, [1]);
      expect(updated.players[0].isEliminated, false);
    });

    test('reorderPlayers updates playerOrder', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
        PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
        PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final reordered = session.reorderPlayers([2, 0, 3, 1]);
      expect(reordered.playerOrder, [2, 0, 3, 1]);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/game_session_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement GameSession model**

```dart
// lib/models/game_session.dart
import 'package:magic_compagnion/models/game_format.dart';
import 'package:magic_compagnion/models/player_config.dart';

class LifeEvent {
  final int delta;
  final String? source;
  final Duration timestamp;

  const LifeEvent({
    required this.delta,
    this.source,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'delta': delta,
    'source': source,
    'timestampMs': timestamp.inMilliseconds,
  };

  factory LifeEvent.fromJson(Map<String, dynamic> json) => LifeEvent(
    delta: json['delta'] as int,
    source: json['source'] as String?,
    timestamp: Duration(milliseconds: json['timestampMs'] as int),
  );
}

class PlayerState {
  final int playerId;
  final PlayerConfig config;
  final int life;
  final Map<String, int> counters;
  final Map<int, int> commanderDamageReceived;
  final bool isEliminated;
  final Duration? eliminatedAt;
  final bool isMonarch;
  final int quarterTurns;
  final List<LifeEvent> lifeHistory;

  const PlayerState({
    required this.playerId,
    required this.config,
    required this.life,
    this.counters = const {},
    this.commanderDamageReceived = const {},
    this.isEliminated = false,
    this.eliminatedAt,
    this.isMonarch = false,
    this.quarterTurns = 0,
    this.lifeHistory = const [],
  });

  PlayerState copyWith({
    int? playerId,
    PlayerConfig? config,
    int? life,
    Map<String, int>? counters,
    Map<int, int>? commanderDamageReceived,
    bool? isEliminated,
    Duration? eliminatedAt,
    bool? isMonarch,
    int? quarterTurns,
    List<LifeEvent>? lifeHistory,
  }) {
    return PlayerState(
      playerId: playerId ?? this.playerId,
      config: config ?? this.config,
      life: life ?? this.life,
      counters: counters ?? this.counters,
      commanderDamageReceived: commanderDamageReceived ?? this.commanderDamageReceived,
      isEliminated: isEliminated ?? this.isEliminated,
      eliminatedAt: eliminatedAt ?? this.eliminatedAt,
      isMonarch: isMonarch ?? this.isMonarch,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      lifeHistory: lifeHistory ?? this.lifeHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'config': config.toJson(),
    'life': life,
    'counters': counters,
    'commanderDamageReceived': commanderDamageReceived.map((k, v) => MapEntry(k.toString(), v)),
    'isEliminated': isEliminated,
    'eliminatedAtMs': eliminatedAt?.inMilliseconds,
    'isMonarch': isMonarch,
    'quarterTurns': quarterTurns,
    'lifeHistory': lifeHistory.map((e) => e.toJson()).toList(),
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    playerId: json['playerId'] as int,
    config: PlayerConfig.fromJson(json['config'] as Map<String, dynamic>),
    life: json['life'] as int,
    counters: (json['counters'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as int)) ?? {},
    commanderDamageReceived: (json['commanderDamageReceived'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(int.parse(k), v as int)) ?? {},
    isEliminated: json['isEliminated'] as bool? ?? false,
    eliminatedAt: json['eliminatedAtMs'] != null
        ? Duration(milliseconds: json['eliminatedAtMs'] as int) : null,
    isMonarch: json['isMonarch'] as bool? ?? false,
    quarterTurns: json['quarterTurns'] as int? ?? 0,
    lifeHistory: (json['lifeHistory'] as List?)
        ?.map((e) => LifeEvent.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class GameSession {
  final String id;
  final GameFormat format;
  final List<PlayerState> players;
  final List<String> activeCounterIds;
  final List<String> customCounterIds;
  final DateTime? startedAt;
  final Duration duration;
  final bool isActive;
  final List<int> eliminationOrder;
  final List<int> playerOrder;
  final String? tag;

  const GameSession({
    required this.id,
    required this.format,
    required this.players,
    this.activeCounterIds = const [],
    this.customCounterIds = const [],
    this.startedAt,
    this.duration = Duration.zero,
    this.isActive = false,
    this.eliminationOrder = const [],
    this.playerOrder = const [],
    this.tag,
  });

  factory GameSession.newGame({
    required GameFormat format,
    required List<PlayerConfig> playerConfigs,
    List<String>? extraCounterIds,
    String? tag,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final players = List.generate(playerConfigs.length, (i) {
      return PlayerState(
        playerId: i,
        config: playerConfigs[i],
        life: format.startingLife,
      );
    });
    return GameSession(
      id: id,
      format: format,
      players: players,
      activeCounterIds: [...format.enabledCounterIds, ...?extraCounterIds],
      customCounterIds: extraCounterIds ?? [],
      playerOrder: List.generate(playerConfigs.length, (i) => i),
      tag: tag,
    );
  }

  GameSession copyWith({
    String? id,
    GameFormat? format,
    List<PlayerState>? players,
    List<String>? activeCounterIds,
    List<String>? customCounterIds,
    DateTime? startedAt,
    Duration? duration,
    bool? isActive,
    List<int>? eliminationOrder,
    List<int>? playerOrder,
    String? tag,
  }) {
    return GameSession(
      id: id ?? this.id,
      format: format ?? this.format,
      players: players ?? this.players,
      activeCounterIds: activeCounterIds ?? this.activeCounterIds,
      customCounterIds: customCounterIds ?? this.customCounterIds,
      startedAt: startedAt ?? this.startedAt,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      eliminationOrder: eliminationOrder ?? this.eliminationOrder,
      playerOrder: playerOrder ?? this.playerOrder,
      tag: tag ?? this.tag,
    );
  }

  GameSession eliminatePlayer(int playerId, {required Duration atDuration}) {
    final updatedPlayers = players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(isEliminated: true, eliminatedAt: atDuration);
      }
      return p;
    }).toList();
    return copyWith(
      players: updatedPlayers,
      eliminationOrder: [...eliminationOrder, playerId],
    );
  }

  GameSession reorderPlayers(List<int> newOrder) {
    return copyWith(playerOrder: newOrder);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'format': format.toJson(),
    'players': players.map((p) => p.toJson()).toList(),
    'activeCounterIds': activeCounterIds,
    'customCounterIds': customCounterIds,
    'startedAt': startedAt?.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'isActive': isActive,
    'eliminationOrder': eliminationOrder,
    'playerOrder': playerOrder,
    'tag': tag,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    id: json['id'] as String,
    format: GameFormat.fromJson(json['format'] as Map<String, dynamic>),
    players: (json['players'] as List)
        .map((p) => PlayerState.fromJson(p as Map<String, dynamic>))
        .toList(),
    activeCounterIds: (json['activeCounterIds'] as List?)?.cast<String>() ?? [],
    customCounterIds: (json['customCounterIds'] as List?)?.cast<String>() ?? [],
    startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    isActive: json['isActive'] as bool? ?? false,
    eliminationOrder: (json['eliminationOrder'] as List?)?.cast<int>() ?? [],
    playerOrder: (json['playerOrder'] as List?)?.cast<int>() ?? [],
    tag: json['tag'] as String?,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/game_session_test.dart`
Expected: All 10 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/game_session.dart test/models/game_session_test.dart
git commit -m "feat: add GameSession, PlayerState, LifeEvent models with elimination and reorder support"
```

---

## Task 5: AnimationService (Animation Config Resolution)

**Files:**
- Create: `lib/widgets/life_counter/animations/animation_service.dart`
- Test: `test/widgets/life_counter/animation_service_test.dart`

- [ ] **Step 1: Write failing tests for AnimationService**

```dart
// test/widgets/life_counter/animation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/widgets/life_counter/animations/animation_service.dart';

void main() {
  group('AnimationService.getLifeAnimation', () {
    test('small gain returns pulseLight', () {
      final config = AnimationService.getLifeAnimation(
        delta: 3,
        currentLife: 37,
        startingLife: 40,
      );
      expect(config.type, AnimationType.pulseLight);
      expect(config.durationMs, 200);
    });

    test('massive gain returns pulseHeavy', () {
      final config = AnimationService.getLifeAnimation(
        delta: 8,
        currentLife: 48,
        startingLife: 40,
      );
      expect(config.type, AnimationType.pulseHeavy);
      expect(config.durationMs, 400);
    });

    test('small loss returns shakeLight', () {
      final config = AnimationService.getLifeAnimation(
        delta: -3,
        currentLife: 37,
        startingLife: 40,
      );
      expect(config.type, AnimationType.shakeLight);
      expect(config.durationMs, 250);
    });

    test('medium loss returns shakeMedium', () {
      final config = AnimationService.getLifeAnimation(
        delta: -8,
        currentLife: 32,
        startingLife: 40,
      );
      expect(config.type, AnimationType.shakeMedium);
      expect(config.durationMs, 350);
    });

    test('massive loss returns shakeHeavy', () {
      final config = AnimationService.getLifeAnimation(
        delta: -15,
        currentLife: 25,
        startingLife: 40,
      );
      expect(config.type, AnimationType.shakeHeavy);
      expect(config.durationMs, 500);
      expect(config.haptic, true);
    });
  });

  group('AnimationService.getCriticalLevel', () {
    test('returns safe above 50%', () {
      final level = AnimationService.getCriticalLevel(
        currentLife: 25,
        startingLife: 40,
      );
      expect(level, CriticalLevel.safe);
    });

    test('returns warning between 25-50%', () {
      final level = AnimationService.getCriticalLevel(
        currentLife: 15,
        startingLife: 40,
      );
      expect(level, CriticalLevel.warning);
    });

    test('returns danger between 10-25%', () {
      final level = AnimationService.getCriticalLevel(
        currentLife: 8,
        startingLife: 40,
      );
      expect(level, CriticalLevel.danger);
    });

    test('returns lethal at or below 10%', () {
      final level = AnimationService.getCriticalLevel(
        currentLife: 4,
        startingLife: 40,
      );
      expect(level, CriticalLevel.lethal);
    });

    test('standard format thresholds', () {
      // 20 starting: warning <= 10, danger <= 5, lethal <= 2
      expect(AnimationService.getCriticalLevel(currentLife: 12, startingLife: 20), CriticalLevel.safe);
      expect(AnimationService.getCriticalLevel(currentLife: 8, startingLife: 20), CriticalLevel.warning);
      expect(AnimationService.getCriticalLevel(currentLife: 4, startingLife: 20), CriticalLevel.danger);
      expect(AnimationService.getCriticalLevel(currentLife: 2, startingLife: 20), CriticalLevel.lethal);
    });
  });

  group('AnimationService.getCounterAnimation', () {
    test('poison returns poisonTint', () {
      final config = AnimationService.getCounterAnimation(
        counterId: 'poison',
        delta: 2,
      );
      expect(config.type, AnimationType.poisonTint);
    });

    test('commander_damage returns commanderPulse', () {
      final config = AnimationService.getCounterAnimation(
        counterId: 'commander_damage',
        delta: 5,
      );
      expect(config.type, AnimationType.commanderPulse);
    });

    test('generic counter returns shakeLight', () {
      final config = AnimationService.getCounterAnimation(
        counterId: 'energy',
        delta: 1,
      );
      expect(config.type, AnimationType.shakeLight);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/life_counter/animation_service_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement AnimationService**

```dart
// lib/widgets/life_counter/animations/animation_service.dart

enum AnimationType {
  pulseLight,
  pulseHeavy,
  shakeLight,
  shakeMedium,
  shakeHeavy,
  poisonTint,
  commanderPulse,
  elimination,
}

enum CriticalLevel {
  safe,
  warning,
  danger,
  lethal,
}

class AnimationConfig {
  final AnimationType type;
  final int durationMs;
  final bool haptic;

  const AnimationConfig({
    required this.type,
    required this.durationMs,
    this.haptic = false,
  });
}

class AnimationService {
  const AnimationService._();

  static AnimationConfig getLifeAnimation({
    required int delta,
    required int currentLife,
    required int startingLife,
  }) {
    if (delta > 0) {
      // Gains
      if (delta <= 5) {
        return const AnimationConfig(type: AnimationType.pulseLight, durationMs: 200);
      } else {
        return const AnimationConfig(type: AnimationType.pulseHeavy, durationMs: 400);
      }
    } else {
      // Losses
      final absDelta = delta.abs();
      if (absDelta <= 5) {
        return const AnimationConfig(type: AnimationType.shakeLight, durationMs: 250);
      } else if (absDelta <= 10) {
        return const AnimationConfig(type: AnimationType.shakeMedium, durationMs: 350);
      } else {
        return const AnimationConfig(type: AnimationType.shakeHeavy, durationMs: 500, haptic: true);
      }
    }
  }

  static CriticalLevel getCriticalLevel({
    required int currentLife,
    required int startingLife,
  }) {
    if (startingLife <= 0) return CriticalLevel.safe;
    final ratio = currentLife / startingLife;
    if (ratio <= 0.10) return CriticalLevel.lethal;
    if (ratio <= 0.25) return CriticalLevel.danger;
    if (ratio <= 0.50) return CriticalLevel.warning;
    return CriticalLevel.safe;
  }

  static AnimationConfig getCounterAnimation({
    required String counterId,
    required int delta,
  }) {
    switch (counterId) {
      case 'poison':
        return const AnimationConfig(type: AnimationType.poisonTint, durationMs: 300);
      case 'commander_damage':
        return const AnimationConfig(type: AnimationType.commanderPulse, durationMs: 350);
      default:
        return const AnimationConfig(type: AnimationType.shakeLight, durationMs: 200);
    }
  }

  static const AnimationConfig eliminationAnimation = AnimationConfig(
    type: AnimationType.elimination,
    durationMs: 900, // 200ms flash + 400ms cracks + 300ms overlay
    haptic: true,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/life_counter/animation_service_test.dart`
Expected: All 12 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/animations/animation_service.dart test/widgets/life_counter/animation_service_test.dart
git commit -m "feat: add AnimationService with life animation matrix, critical thresholds, and counter animations"
```

---

## Task 6: LayoutStrategy Pattern

**Files:**
- Create: `lib/widgets/life_counter/layouts/layout_strategy.dart`
- Test: `test/widgets/life_counter/layout_strategy_test.dart`

- [ ] **Step 1: Write failing tests for LayoutStrategy**

```dart
// test/widgets/life_counter/layout_strategy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/widgets/life_counter/layouts/layout_strategy.dart';

void main() {
  group('LayoutResolver', () {
    test('2 players resolves to FaceToFace', () {
      final layout = LayoutResolver.resolve(2);
      expect(layout, LayoutType.faceToFace);
    });

    test('3 players resolves to Grid', () {
      final layout = LayoutResolver.resolve(3);
      expect(layout, LayoutType.grid);
    });

    test('4 players resolves to Grid', () {
      final layout = LayoutResolver.resolve(4);
      expect(layout, LayoutType.grid);
    });

    test('5 players resolves to Focus', () {
      final layout = LayoutResolver.resolve(5);
      expect(layout, LayoutType.focus);
    });

    test('8 players resolves to Focus', () {
      final layout = LayoutResolver.resolve(8);
      expect(layout, LayoutType.focus);
    });

    test('user preference overrides default for 4 players', () {
      final layout = LayoutResolver.resolve(4, preference: LayoutType.focus);
      expect(layout, LayoutType.focus);
    });

    test('user preference overrides default for 6 players', () {
      final layout = LayoutResolver.resolve(6, preference: LayoutType.grid);
      expect(layout, LayoutType.grid);
    });

    test('2 players always FaceToFace regardless of preference', () {
      final layout = LayoutResolver.resolve(2, preference: LayoutType.focus);
      expect(layout, LayoutType.faceToFace);
    });
  });

  group('GridLayoutConfig', () {
    test('3 players uses 2+1 layout', () {
      final config = GridLayoutConfig.forPlayerCount(3);
      expect(config.columns, 2);
      expect(config.topRowCount, 2);
      expect(config.bottomRowCount, 1);
      expect(config.bottomRowFullWidth, true);
    });

    test('4 players uses 2x2 layout', () {
      final config = GridLayoutConfig.forPlayerCount(4);
      expect(config.columns, 2);
      expect(config.topRowCount, 2);
      expect(config.bottomRowCount, 2);
      expect(config.bottomRowFullWidth, false);
    });
  });

  group('FocusLayoutConfig', () {
    test('5 players has 4 adversaries', () {
      final config = FocusLayoutConfig.forPlayerCount(5);
      expect(config.adversaryCount, 4);
      expect(config.ownerHeightRatio, closeTo(0.4, 0.01));
    });

    test('8 players has 7 adversaries', () {
      final config = FocusLayoutConfig.forPlayerCount(8);
      expect(config.adversaryCount, 7);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/life_counter/layout_strategy_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement LayoutStrategy**

```dart
// lib/widgets/life_counter/layouts/layout_strategy.dart

enum LayoutType {
  faceToFace,
  grid,
  focus,
}

class LayoutResolver {
  const LayoutResolver._();

  static LayoutType resolve(int playerCount, {LayoutType? preference}) {
    // 2 players always face to face
    if (playerCount <= 2) return LayoutType.faceToFace;

    // If user has a preference, respect it (except for 2 players)
    if (preference != null) return preference;

    // Default: 3-4 = grid, 5+ = focus
    if (playerCount <= 4) return LayoutType.grid;
    return LayoutType.focus;
  }
}

class GridLayoutConfig {
  final int columns;
  final int topRowCount;
  final int bottomRowCount;
  final bool bottomRowFullWidth;

  const GridLayoutConfig({
    required this.columns,
    required this.topRowCount,
    required this.bottomRowCount,
    required this.bottomRowFullWidth,
  });

  factory GridLayoutConfig.forPlayerCount(int count) {
    if (count == 3) {
      return const GridLayoutConfig(
        columns: 2,
        topRowCount: 2,
        bottomRowCount: 1,
        bottomRowFullWidth: true,
      );
    }
    // 4 players (default grid)
    return const GridLayoutConfig(
      columns: 2,
      topRowCount: 2,
      bottomRowCount: 2,
      bottomRowFullWidth: false,
    );
  }
}

class FocusLayoutConfig {
  final int adversaryCount;
  final double ownerHeightRatio;

  const FocusLayoutConfig({
    required this.adversaryCount,
    required this.ownerHeightRatio,
  });

  factory FocusLayoutConfig.forPlayerCount(int count) {
    return FocusLayoutConfig(
      adversaryCount: count - 1,
      ownerHeightRatio: 0.4,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/life_counter/layout_strategy_test.dart`
Expected: All 10 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/life_counter/layouts/layout_strategy.dart test/widgets/life_counter/layout_strategy_test.dart
git commit -m "feat: add LayoutStrategy pattern with FaceToFace, Grid, Focus layouts and resolver"
```

---

## Task 7: GameSession Controller (Notifier)

**Files:**
- Create: `lib/controllers/game_session_controller.dart`
- Test: `test/controllers/game_session_controller_test.dart`

- [ ] **Step 1: Write failing tests for GameSessionController**

```dart
// test/controllers/game_session_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/controllers/game_session_controller.dart';
import 'package:magic_compagnion/models/game_format.dart';
import 'package:magic_compagnion/models/game_session.dart';
import 'package:magic_compagnion/models/player_config.dart';

void main() {
  late GameSessionController controller;
  final commanderFormat = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
  final configs = [
    PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
    PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
    PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
    PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
  ];

  setUp(() {
    controller = GameSessionController();
  });

  group('startNewGame', () {
    test('creates session with correct starting life', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      expect(controller.session, isNotNull);
      expect(controller.session!.players, hasLength(4));
      expect(controller.session!.players[0].life, 40);
      expect(controller.session!.format.id, 'commander');
    });
  });

  group('updateLife', () {
    test('increases life and records event', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateLife(0, 5, gameDuration: const Duration(minutes: 1));
      expect(controller.session!.players[0].life, 45);
      expect(controller.session!.players[0].lifeHistory, hasLength(1));
      expect(controller.session!.players[0].lifeHistory.first.delta, 5);
    });

    test('decreases life', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateLife(0, -3, gameDuration: const Duration(minutes: 2));
      expect(controller.session!.players[0].life, 37);
    });

    test('does not affect other players', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateLife(0, -10, gameDuration: Duration.zero);
      expect(controller.session!.players[1].life, 40);
      expect(controller.session!.players[2].life, 40);
    });
  });

  group('updateCounter', () {
    test('sets counter value', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateCounter(0, 'poison', 3);
      expect(controller.session!.players[0].counters['poison'], 3);
    });

    test('increments existing counter', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateCounter(0, 'poison', 2);
      controller.updateCounter(0, 'poison', 3);
      expect(controller.session!.players[0].counters['poison'], 3);
    });
  });

  group('addCommanderDamage', () {
    test('records commander damage from opponent', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.addCommanderDamage(
        targetPlayerId: 0,
        sourcePlayerId: 1,
        damage: 5,
        gameDuration: const Duration(minutes: 3),
      );
      expect(controller.session!.players[0].commanderDamageReceived[1], 5);
      expect(controller.session!.players[0].life, 35);
      expect(controller.session!.players[0].lifeHistory, hasLength(1));
      expect(controller.session!.players[0].lifeHistory.first.source, contains('Max'));
    });
  });

  group('eliminatePlayer', () {
    test('marks player as eliminated', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.eliminatePlayer(2, atDuration: const Duration(minutes: 15));
      expect(controller.session!.players[2].isEliminated, true);
      expect(controller.session!.eliminationOrder, [2]);
    });
  });

  group('toggleMonarch', () {
    test('sets monarch and clears from others', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.toggleMonarch(1);
      expect(controller.session!.players[1].isMonarch, true);
      expect(controller.session!.players[0].isMonarch, false);

      // Switch to another player
      controller.toggleMonarch(3);
      expect(controller.session!.players[1].isMonarch, false);
      expect(controller.session!.players[3].isMonarch, true);
    });

    test('toggles off if same player', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.toggleMonarch(1);
      expect(controller.session!.players[1].isMonarch, true);
      controller.toggleMonarch(1);
      expect(controller.session!.players[1].isMonarch, false);
    });
  });

  group('reorderPlayers', () {
    test('updates player order', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.reorderPlayers([3, 1, 0, 2]);
      expect(controller.session!.playerOrder, [3, 1, 0, 2]);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/controllers/game_session_controller_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement GameSessionController**

```dart
// lib/controllers/game_session_controller.dart
import 'package:magic_compagnion/models/game_format.dart';
import 'package:magic_compagnion/models/game_session.dart';
import 'package:magic_compagnion/models/player_config.dart';

class GameSessionController {
  GameSession? _session;

  GameSession? get session => _session;

  void startNewGame({
    required GameFormat format,
    required List<PlayerConfig> playerConfigs,
    List<String>? extraCounterIds,
    String? tag,
  }) {
    _session = GameSession.newGame(
      format: format,
      playerConfigs: playerConfigs,
      extraCounterIds: extraCounterIds,
      tag: tag,
    );
  }

  void updateLife(int playerId, int delta, {required Duration gameDuration}) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        final event = LifeEvent(delta: delta, timestamp: gameDuration);
        return p.copyWith(
          life: p.life + delta,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void updateCounter(int playerId, String counterId, int value) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        final counters = Map<String, int>.from(p.counters);
        counters[counterId] = value;
        return p.copyWith(counters: counters);
      }
      return p;
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void addCommanderDamage({
    required int targetPlayerId,
    required int sourcePlayerId,
    required int damage,
    required Duration gameDuration,
  }) {
    if (_session == null) return;
    final sourceName = _session!.players
        .firstWhere((p) => p.playerId == sourcePlayerId)
        .config.name;

    final players = _session!.players.map((p) {
      if (p.playerId == targetPlayerId) {
        final cmdDamage = Map<int, int>.from(p.commanderDamageReceived);
        cmdDamage[sourcePlayerId] = (cmdDamage[sourcePlayerId] ?? 0) + damage;
        final event = LifeEvent(
          delta: -damage,
          source: 'Commander: $sourceName',
          timestamp: gameDuration,
        );
        return p.copyWith(
          life: p.life - damage,
          commanderDamageReceived: cmdDamage,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void eliminatePlayer(int playerId, {required Duration atDuration}) {
    if (_session == null) return;
    _session = _session!.eliminatePlayer(playerId, atDuration: atDuration);
  }

  void toggleMonarch(int playerId) {
    if (_session == null) return;
    final currentMonarch = _session!.players.any((p) => p.playerId == playerId && p.isMonarch);
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(isMonarch: !currentMonarch);
      }
      return p.copyWith(isMonarch: false);
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void reorderPlayers(List<int> newOrder) {
    if (_session == null) return;
    _session = _session!.reorderPlayers(newOrder);
  }

  void updateRotation(int playerId, int quarterTurns) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(quarterTurns: quarterTurns);
      }
      return p;
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void endGame() {
    if (_session == null) return;
    _session = _session!.copyWith(isActive: false);
  }

  void clear() {
    _session = null;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/controllers/game_session_controller_test.dart`
Expected: All 12 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/controllers/game_session_controller.dart test/controllers/game_session_controller_test.dart
git commit -m "feat: add GameSessionController with life, counter, commander damage, elimination, monarch, and reorder"
```

---

## Task 8: Enriched GameHistory Model + Stats Models

**Files:**
- Modify: `lib/models/game_history_model.dart`
- Create: `lib/models/game_stats.dart`
- Test: `test/models/game_stats_test.dart`

- [ ] **Step 1: Write failing tests for enriched PlayerHistorySnapshot and GameStats**

```dart
// test/models/game_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/models/game_history_model.dart';
import 'package:magic_compagnion/models/game_stats.dart';

void main() {
  group('Enriched PlayerHistorySnapshot', () {
    test('toJson and fromJson with new fields', () {
      final snapshot = PlayerHistorySnapshot(
        name: 'Alex',
        life: 32,
        poison: 3,
        commanderDamageTaken: 12,
        type: 'owner',
        deckName: 'Atraxa Superfriends',
        commanderNames: ['Atraxa', 'Thrasios'],
        energy: 5,
        commanderTax: 4,
        isEliminated: false,
      );
      final json = snapshot.toJson();
      final restored = PlayerHistorySnapshot.fromJson(json);
      expect(restored.type, 'owner');
      expect(restored.deckName, 'Atraxa Superfriends');
      expect(restored.commanderNames, hasLength(2));
      expect(restored.energy, 5);
      expect(restored.commanderTax, 4);
      expect(restored.isEliminated, false);
    });

    test('backward compatible with old snapshots missing new fields', () {
      final oldJson = {
        'name': 'Max',
        'life': 0,
        'poison': 10,
        'commanderDamageTaken': 0,
      };
      final restored = PlayerHistorySnapshot.fromJson(oldJson);
      expect(restored.name, 'Max');
      expect(restored.type, isNull);
      expect(restored.deckName, isNull);
      expect(restored.commanderNames, isEmpty);
      expect(restored.energy, 0);
      expect(restored.isEliminated, false);
    });
  });

  group('StatsCalculator', () {
    final games = [
      _makeGame(winner: 'Alex', deckName: 'Atraxa', format: 'Commander', players: ['Alex', 'Max', 'Sarah']),
      _makeGame(winner: 'Max', format: 'Commander', players: ['Alex', 'Max', 'Sarah']),
      _makeGame(winner: 'Alex', deckName: 'Korvold', format: 'Commander', players: ['Alex', 'Max']),
      _makeGame(winner: 'Alex', deckName: 'Atraxa', format: 'Standard', players: ['Alex', 'Sarah']),
      _makeGame(winner: 'Sarah', format: 'Commander', players: ['Alex', 'Sarah', 'Leo']),
    ];

    test('calculates global winrate for owner', () {
      final stats = StatsCalculator.computeOwnerStats('Alex', games);
      expect(stats.totalGames, 5);
      expect(stats.wins, 3);
      expect(stats.winrate, closeTo(0.6, 0.01));
    });

    test('calculates winrate by deck', () {
      final deckStats = StatsCalculator.computeDeckStats('Alex', games);
      final atraxa = deckStats.firstWhere((d) => d.deckName == 'Atraxa');
      expect(atraxa.games, 2);
      expect(atraxa.wins, 2);
      expect(atraxa.winrate, 1.0);

      final korvold = deckStats.firstWhere((d) => d.deckName == 'Korvold');
      expect(korvold.games, 1);
      expect(korvold.wins, 1);
    });

    test('calculates winrate by format', () {
      final formatStats = StatsCalculator.computeFormatStats('Alex', games);
      final commander = formatStats.firstWhere((f) => f.format == 'Commander');
      expect(commander.games, 4);
      expect(commander.wins, 2);
    });

    test('calculates opponent stats', () {
      final oppStats = StatsCalculator.computeOpponentStats('Alex', games);
      final max = oppStats.firstWhere((o) => o.opponentName == 'Max');
      expect(max.gamesAgainst, 3);
      // Alex won 2 of 3 games where Max was present
      expect(max.winsAgainst, 2);
    });
  });
}

GameHistoryItem _makeGame({
  required String winner,
  String? deckName,
  required String format,
  required List<String> players,
}) {
  return GameHistoryItem(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    date: DateTime.now(),
    durationSeconds: 1800,
    winnerName: winner,
    format: format,
    winMethod: 'normal',
    playerStates: players.map((name) => PlayerHistorySnapshot(
      name: name,
      life: 20,
      poison: 0,
      commanderDamageTaken: 0,
      deckName: name == 'Alex' ? deckName : null,
      type: name == 'Alex' ? 'owner' : 'guest',
    )).toList(),
  );
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/game_stats_test.dart`
Expected: FAIL — new fields and GameStats not found.

- [ ] **Step 3: Enrich PlayerHistorySnapshot with new fields**

In `lib/models/game_history_model.dart`, update `PlayerHistorySnapshot`:

```dart
class PlayerHistorySnapshot {
  final String name;
  final String? imageUrl;
  final int life;
  final int poison;
  final int commanderDamageTaken;
  // New fields
  final String? type; // 'owner' | 'guest'
  final String? deckName;
  final List<String> commanderNames;
  final int energy;
  final int commanderTax;
  final bool isEliminated;
  final int? eliminatedAtSeconds;
  final int? eliminationRank;

  PlayerHistorySnapshot({
    required this.name,
    this.imageUrl,
    required this.life,
    required this.poison,
    required this.commanderDamageTaken,
    this.type,
    this.deckName,
    this.commanderNames = const [],
    this.energy = 0,
    this.commanderTax = 0,
    this.isEliminated = false,
    this.eliminatedAtSeconds,
    this.eliminationRank,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'imageUrl': imageUrl,
    'life': life,
    'poison': poison,
    'commanderDamageTaken': commanderDamageTaken,
    'type': type,
    'deckName': deckName,
    'commanderNames': commanderNames,
    'energy': energy,
    'commanderTax': commanderTax,
    'isEliminated': isEliminated,
    'eliminatedAtSeconds': eliminatedAtSeconds,
    'eliminationRank': eliminationRank,
  };

  factory PlayerHistorySnapshot.fromJson(Map<String, dynamic> json) =>
      PlayerHistorySnapshot(
        name: json['name'],
        imageUrl: json['imageUrl'],
        life: json['life'] ?? 0,
        poison: json['poison'] ?? 0,
        commanderDamageTaken: json['commanderDamageTaken'] ?? 0,
        type: json['type'],
        deckName: json['deckName'],
        commanderNames: (json['commanderNames'] as List?)
            ?.map((e) => e.toString()).toList() ?? [],
        energy: json['energy'] ?? 0,
        commanderTax: json['commanderTax'] ?? 0,
        isEliminated: json['isEliminated'] ?? false,
        eliminatedAtSeconds: json['eliminatedAtSeconds'],
        eliminationRank: json['eliminationRank'],
      );
}
```

- [ ] **Step 4: Implement GameStats models**

```dart
// lib/models/game_stats.dart
import 'package:magic_compagnion/models/game_history_model.dart';

class OwnerStats {
  final int totalGames;
  final int wins;
  final double winrate;
  final int currentStreak;
  final int bestStreak;

  const OwnerStats({
    required this.totalGames,
    required this.wins,
    required this.winrate,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });
}

class DeckStats {
  final String deckName;
  final int games;
  final int wins;
  final double winrate;

  const DeckStats({
    required this.deckName,
    required this.games,
    required this.wins,
    required this.winrate,
  });
}

class FormatStats {
  final String format;
  final int games;
  final int wins;
  final double winrate;
  final int avgDurationSeconds;

  const FormatStats({
    required this.format,
    required this.games,
    required this.wins,
    required this.winrate,
    this.avgDurationSeconds = 0,
  });
}

class OpponentStats {
  final String opponentName;
  final int gamesAgainst;
  final int winsAgainst;
  final double winrateAgainst;
  final DateTime? lastPlayed;

  const OpponentStats({
    required this.opponentName,
    required this.gamesAgainst,
    required this.winsAgainst,
    required this.winrateAgainst,
    this.lastPlayed,
  });
}

class StatsCalculator {
  const StatsCalculator._();

  static OwnerStats computeOwnerStats(String ownerName, List<GameHistoryItem> games) {
    final total = games.length;
    final wins = games.where((g) => g.winnerName == ownerName).length;
    final winrate = total > 0 ? wins / total : 0.0;

    // Streak calculation
    int currentStreak = 0;
    int bestStreak = 0;
    int streak = 0;
    for (final game in games.reversed) {
      if (game.winnerName == ownerName) {
        streak++;
        if (streak > bestStreak) bestStreak = streak;
      } else {
        streak = 0;
      }
    }
    currentStreak = streak;

    return OwnerStats(
      totalGames: total,
      wins: wins,
      winrate: winrate,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );
  }

  static List<DeckStats> computeDeckStats(String ownerName, List<GameHistoryItem> games) {
    final Map<String, List<GameHistoryItem>> byDeck = {};
    for (final game in games) {
      final ownerSnapshot = game.playerStates
          .where((p) => p.name == ownerName && p.deckName != null)
          .firstOrNull;
      if (ownerSnapshot != null && ownerSnapshot.deckName != null) {
        byDeck.putIfAbsent(ownerSnapshot.deckName!, () => []).add(game);
      }
    }
    return byDeck.entries.map((entry) {
      final deckGames = entry.value;
      final wins = deckGames.where((g) => g.winnerName == ownerName).length;
      return DeckStats(
        deckName: entry.key,
        games: deckGames.length,
        wins: wins,
        winrate: deckGames.isNotEmpty ? wins / deckGames.length : 0.0,
      );
    }).toList()..sort((a, b) => b.games.compareTo(a.games));
  }

  static List<FormatStats> computeFormatStats(String ownerName, List<GameHistoryItem> games) {
    final Map<String, List<GameHistoryItem>> byFormat = {};
    for (final game in games) {
      byFormat.putIfAbsent(game.format, () => []).add(game);
    }
    return byFormat.entries.map((entry) {
      final formatGames = entry.value;
      final wins = formatGames.where((g) => g.winnerName == ownerName).length;
      final avgDuration = formatGames.isNotEmpty
          ? formatGames.map((g) => g.durationSeconds).reduce((a, b) => a + b) ~/ formatGames.length
          : 0;
      return FormatStats(
        format: entry.key,
        games: formatGames.length,
        wins: wins,
        winrate: formatGames.isNotEmpty ? wins / formatGames.length : 0.0,
        avgDurationSeconds: avgDuration,
      );
    }).toList()..sort((a, b) => b.games.compareTo(a.games));
  }

  static List<OpponentStats> computeOpponentStats(String ownerName, List<GameHistoryItem> games) {
    final Map<String, List<GameHistoryItem>> byOpponent = {};
    for (final game in games) {
      for (final player in game.playerStates) {
        if (player.name != ownerName) {
          byOpponent.putIfAbsent(player.name, () => []).add(game);
        }
      }
    }
    return byOpponent.entries.map((entry) {
      final oppGames = entry.value;
      final wins = oppGames.where((g) => g.winnerName == ownerName).length;
      final lastGame = oppGames.isNotEmpty ? oppGames.map((g) => g.date).reduce(
        (a, b) => a.isAfter(b) ? a : b,
      ) : null;
      return OpponentStats(
        opponentName: entry.key,
        gamesAgainst: oppGames.length,
        winsAgainst: wins,
        winrateAgainst: oppGames.isNotEmpty ? wins / oppGames.length : 0.0,
        lastPlayed: lastGame,
      );
    }).toList()..sort((a, b) => b.gamesAgainst.compareTo(a.gamesAgainst));
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/models/game_stats_test.dart`
Expected: All 7 tests PASS.

- [ ] **Step 6: Run existing game_history tests to check backward compatibility**

Run: `flutter test test/ --name "game_history\|GameHistory"`
Expected: All existing tests still PASS (new fields have defaults).

- [ ] **Step 7: Commit**

```bash
git add lib/models/game_history_model.dart lib/models/game_stats.dart test/models/game_stats_test.dart
git commit -m "feat: enrich PlayerHistorySnapshot with deck/format/elimination data, add StatsCalculator"
```

---

## Task 9: Drift Schema v2 — New Tables + Migration

**Files:**
- Modify: `lib/data/database/app_database.dart`
- Test: `test/data/app_database_v2_test.dart`

- [ ] **Step 1: Write failing tests for new tables**

```dart
// test/data/app_database_v2_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_compagnion/data/database/app_database.dart';

AppDatabase _createTestDb() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('GameFormats table', () {
    test('insert and retrieve a custom format', () async {
      await db.upsertGameFormat(GameFormatsCompanion.insert(
        id: 'my-format',
        name: 'My Format',
        startingLife: Value(30),
        minPlayers: Value(2),
        maxPlayers: Value(6),
        maxCommanders: Value(3),
        enabledCounterIds: Value('["poison","energy"]'),
        isBuiltIn: Value(false),
      ));

      final formats = await db.getAllGameFormats();
      expect(formats, hasLength(1));
      expect(formats.first.name, 'My Format');
      expect(formats.first.startingLife, 30);
      expect(formats.first.isBuiltIn, false);
    });
  });

  group('CounterTypes table', () {
    test('insert and retrieve a custom counter', () async {
      await db.upsertCounterType(CounterTypesCompanion.insert(
        id: 'storm',
        name: 'Storm Count',
        emoji: Value('⚡'),
        color: Value(0xFFFF9800),
        isBuiltIn: Value(false),
      ));

      final counters = await db.getAllCounterTypes();
      expect(counters, hasLength(1));
      expect(counters.first.name, 'Storm Count');
    });
  });

  group('PlayerConfigs table', () {
    test('insert owner config and retrieve', () async {
      await db.upsertPlayerConfig(PlayerConfigsCompanion.insert(
        id: 'owner-1',
        name: 'Alex',
        type: Value('owner'),
        colorValue: Value(0xFF0D47A1),
      ));

      final configs = await db.getAllPlayerConfigs();
      expect(configs, hasLength(1));
      expect(configs.first.name, 'Alex');
      expect(configs.first.type, 'owner');
    });

    test('insert player config commanders', () async {
      await db.upsertPlayerConfig(PlayerConfigsCompanion.insert(
        id: 'guest-1',
        name: 'Max',
        type: Value('guest'),
      ));

      await db.insertPlayerConfigCommander(PlayerConfigCommandersCompanion.insert(
        id: 'cmd-1',
        playerConfigId: 'guest-1',
        name: 'Atraxa',
        sortOrder: Value(0),
      ));

      final commanders = await db.getCommandersForConfig('guest-1');
      expect(commanders, hasLength(1));
      expect(commanders.first.name, 'Atraxa');
    });
  });

  group('Enriched GameHistory', () {
    test('insert with new fields and retrieve', () async {
      await db.insertGameHistory(GameHistoryItemsCompanion.insert(
        id: 'game-1',
        date: DateTime(2026, 3, 29),
        winnerName: 'Alex',
        format: Value('Commander'),
        startingLife: Value(40),
        playerCount: Value(4),
        tag: Value('Soiree chez Max'),
        winnerDeckName: Value('Atraxa Superfriends'),
      ));

      final games = await db.getAllGameHistory();
      expect(games, hasLength(1));
      expect(games.first.startingLife, 40);
      expect(games.first.playerCount, 4);
      expect(games.first.tag, 'Soiree chez Max');
      expect(games.first.winnerDeckName, 'Atraxa Superfriends');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/app_database_v2_test.dart`
Expected: FAIL — new tables and methods don't exist.

- [ ] **Step 3: Add new tables and enrich existing ones in app_database.dart**

Add these new table classes before the `@DriftDatabase` annotation in `lib/data/database/app_database.dart`:

```dart
/// Table des formats de jeu
@DataClassName('DbGameFormat')
class GameFormats extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get startingLife => integer().withDefault(const Constant(20))();
  IntColumn get minPlayers => integer().withDefault(const Constant(2))();
  IntColumn get maxPlayers => integer().withDefault(const Constant(8))();
  IntColumn get maxCommanders => integer().withDefault(const Constant(0))();
  TextColumn get enabledCounterIds => text().withDefault(const Constant('[]'))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des types de compteurs
@DataClassName('DbCounterType')
class CounterTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('🔢'))();
  IntColumn get color => integer().withDefault(const Constant(0xFFFFFFFF))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get maxValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des configs joueurs (owner/guest)
@DataClassName('DbPlayerConfig')
class PlayerConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('guest'))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF2196F3))();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get linkedDeckId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des commanders par config joueur
@DataClassName('DbPlayerConfigCommander')
class PlayerConfigCommanders extends Table {
  TextColumn get id => text()();
  TextColumn get playerConfigId => text().references(PlayerConfigs, #id)();
  TextColumn get name => text()();
  TextColumn get scryfallId => text().nullable()();
  TextColumn get artCropUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add new columns to `GameHistoryItems`:

```dart
@DataClassName('DbGameHistoryItem')
class GameHistoryItems extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get winnerName => text()();
  TextColumn get format => text().withDefault(const Constant('Standard'))();
  TextColumn get winMethod => text().withDefault(const Constant('normal'))();
  TextColumn get playerStates => text().withDefault(const Constant('[]'))();
  // New columns
  IntColumn get startingLife => integer().withDefault(const Constant(20))();
  IntColumn get playerCount => integer().withDefault(const Constant(2))();
  TextColumn get tag => text().nullable()();
  TextColumn get winnerDeckName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Update `@DriftDatabase` to include new tables:

```dart
@DriftDatabase(tables: [
  CollectionCards,
  Decks,
  DeckCards,
  Wishlists,
  WishlistCards,
  Profiles,
  GameHistoryItems,
  ScanHistoryItems,
  CollectionValueHistory,
  AppSettings,
  // v2 tables
  GameFormats,
  CounterTypes,
  PlayerConfigs,
  PlayerConfigCommanders,
])
```

Bump `schemaVersion` to `2` and add migration:

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(gameFormats);
        await m.createTable(counterTypes);
        await m.createTable(playerConfigs);
        await m.createTable(playerConfigCommanders);
        // Add new columns to gameHistoryItems
        await m.addColumn(gameHistoryItems, gameHistoryItems.startingLife);
        await m.addColumn(gameHistoryItems, gameHistoryItems.playerCount);
        await m.addColumn(gameHistoryItems, gameHistoryItems.tag);
        await m.addColumn(gameHistoryItems, gameHistoryItems.winnerDeckName);
      }
    },
  );
}
```

Add DAO methods for new tables:

```dart
// GAME FORMATS DAO
Future<List<DbGameFormat>> getAllGameFormats() => select(gameFormats).get();

Future<void> upsertGameFormat(GameFormatsCompanion format) async {
  await into(gameFormats).insertOnConflictUpdate(format);
}

Future<void> deleteGameFormat(String id) async {
  await (delete(gameFormats)..where((f) => f.id.equals(id))).go();
}

// COUNTER TYPES DAO
Future<List<DbCounterType>> getAllCounterTypes() => select(counterTypes).get();

Future<void> upsertCounterType(CounterTypesCompanion counter) async {
  await into(counterTypes).insertOnConflictUpdate(counter);
}

Future<void> deleteCounterType(String id) async {
  await (delete(counterTypes)..where((c) => c.id.equals(id))).go();
}

// PLAYER CONFIGS DAO
Future<List<DbPlayerConfig>> getAllPlayerConfigs() => select(playerConfigs).get();

Future<void> upsertPlayerConfig(PlayerConfigsCompanion config) async {
  await into(playerConfigs).insertOnConflictUpdate(config);
}

Future<void> deletePlayerConfig(String id) async {
  await (delete(playerConfigCommanders)..where((c) => c.playerConfigId.equals(id))).go();
  await (delete(playerConfigs)..where((p) => p.id.equals(id))).go();
}

Future<List<DbPlayerConfigCommander>> getCommandersForConfig(String configId) =>
    (select(playerConfigCommanders)
      ..where((c) => c.playerConfigId.equals(configId))
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
    .get();

Future<void> insertPlayerConfigCommander(PlayerConfigCommandersCompanion commander) async {
  await into(playerConfigCommanders).insertOnConflictUpdate(commander);
}

Future<void> clearCommandersForConfig(String configId) async {
  await (delete(playerConfigCommanders)..where((c) => c.playerConfigId.equals(configId))).go();
}
```

- [ ] **Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` regenerated with new table definitions.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/app_database_v2_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 6: Run all existing database tests**

Run: `flutter test test/data/`
Expected: All existing tests still PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/data/database/app_database.dart lib/data/database/app_database.g.dart test/data/app_database_v2_test.dart
git commit -m "feat: add Drift schema v2 — GameFormats, CounterTypes, PlayerConfigs tables + enriched GameHistory"
```

---

## Task 10: GameSession Crash Recovery Service

**Files:**
- Create: `lib/services/game_session_service.dart`
- Test: `test/services/game_session_service_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/services/game_session_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_compagnion/services/game_session_service.dart';
import 'package:magic_compagnion/models/game_format.dart';
import 'package:magic_compagnion/models/game_session.dart';
import 'package:magic_compagnion/models/player_config.dart';

void main() {
  final commanderFormat = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameSessionService', () {
    test('saveSnapshot and loadSnapshot roundtrip', () async {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final service = GameSessionService();

      await service.saveSnapshot(session);
      final restored = await service.loadSnapshot();

      expect(restored, isNotNull);
      expect(restored!.format.id, 'commander');
      expect(restored.players, hasLength(2));
      expect(restored.players[0].config.name, 'Alex');
      expect(restored.players[0].life, 40);
    });

    test('hasActiveGame returns true after save', () async {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final service = GameSessionService();

      expect(await service.hasActiveGame(), false);
      await service.saveSnapshot(session);
      expect(await service.hasActiveGame(), true);
    });

    test('clearSnapshot removes the snapshot', () async {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final service = GameSessionService();

      await service.saveSnapshot(session);
      expect(await service.hasActiveGame(), true);

      await service.clearSnapshot();
      expect(await service.hasActiveGame(), false);
      expect(await service.loadSnapshot(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/game_session_service_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement GameSessionService**

```dart
// lib/services/game_session_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_compagnion/models/game_session.dart';

class GameSessionService {
  static const _snapshotKey = 'active_game_snapshot';

  Future<void> saveSnapshot(GameSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(session.toJson());
    await prefs.setString(_snapshotKey, jsonStr);
  }

  Future<GameSession?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_snapshotKey);
    if (jsonStr == null) return null;
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return GameSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasActiveGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_snapshotKey);
  }

  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/game_session_service_test.dart`
Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/game_session_service.dart test/services/game_session_service_test.dart
git commit -m "feat: add GameSessionService for crash recovery via SharedPreferences snapshot"
```

---

## Task 11: Service Providers Wiring

**Files:**
- Modify: `lib/providers/service_providers.dart`
- Create: `lib/providers/game_session_provider.dart`
- Create: `lib/providers/stats_provider.dart`

- [ ] **Step 1: Add new service providers to service_providers.dart**

Add to `lib/providers/service_providers.dart`:

```dart
import 'package:magic_compagnion/services/game_session_service.dart';

final gameSessionServiceProvider = Provider<GameSessionService>((ref) {
  return GameSessionService();
});
```

- [ ] **Step 2: Create game_session_provider.dart**

```dart
// lib/providers/game_session_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_compagnion/controllers/game_session_controller.dart';
import 'package:magic_compagnion/models/game_session.dart';
import 'package:magic_compagnion/widgets/life_counter/layouts/layout_strategy.dart';

final gameSessionControllerProvider = StateProvider<GameSessionController>((ref) {
  return GameSessionController();
});

final layoutPreferenceProvider = StateProvider<LayoutType?>((ref) => null);
```

- [ ] **Step 3: Create stats_provider.dart**

```dart
// lib/providers/stats_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_compagnion/models/game_history_model.dart';
import 'package:magic_compagnion/models/game_stats.dart';
import 'package:magic_compagnion/providers/game_history_provider.dart';

final ownerStatsProvider = Provider<OwnerStats?>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    if (games.isEmpty) return null;
    // Use first owner-type player name found, or first winner
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return null;
    return StatsCalculator.computeOwnerStats(ownerName, games);
  });
});

final deckStatsProvider = Provider<List<DeckStats>>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return <DeckStats>[];
    return StatsCalculator.computeDeckStats(ownerName, games);
  }) ?? [];
});

final formatStatsProvider = Provider<List<FormatStats>>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return <FormatStats>[];
    return StatsCalculator.computeFormatStats(ownerName, games);
  }) ?? [];
});

final opponentStatsProvider = Provider<List<OpponentStats>>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return <OpponentStats>[];
    return StatsCalculator.computeOpponentStats(ownerName, games);
  }) ?? [];
});

String? _findOwnerName(List<GameHistoryItem> games) {
  for (final game in games) {
    for (final player in game.playerStates) {
      if (player.type == 'owner') return player.name;
    }
  }
  // Fallback: most frequent winner
  if (games.isEmpty) return null;
  final winCounts = <String, int>{};
  for (final game in games) {
    winCounts[game.winnerName] = (winCounts[game.winnerName] ?? 0) + 1;
  }
  return winCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}
```

- [ ] **Step 4: Run all tests to verify nothing broke**

Run: `flutter test`
Expected: All existing + new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/service_providers.dart lib/providers/game_session_provider.dart lib/providers/stats_provider.dart
git commit -m "feat: wire new service providers for GameSession, layout preference, and stats"
```

---

## Remaining Tasks (UI Implementation)

The following tasks cover the UI layer. They build on the models, controllers, services, and providers from Tasks 1-11. Each task follows the same TDD pattern but involves widget creation and integration.

### Task 12: Decompose PlayerZone into sub-widgets

Refactor the monolithic `player_zone.dart` (850+ lines) into composable sub-widgets:
- **Files:** Create `player_header.dart`, `life_display.dart`, `life_log.dart`, `counter_strip.dart`. Modify `player_zone.dart` to compose them.
- Extract PlayerHeader (name, avatar, commander artwork, color band)
- Extract LifeDisplay (PV number + buttons +/-)
- Extract LifeLog (floating history of 4 last changes with 8s timeout)
- Extract CounterStrip (horizontal swipe between counters with PageView)
- Keep PlayerZone as the orchestrator that composes all sub-widgets
- All callbacks flow through PlayerZone to the parent

### Task 13: CriticalOverlay + EliminationOverlay widgets

- **Files:** Create `critical_overlay.dart`, `elimination_overlay.dart`, `crack_effect.dart`
- CriticalOverlay: animated border based on CriticalLevel (safe/warning/danger/lethal)
- EliminationOverlay: 3-phase animation (flash → cracks → dark overlay with skull)
- CrackEffect: CustomPainter for crack lines radiating from center
- Wire into PlayerZone

### Task 14: RadialMenu widget

- **Files:** Create `radial_menu.dart`
- Long press (500ms) on zone opens radial menu at touch point
- 4 options: Monarch, Commander Damage, Eliminate, Reset
- Commander Damage opens opponent selector
- Animate open/close with scale + fade

### Task 15: Quick Start + Advanced Settings pages

- **Files:** Create `quick_start_page.dart`, `advanced_settings_page.dart`, `deck_picker_sheet.dart`, `guest_profile_sheet.dart`, `profile_picker_sheet.dart`
- Quick Start: format chips + player count selector + launch button (2 taps)
- Advanced Settings: collapsible sections (Format, Players, Counters, Options)
- Deck picker: bottom sheet showing owner's decks from collection
- Guest profile: bottom sheet for name/color/commander
- Wire GameFormat presets into the setup flow

### Task 16: Layout widgets (FaceToFace, Grid, Focus)

- **Files:** Create `face_to_face_layout.dart`, `grid_layout.dart`, `focus_layout.dart`, `player_zone_compact.dart`, `game_control_bar.dart`
- FaceToFaceLayout: 2 zones stacked, top rotated 180deg
- GridLayout: 2x2 grid (4 players) or 2+1 (3 players)
- FocusLayout: owner zone (40% bottom) + compact adversary strip (scrollable top)
- PlayerZoneCompact: minimal card for adversaries in Focus mode
- GameControlBar: floating bar with dice/timer/switch layout/settings/end
- Switch layout button toggles between grid and focus

### Task 17: Drag & Drop zone reordering

- **Files:** Modify layout widgets to support `LongPressDraggable` + `DragTarget`
- Long press (1s) on PlayerHeader activates drag
- Visual feedback: scale 1.05 + shadow + 80% opacity
- Placeholder zones shown during drag
- Swap animation on drop (300ms)
- Persist new order in GameSession.playerOrder

### Task 18: Integrate into life_counter_page.dart

- **Files:** Modify `life_counter_page.dart`, `game_setup_modal.dart`
- Replace SharedPreferences state with GameSessionNotifier
- Use LayoutResolver to pick layout based on player count
- Wire Quick Start page as entry point (replace GameSetupModal)
- Wire crash recovery: check for active snapshot on init
- Wire GameHistory save with enriched PlayerHistorySnapshot
- Update timer to use GameSession.duration

### Task 19: Stats Tab

- **Files:** Create `stats_tab.dart`, modify game history page
- Add "Stats" tab alongside existing "Historique" tab
- Sections: Resume, Par Deck, Par Adversaire, Par Format
- Wire StatsProvider data into the UI
- Tap on entry → detail bottom sheet

---

## Summary

| Task | Description | Dependencies |
|------|-------------|-------------|
| 1 | GameFormat model + presets | None |
| 2 | CounterType model + built-in counters | None |
| 3 | PlayerConfig model (Owner/Guest) | None |
| 4 | GameSession + PlayerState + LifeEvent | Tasks 1, 3 |
| 5 | AnimationService | None |
| 6 | LayoutStrategy pattern | None |
| 7 | GameSessionController | Task 4 |
| 8 | Enriched GameHistory + StatsCalculator | None |
| 9 | Drift schema v2 + migration | None |
| 10 | GameSession crash recovery service | Task 4 |
| 11 | Service providers wiring | Tasks 7, 8, 10 |
| 12 | Decompose PlayerZone sub-widgets | Task 5 |
| 13 | CriticalOverlay + EliminationOverlay | Tasks 5, 12 |
| 14 | RadialMenu widget | Task 7 |
| 15 | Quick Start + Advanced Settings | Tasks 1, 2, 3, 9 |
| 16 | Layout widgets (FtF, Grid, Focus) | Tasks 6, 12 |
| 17 | Drag & Drop reordering | Tasks 7, 16 |
| 18 | Integration into life_counter_page | All above |
| 19 | Stats Tab | Tasks 8, 11 |

Tasks 1-6 are independent and can be parallelized. Tasks 7-11 depend on models. Tasks 12-19 are UI and build sequentially on the foundation.
