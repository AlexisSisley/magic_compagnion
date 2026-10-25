// Tests de la migration SharedPreferences -> Drift pour les decks.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/data/migration/migration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('une date de deck illisible migre avec updatedAt nul', () async {
    SharedPreferences.setMockInitialValues({
      'user_decks': json.encode([
        {
          'id': 'x',
          'name': 'Date cassée',
          'updatedAt': 'pas une date',
          'mainboard': [],
          'sideboard': [],
        },
      ]),
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await MigrationService(db).migrateIfNeeded(), isTrue);

    final deck = (await db.getAllDecksRaw()).single;
    expect(deck.name, 'Date cassée');
    expect(deck.updatedAt, isNull);
  });
}
