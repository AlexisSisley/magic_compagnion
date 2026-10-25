import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/deck_view_prefs.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'sans valeur enregistrée : regroupement par catégorie, grille',
    () async {
      final p = await loadDeckViewPrefs(db, 'd1');
      expect(p.grouping, DeckGrouping.category);
      expect(p.layout, DeckLayout.grid);
    },
  );

  test('aller-retour, sous la clé et au format attendus', () async {
    await saveDeckViewPrefs(
      db,
      'd1',
      const DeckViewPrefs(grouping: DeckGrouping.type, layout: DeckLayout.list),
    );
    expect(
      await db.getSetting('deck_view:d1'),
      '{"grouping":"type","layout":"list"}',
    );
    final p = await loadDeckViewPrefs(db, 'd1');
    expect(p.grouping, DeckGrouping.type);
    expect(p.layout, DeckLayout.list);
    // Un autre deck n'en hérite pas.
    expect(await loadDeckViewPrefs(db, 'd2'), const DeckViewPrefs());
  });

  test('une valeur illisible rend les défauts', () async {
    for (final raw in ['{pas du json', '[1,2]', '{"grouping":"xyz"}']) {
      await db.setSetting('deck_view:d1', raw);
      expect(
        await loadDeckViewPrefs(db, 'd1'),
        const DeckViewPrefs(),
        reason: raw,
      );
    }
  });

  test('supprimer le deck efface ses préférences', () async {
    final service = DeckService(database: db);
    final id = await service.createNewDeck('Deck');
    final other = await service.createNewDeck('Autre');
    await saveDeckViewPrefs(
      db,
      id,
      const DeckViewPrefs(layout: DeckLayout.list),
    );
    await saveDeckViewPrefs(
      db,
      other,
      const DeckViewPrefs(layout: DeckLayout.list),
    );

    await service.deleteDeck(id);

    expect(await db.getSetting('deck_view:$id'), isNull);
    expect(await db.getSetting('deck_view:$other'), isNotNull);
  });
}
