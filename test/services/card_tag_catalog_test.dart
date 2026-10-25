import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_tag_catalog_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_tag.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/card_tag_catalog.dart';

void main() {
  late AppDatabase db;
  late CardTagCatalog catalog;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CardTagCatalog(db);
    await db.insertDeck(DecksCompanion.insert(id: 'd1', name: 'A'));
    await db.insertDeck(DecksCompanion.insert(id: 'd2', name: 'B'));
  });
  tearDown(() => db.close());

  Future<void> card(String deck, String id, List<String> tags,
      {String board = 'main'}) {
    return db.upsertDeckCard(
        deckId: deck, board: board, scryfallId: id, cardName: id, absoluteQuantity: 1, newTags: tags);
  }

  Future<List<String>> tagsOf(String deck, String id, {String board = 'main'}) async {
    final rows = await db.getDeckCardsByDeckId(deck);
    return AppDatabase.decodeTags(
        rows.firstWhere((r) => r.scryfallId == id && r.board == board).tags);
  }

  test('load seeds defaults once', () async {
    expect(await catalog.load(), kDefaultCardTags);
    expect(await db.getSetting('card_tags:universal'), isNotNull);
    await catalog.save([]);
    expect(await catalog.load(), isEmpty);
  });

  test('load falls back on unreadable json', () async {
    await db.setSetting('card_tags:universal', '{x');
    expect(await catalog.load(), kDefaultCardTags);
  });

  test('rename propagates and dedupes', () async {
    await card('d1', 'a', ['Ma pioche', 'Pioche']);
    await card('d2', 'b', ['Pioche']);
    expect(await catalog.rename('Pioche', 'Ma pioche'), RenameResult.ok);
    expect(await tagsOf('d1', 'a'), ['Ma pioche']);
    expect(await tagsOf('d2', 'b'), ['Ma pioche']);
    final cat = await catalog.load();
    final draw = cat.firstWhere((t) => t.key == 'draw');
    expect(draw.name, 'Ma pioche');
  });

  test('rename to another universal name is refused', () async {
    await card('d1', 'a', ['Pioche']);
    expect(await catalog.rename('Pioche', 'removal'), RenameResult.duplicate);
    expect(await tagsOf('d1', 'a'), ['Pioche']);
    expect((await catalog.load()).map((t) => t.name), contains('Pioche'));
  });

  test('rename may change only the case of the same tag', () async {
    expect(await catalog.rename('Pioche', 'PIOCHE'), RenameResult.ok);
    expect((await catalog.load())[1].name, 'PIOCHE');
  });

  test('rename refuses invalid name', () async {
    expect(await catalog.rename('Pioche', '  '), RenameResult.invalid);
  });

  test('delete removes from cards and counts', () async {
    await card('d1', 'a', ['Blink', 'Ramp']);
    await card('d2', 'b', ['Ramp']);
    expect(await catalog.delete('Ramp'), 2);
    expect(await tagsOf('d1', 'a'), ['Blink']);
    expect(await tagsOf('d2', 'b'), isEmpty);
    expect((await catalog.load()).map((t) => t.name), isNot(contains('Ramp')));
  });

  test('usageCount counts rows, case-insensitively', () async {
    await card('d1', 'a', ['Blink', 'Ramp']);
    await card('d2', 'b', ['Ramp']);
    expect(await catalog.usageCount('Blink'), 1);
    expect(await catalog.usageCount('ramp'), 2);
  });

  test('add refuses invalid and duplicate names', () async {
    expect(await catalog.add('  '), isFalse);
    expect(await catalog.add('ramp'), isFalse);
    expect(await catalog.add('  Mon   tag ', color: 0xFF123456), isTrue);
    final added = (await catalog.load()).last;
    expect(added.name, 'Mon tag');
    expect(added.key, isNull);
    expect(added.color, 0xFF123456);
  });

  group('controller', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
    });

    Future<CardTagCatalogController> ready() async {
      final c = container.read(cardTagCatalogProvider.notifier);
      await c.load();
      return c;
    }

    test('charge le catalogue dans le constructeur', () async {
      container.read(cardTagCatalogProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(cardTagCatalogProvider), kDefaultCardTags);
    });

    test('add, setColor, reorder persistent', () async {
      final c = await ready();
      expect(await c.add('Nouveau'), isTrue);
      await c.setColor('Nouveau', 0xFF010203);
      await c.reorder(8, 0);
      final stored = await catalog.load();
      expect(stored.first.name, 'Nouveau');
      expect(stored.first.color, 0xFF010203);
      expect(container.read(cardTagCatalogProvider), stored);
    });

    test('reorder suit la convention de ReorderableListView', () async {
      final c = await ready();
      await c.reorder(0, 3); // Ramp passe après Removal
      expect(container.read(cardTagCatalogProvider).take(3).map((t) => t.name),
          ['Pioche', 'Removal', 'Ramp']);
    });

    test('rename et delete passent par le service', () async {
      final c = await ready();
      await card('d1', 'a', ['Blink']);
      expect(await c.rename('Blink', 'Clignote'), RenameResult.ok);
      expect(await tagsOf('d1', 'a'), ['Clignote']);
      expect(await c.delete('Clignote'), 1);
      expect(container.read(cardTagCatalogProvider).map((t) => t.name),
          isNot(contains('Clignote')));
      expect(json.decode((await db.getSetting('card_tags:universal'))!),
          isA<List>());
    });
  });
}
