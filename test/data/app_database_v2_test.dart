import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';

AppDatabase _createTestDb() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;
  setUp(() { db = _createTestDb(); });
  tearDown(() async { await db.close(); });

  group('GameFormats table', () {
    test('insert and retrieve a custom format', () async {
      await db.upsertGameFormat(GameFormatsCompanion.insert(
        id: 'my-format', name: 'My Format',
        startingLife: const Value(30), minPlayers: const Value(2), maxPlayers: const Value(6),
        maxCommanders: const Value(3), enabledCounterIds: const Value('["poison","energy"]'),
        isBuiltIn: const Value(false),
      ));
      final formats = await db.getAllGameFormats();
      expect(formats, hasLength(1));
      expect(formats.first.name, 'My Format');
      expect(formats.first.startingLife, 30);
    });
  });

  group('CounterTypes table', () {
    test('insert and retrieve a custom counter', () async {
      await db.upsertCounterType(CounterTypesCompanion.insert(
        id: 'storm', name: 'Storm Count',
        emoji: const Value('⚡'), color: const Value(0xFFFF9800), isBuiltIn: const Value(false),
      ));
      final counters = await db.getAllCounterTypes();
      expect(counters, hasLength(1));
      expect(counters.first.name, 'Storm Count');
    });
  });

  group('PlayerConfigs table', () {
    test('insert owner config and retrieve', () async {
      await db.upsertPlayerConfig(PlayerConfigsCompanion.insert(
        id: 'owner-1', name: 'Alex', type: const Value('owner'), colorValue: const Value(0xFF0D47A1),
      ));
      final configs = await db.getAllPlayerConfigs();
      expect(configs, hasLength(1));
      expect(configs.first.name, 'Alex');
      expect(configs.first.type, 'owner');
    });

    test('insert player config commanders', () async {
      await db.upsertPlayerConfig(PlayerConfigsCompanion.insert(
        id: 'guest-1', name: 'Max', type: const Value('guest'),
      ));
      await db.insertPlayerConfigCommander(PlayerConfigCommandersCompanion.insert(
        id: 'cmd-1', playerConfigId: 'guest-1', name: 'Atraxa', sortOrder: const Value(0),
      ));
      final commanders = await db.getCommandersForConfig('guest-1');
      expect(commanders, hasLength(1));
      expect(commanders.first.name, 'Atraxa');
    });
  });

  group('Enriched GameHistory', () {
    test('insert with new fields and retrieve', () async {
      await db.insertGameHistory(GameHistoryItemsCompanion.insert(
        id: 'game-1', date: DateTime(2026, 3, 29), winnerName: 'Alex',
        format: const Value('Commander'), startingLife: const Value(40), playerCount: const Value(4),
        tag: const Value('Soiree chez Max'), winnerDeckName: const Value('Atraxa Superfriends'),
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
