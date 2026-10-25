// Montee de schema v4 -> v5 sur une vraie base v4 : tags et updatedAt des decks.
//
// Technique (a reprendre pour les futures migrations) : on ne peut pas ouvrir
// une base "ancienne" avec le code courant, qui ne sait creer que le schema le
// plus recent. On construit donc l'executeur a la main : `setup` s'execute sur
// la connexion SQLite brute AVANT que Drift ne lise `user_version`. On y rejoue
// le DDL ffige de la version precedente, on insere des donnees, puis on pose
// `PRAGMA user_version`. A l'ouverture, Drift voit une base v4 et deroule
// `onUpgrade(from: 4, to: 5)` sur de vraies donnees.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';

/// DDL v4 de `decks` et `deck_cards`, copie de `sqlite_master` d'une base v4
/// neuve. Ne JAMAIS le regenerer depuis le code courant : il doit rester fige.
void _createV4DeckTables(dynamic raw) {
  raw.execute('''
CREATE TABLE "decks" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "format" TEXT NOT NULL DEFAULT 'Standard', "commander_scryfall_id" TEXT NULL, "commander_secondary_scryfall_id" TEXT NULL, "colors" TEXT NOT NULL DEFAULT '[]', PRIMARY KEY ("id"))''');
  raw.execute('''
CREATE TABLE "deck_cards" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "deck_id" TEXT NOT NULL REFERENCES decks (id), "board" TEXT NOT NULL, "scryfall_id" TEXT NOT NULL, "name" TEXT NOT NULL, "quantity" INTEGER NOT NULL DEFAULT 1, "proxy_quantity" INTEGER NOT NULL DEFAULT 0, "is_foil" INTEGER NOT NULL DEFAULT 0 CHECK ("is_foil" IN (0, 1)), "tags" TEXT NOT NULL DEFAULT '[]')''');
}

void main() {
  test('un deck v4 migre avec tags vide, updatedAt nul, cartes intactes',
      () async {
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      _createV4DeckTables(raw);
      raw.execute('''
INSERT INTO decks VALUES ('d1', 'Toph', 'Commander', 'cmdr-id', NULL, '["W","R","B"]')''');
      raw.execute('''
INSERT INTO deck_cards (deck_id, board, scryfall_id, name, quantity, proxy_quantity, is_foil, tags)
VALUES ('d1', 'main', 's1', 'Rampant Growth', 2, 1, 1, '["Ramp"]')''');
      raw.execute('''
INSERT INTO deck_cards (deck_id, board, scryfall_id, name) VALUES ('d1', 'main', 's2', 'Island')''');
      raw.execute('PRAGMA user_version = 4');
    }));
    addTearDown(db.close);

    final decks = await db.getAllDecksRaw();
    expect(decks, hasLength(1));
    expect(decks.single.name, 'Toph');
    expect(decks.single.colors, '["W","R","B"]');
    expect(decks.single.tags, '[]');
    expect(decks.single.updatedAt, isNull);

    final cards = await db.getDeckCardsByDeckId('d1');
    expect(cards, hasLength(2));
    final ramp = cards.firstWhere((c) => c.scryfallId == 's1');
    expect(ramp.tags, '["Ramp"]');
    expect(ramp.quantity, 2);
    expect(ramp.proxyQuantity, 1);
    expect(ramp.isFoil, isTrue);
    final island = cards.firstWhere((c) => c.scryfallId == 's2');
    expect(island.tags, '[]');
    expect(island.quantity, 1);
    expect(island.proxyQuantity, 0);
    expect(island.isFoil, isFalse);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    // Drift deroule toutes les marches jusqu'au schema courant, pas seulement
    // la v5 : une base v4 ouverte aujourd'hui sort en v6.
    expect(version.read<int>('user_version'), 6);
  });
}
