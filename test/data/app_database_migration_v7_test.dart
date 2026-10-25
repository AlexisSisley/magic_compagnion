// Montee de schema v6 -> v7 sur une vraie base v6 : la categorie des cartes de
// deck devient un tag, son verrou devient tagsEdited, et les deux anciennes
// colonnes disparaissent. Meme technique que la migration v5 -> v6 (DDL fige
// + PRAGMA user_version).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';

/// DDL v6 de `decks` et `deck_cards`. Ne JAMAIS le regenerer depuis le code
/// courant : il doit rester fige.
void _createV6DeckTables(dynamic raw) {
  raw.execute(
    '''
CREATE TABLE "decks" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "format" TEXT NOT NULL DEFAULT 'Standard', "commander_scryfall_id" TEXT NULL, "commander_secondary_scryfall_id" TEXT NULL, "colors" TEXT NOT NULL DEFAULT '[]', "tags" TEXT NOT NULL DEFAULT '[]', "updated_at" INTEGER NULL, PRIMARY KEY ("id"))''',
  );
  raw.execute(
    '''
CREATE TABLE "deck_cards" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "deck_id" TEXT NOT NULL REFERENCES decks (id), "board" TEXT NOT NULL, "scryfall_id" TEXT NOT NULL, "name" TEXT NOT NULL, "quantity" INTEGER NOT NULL DEFAULT 1, "proxy_quantity" INTEGER NOT NULL DEFAULT 0, "is_foil" INTEGER NOT NULL DEFAULT 0 CHECK ("is_foil" IN (0, 1)), "tags" TEXT NOT NULL DEFAULT '[]', "category" TEXT NULL, "category_locked" INTEGER NOT NULL DEFAULT 0 CHECK ("category_locked" IN (0, 1)))''',
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          _createV6DeckTables(raw);
          raw.execute(
            '''
INSERT INTO decks (id, name, format, colors, tags) VALUES ('d1', 'Toph', 'Commander', '["W"]', '["Casual"]')''',
          );
          raw.execute('''
INSERT INTO deck_cards (deck_id, board, scryfall_id, name, quantity, proxy_quantity, is_foil, tags, category, category_locked) VALUES
  ('d1', 'main', 'a', 'Swords', 2, 1, 1, '[]', 'removal', 0),
  ('d1', 'main', 'b', 'Rampant Growth', 1, 0, 0, '["Commander"]', 'ramp', 1),
  ('d1', 'main', 'c', 'Island', 1, 0, 0, '[]', 'lands', 0),
  ('d1', 'side', 'd', 'Harmonize', 1, 0, 0, '["pioche"]', 'draw', 0),
  ('d1', 'side', 'e', 'Opt', 1, 0, 0, '["Cantrip"]', NULL, 0)''');
          raw.execute('PRAGMA user_version = 6');
        },
      ),
    );
  });

  tearDown(() => db.close());

  Future<DbDeckCard> row(String id) async =>
      (await db.getDeckCardsByDeckId('d1')).firstWhere(
        (c) => c.scryfallId == id,
      );

  test('(a) une catégorie de rôle devient le tag principal', () async {
    final a = await row('a');
    expect(AppDatabase.decodeTags(a.tags), ['Removal']);
    expect(a.tagsEdited, isFalse);
    expect(a.quantity, 2);
    expect(a.proxyQuantity, 1);
    expect(a.isFoil, isTrue);
  });

  test('(b) verrouillée : le rôle passe devant, tagsEdited vrai', () async {
    final b = await row('b');
    expect(AppDatabase.decodeTags(b.tags), ['Ramp', 'Commander']);
    expect(b.tagsEdited, isTrue);
  });

  test('(c) lands ne donne aucun tag', () async {
    expect(AppDatabase.decodeTags((await row('c')).tags), isEmpty);
  });

  test('(d) un tag déjà porté à la casse près n\'est pas doublé', () async {
    expect(AppDatabase.decodeTags((await row('d')).tags), ['pioche']);
    expect(AppDatabase.decodeTags((await row('e')).tags), ['Cantrip']);
  });

  test('(e) aucune ligne perdue, colonnes retirées, version 7', () async {
    expect(await db.getDeckCardsByDeckId('d1'), hasLength(5));
    final cols = await db.customSelect('PRAGMA table_info(deck_cards)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('tags_edited'));
    expect(names, isNot(contains('category')));
    expect(names, isNot(contains('category_locked')));
    final deck = (await db.getAllDecksRaw()).single;
    expect(AppDatabase.decodeTags(deck.tags), ['Casual']);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 7);
  });
}
