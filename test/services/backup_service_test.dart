// Fichier : test/services/backup_service_test.dart
// Tests unitaires pour BackupService

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
