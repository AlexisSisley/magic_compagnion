// Fichier : test/services/backup_service_test.dart
// Tests unitaires pour BackupService

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackupService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = BackupService();
  });

  // ──────────────────────────────────────────────
  // 1. generateBackupJson() inclut backup_date et app_version
  // ──────────────────────────────────────────────
  test('generateBackupJson() inclut backup_date et app_version', () async {
    final jsonString = await service.generateBackupJson();
    final data = json.decode(jsonString) as Map<String, dynamic>;

    expect(data, contains('backup_date'));
    expect(data, contains('app_version'));
    expect(data['app_version'], '1.0.0');
    // backup_date doit être un ISO 8601 parseable
    expect(() => DateTime.parse(data['backup_date'] as String), returnsNormally);
  });

  // ──────────────────────────────────────────────
  // 2. generateBackupJson() gère les clés JSON (collection, decks)
  // ──────────────────────────────────────────────
  test('generateBackupJson() gère les clés JSON (user_collection, user_decks)', () async {
    final collectionData = [
      {'scryfallId': 'abc', 'name': 'Lightning Bolt', 'quantity': 4}
    ];
    final decksData = [
      {'id': 'deck-1', 'name': 'Burn', 'mainboard': [], 'sideboard': []}
    ];

    SharedPreferences.setMockInitialValues({
      'user_collection': json.encode(collectionData),
      'user_decks': json.encode(decksData),
    });
    service = BackupService();

    final jsonString = await service.generateBackupJson();
    final data = json.decode(jsonString) as Map<String, dynamic>;

    // Les valeurs JSON stockées en String doivent être décodées en objets
    expect(data['user_collection'], isList);
    expect((data['user_collection'] as List).first['name'], 'Lightning Bolt');

    expect(data['user_decks'], isList);
    expect((data['user_decks'] as List).first['name'], 'Burn');
  });

  // ──────────────────────────────────────────────
  // 3. generateBackupJson() gère les clés String simples
  // ──────────────────────────────────────────────
  test('generateBackupJson() gère les clés String simples (glossaryLang)', () async {
    SharedPreferences.setMockInitialValues({
      'glossaryLang': 'fr',
    });
    service = BackupService();

    final jsonString = await service.generateBackupJson();
    final data = json.decode(jsonString) as Map<String, dynamic>;

    // Une string simple (non-JSON) reste une string
    expect(data['glossaryLang'], 'fr');
    expect(data['glossaryLang'], isA<String>());
  });

  // ──────────────────────────────────────────────
  // 4. generateBackupJson() gère les clés int
  // ──────────────────────────────────────────────
  test('generateBackupJson() gère les clés int (playerCount, startingLife)', () async {
    SharedPreferences.setMockInitialValues({
      'playerCount': 4,
      'startingLife': 40,
    });
    service = BackupService();

    final jsonString = await service.generateBackupJson();
    final data = json.decode(jsonString) as Map<String, dynamic>;

    expect(data['playerCount'], 4);
    expect(data['startingLife'], 40);
    expect(data['playerCount'], isA<int>());
    expect(data['startingLife'], isA<int>());
  });

  // ──────────────────────────────────────────────
  // 5. Roundtrip : generate -> restore -> re-generate -> mêmes données
  // ──────────────────────────────────────────────
  test('Roundtrip : generate → restore → re-generate produit les mêmes données', () async {
    final collectionData = [
      {'scryfallId': 'bolt-001', 'name': 'Lightning Bolt', 'quantity': 4}
    ];

    SharedPreferences.setMockInitialValues({
      'user_collection': json.encode(collectionData),
      'glossaryLang': 'en',
      'playerCount': 2,
      'startingLife': 20,
    });
    service = BackupService();

    // Etape 1 : Générer le backup
    final firstBackup = await service.generateBackupJson();
    final firstData = json.decode(firstBackup) as Map<String, dynamic>;

    // Etape 2 : Réinitialiser les prefs et restaurer
    SharedPreferences.setMockInitialValues({});
    service = BackupService();
    await service.restoreFromJson(firstBackup);

    // Etape 3 : Re-générer et comparer les données métier (hors backup_date)
    final secondBackup = await service.generateBackupJson();
    final secondData = json.decode(secondBackup) as Map<String, dynamic>;

    // Comparer les clés métier (pas backup_date qui change à chaque appel)
    expect(secondData['user_collection'], equals(firstData['user_collection']));
    expect(secondData['glossaryLang'], equals(firstData['glossaryLang']));
    expect(secondData['playerCount'], equals(firstData['playerCount']));
    expect(secondData['startingLife'], equals(firstData['startingLife']));
    expect(secondData['app_version'], equals(firstData['app_version']));
  });

  // ──────────────────────────────────────────────
  // 6. restoreFromJson() avec JSON corrompu -> Exception
  // ──────────────────────────────────────────────
  test('restoreFromJson() avec JSON corrompu lève une Exception', () async {
    const corruptedJson = '{{{not valid json at all!!!';

    expect(
      () => service.restoreFromJson(corruptedJson),
      throwsA(isA<Exception>()),
    );
  });

  // ──────────────────────────────────────────────
  // Tags et date de modification des decks (sauvegarde Drift)
  // ──────────────────────────────────────────────
  group('decks Drift : tags et updatedAt', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('export puis import rendent tags et updatedAt identiques', () async {
      final date = DateTime.utc(2026, 3, 4, 5, 6, 7);
      await db.insertDeck(DecksCompanion.insert(
        id: 'd1',
        name: 'Test',
        tags: Value(json.encode(['Casual', 'Ramp'])),
        updatedAt: Value(date),
      ));
      await db.upsertDeckCard(
          deckId: 'd1', board: 'main', scryfallId: 'c1', cardName: 'Sol Ring',
          absoluteQuantity: 3, proxyQuantity: 2);
      final svc = BackupService(database: db);

      final sauvegarde = await svc.generateBackupJson();
      await svc.restoreFromJson(sauvegarde);

      final deck = (await db.getAllDecksRaw()).single;
      expect(AppDatabase.decodeTags(deck.tags), ['Casual', 'Ramp']);
      expect(deck.updatedAt!.isAtSameMomentAs(date), isTrue);
      expect((await db.getDeckCardsByDeckId('d1')).single.proxyQuantity, 2);
    });

    test('restaurer efface les preferences d affichage des decks', () async {
      await db.insertDeck(DecksCompanion.insert(id: 'd1', name: 'Test'));
      await db.setSetting('deck_view:d1', '{"layout":"list"}');
      await db.setSetting('deck_view:disparu', '{}');
      await db.setSetting('autre_reglage', 'garde');
      final svc = BackupService(database: db);

      await svc.restoreFromJson(await svc.generateBackupJson());

      expect(await db.getSetting('deck_view:d1'), isNull);
      expect(await db.getSetting('deck_view:disparu'), isNull);
      expect(await db.getSetting('autre_reglage'), 'garde');
    });

    test('backup exports and restores the tag catalog', () async {
      final custom = [
        {'key': 'draw', 'name': 'Ma pioche', 'color': 0xFF42A5F5},
        {'key': null, 'name': 'Perso', 'color': 0xFF123456},
      ];
      await db.setSetting('card_tags:universal', json.encode(custom));
      final svc = BackupService(database: db);

      final sauvegarde = await svc.generateBackupJson();
      expect((json.decode(sauvegarde) as Map)['card_tags_universal'], custom);

      await db.setSetting('card_tags:universal', '[]');
      await svc.restoreFromJson(sauvegarde);

      expect(json.decode((await db.getSetting('card_tags:universal'))!), custom);
    });

    test('old backup without catalog keeps current catalog', () async {
      await db.setSetting('card_tags:universal', '[{"key":null,"name":"Garde","color":1}]');
      final svc = BackupService(database: db);

      await svc.restoreFromJson(json.encode({'user_decks': []}));

      expect(
        json.decode((await db.getSetting('card_tags:universal'))!),
        [
          {'key': null, 'name': 'Garde', 'color': 1},
        ],
      );
    });

    test('restoring a pre-1.13 backup converts category to tags', () async {
      const catalogue = '[{"key":null,"name":"Garde","color":1}]';
      await db.setSetting('card_tags:universal', catalogue);
      final svc = BackupService(database: db);

      await svc.restoreFromJson(json.encode({
        'user_decks': [
          {
            'id': 'old',
            'name': 'Ancien',
            'mainboard': [
              {
                'scryfallId': 'w',
                'name': 'Wrath',
                'quantity': 1,
                'tags': [],
                'category': 'wipe',
                'categoryLocked': true,
              },
              {
                'scryfallId': 'b',
                'name': 'Bears',
                'quantity': 1,
                'tags': ['Perso'],
                'category': 'creatures',
                'categoryLocked': false,
              },
            ],
            'sideboard': [],
          },
        ],
      }));

      final cards = await db.getDeckCardsByDeckId('old');
      final wrath = cards.firstWhere((c) => c.scryfallId == 'w');
      expect(AppDatabase.decodeTags(wrath.tags), ['Wipe']);
      expect(wrath.tagsEdited, isTrue);
      final bears = cards.firstWhere((c) => c.scryfallId == 'b');
      expect(AppDatabase.decodeTags(bears.tags), ['Perso']);
      expect(bears.tagsEdited, isFalse);
      expect(await db.getSetting('card_tags:universal'), catalogue);
    });

    test('export puis import conservent tags et tagsEdited', () async {
      await db.insertDeck(DecksCompanion.insert(id: 'd1', name: 'Test'));
      await db.upsertDeckCard(
          deckId: 'd1', board: 'main', scryfallId: 'c1', cardName: 'Swords',
          absoluteQuantity: 1, newTags: ['Removal', 'Perso'], tagsEdited: true);
      await db.upsertDeckCard(
          deckId: 'd1', board: 'main', scryfallId: 'c2', cardName: 'Island',
          absoluteQuantity: 1);
      final svc = BackupService(database: db);

      final sauvegarde = await svc.generateBackupJson();
      await svc.restoreFromJson(sauvegarde);

      final cards = await db.getDeckCardsByDeckId('d1');
      final c1 = cards.firstWhere((c) => c.scryfallId == 'c1');
      expect(AppDatabase.decodeTags(c1.tags), ['Removal', 'Perso']);
      expect(c1.tagsEdited, isTrue);
      final c2 = cards.firstWhere((c) => c.scryfallId == 'c2');
      expect(AppDatabase.decodeTags(c2.tags), isEmpty);
      expect(c2.tagsEdited, isFalse);
    });

    test('une sauvegarde ancienne sans ces cles importe avec [] et null', () async {
      final svc = BackupService(database: db);
      await svc.restoreFromJson(json.encode({
        'user_decks': [
          {'id': 'old', 'name': 'Ancien', 'mainboard': [], 'sideboard': []},
        ],
      }));

      final deck = (await db.getAllDecksRaw()).single;
      expect(AppDatabase.decodeTags(deck.tags), isEmpty);
      expect(deck.updatedAt, isNull);
    });

    test('une date illisible importe le deck avec updatedAt nul', () async {
      final svc = BackupService(database: db);
      await svc.restoreFromJson(json.encode({
        'user_decks': [
          {
            'id': 'x',
            'name': 'Date cassée',
            'updatedAt': 'pas une date',
            'mainboard': [],
            'sideboard': [],
          },
        ],
      }));

      final deck = (await db.getAllDecksRaw()).single;
      expect(deck.name, 'Date cassée');
      expect(deck.updatedAt, isNull);
    });
  });
}
