// Montee de schema depuis une vraie base v5 : les cartes de deck traversent la
// v6 (categorie) jusqu'a la v7 (tagsEdited) sans rien perdre.
// Meme technique que la migration v4 -> v5 (DDL fige + PRAGMA user_version).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';

/// DDL v5 de `decks` et `deck_cards`. Ne JAMAIS le regenerer depuis le code
/// courant : il doit rester fige.
void _createV5DeckTables(dynamic raw) {
  raw.execute(
    '''
CREATE TABLE "decks" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "format" TEXT NOT NULL DEFAULT 'Standard', "commander_scryfall_id" TEXT NULL, "commander_secondary_scryfall_id" TEXT NULL, "colors" TEXT NOT NULL DEFAULT '[]', "tags" TEXT NOT NULL DEFAULT '[]', "updated_at" INTEGER NULL, PRIMARY KEY ("id"))''',
  );
  raw.execute(
    '''
CREATE TABLE "deck_cards" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "deck_id" TEXT NOT NULL REFERENCES decks (id), "board" TEXT NOT NULL, "scryfall_id" TEXT NOT NULL, "name" TEXT NOT NULL, "quantity" INTEGER NOT NULL DEFAULT 1, "proxy_quantity" INTEGER NOT NULL DEFAULT 0, "is_foil" INTEGER NOT NULL DEFAULT 0 CHECK ("is_foil" IN (0, 1)), "tags" TEXT NOT NULL DEFAULT '[]')''',
  );
}

void main() {
  test(
    'les cartes v5 migrent sans tag ajoute ni drapeau, le reste intact',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            _createV5DeckTables(raw);
            raw.execute(
              '''
INSERT INTO decks (id, name, format, colors, tags) VALUES ('d1', 'Toph', 'Commander', '["W"]', '["Casual"]')''',
            );
            raw.execute('''
INSERT INTO deck_cards (deck_id, board, scryfall_id, name, quantity, proxy_quantity, is_foil, tags)
VALUES ('d1', 'main', 's1', 'Rampant Growth', 2, 1, 1, '["Ramp"]')''');
            raw.execute(
              '''
INSERT INTO deck_cards (deck_id, board, scryfall_id, name) VALUES ('d1', 'side', 's2', 'Island')''',
            );
            raw.execute('PRAGMA user_version = 5');
          },
        ),
      );
      addTearDown(db.close);

      final cards = await db.getDeckCardsByDeckId('d1');
      expect(cards, hasLength(2));
      for (final c in cards) {
        expect(c.tagsEdited, isFalse);
      }
      final ramp = cards.firstWhere((c) => c.scryfallId == 's1');
      expect(ramp.tags, '["Ramp"]');
      expect(ramp.quantity, 2);
      expect(ramp.proxyQuantity, 1);
      expect(ramp.isFoil, isTrue);
      final island = cards.firstWhere((c) => c.scryfallId == 's2');
      expect(island.quantity, 1);
      expect(island.proxyQuantity, 0);
      expect(island.isFoil, isFalse);

      // Un SELECT * lit une colonne absente comme nulle : seule une ecriture
      // prouve que la colonne existe bien apres la montee de version.
      await db.setDeckCardTags(
        deckId: 'd1',
        board: 'main',
        scryfallId: 's1',
        tags: ['Removal'],
        tagsEdited: true,
      );
      final relu = (await db.getDeckCardsByDeckId(
        'd1',
      )).firstWhere((c) => c.scryfallId == 's1');
      expect(AppDatabase.decodeTags(relu.tags), ['Removal']);
      expect(relu.tagsEdited, isTrue);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 7);
    },
  );
}
