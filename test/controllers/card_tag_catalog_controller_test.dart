// Fichier : test/controllers/card_tag_catalog_controller_test.dart
// Les écritures qui partent de l'état du contrôleur doivent attendre le
// chargement lancé par le constructeur.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_tag_catalog_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_tag.dart';
import 'package:magic_companion/services/card_tag_catalog.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test(
    'setColor appelé avant la fin du chargement garde le catalogue',
    () async {
      final ctrl = CardTagCatalogController(CardTagCatalog(db));

      await ctrl.setColor('Ramp', kCardTagPalette[9]);

      final stored = await CardTagCatalog(db).load();
      expect(stored.length, kDefaultCardTags.length);
      expect(stored.first.color, kCardTagPalette[9]);
    },
  );

  test(
    'reorder appelé avant la fin du chargement garde le catalogue',
    () async {
      final ctrl = CardTagCatalogController(CardTagCatalog(db));

      await ctrl.reorder(0, 2);

      final stored = await CardTagCatalog(db).load();
      expect(stored.length, kDefaultCardTags.length);
      expect([for (final t in stored) t.name].take(2), ['Pioche', 'Ramp']);
    },
  );
}
