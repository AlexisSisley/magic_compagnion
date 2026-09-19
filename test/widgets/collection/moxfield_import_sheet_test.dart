import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_import_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';
import 'package:magic_companion/widgets/collection/moxfield_import_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Double de [CollectionImportService] : rend un resultat fixe sans jamais
/// toucher au reseau ni a la base.
class _StubImportService extends CollectionImportService {
  _StubImportService({required super.db, required super.resolver});

  int importCalls = 0;

  @override
  Future<CollectionImportResult> import(
    CollectionParseResult parsed, {
    required String preferredLang,
  }) async {
    importCalls++;
    return const CollectionImportResult(imported: 1, added: 1);
  }
}

/// Double de [TranslationWorker] : compte ses appels a drain() sans vider
/// une vraie file.
class _CountingTranslationWorker extends TranslationWorker {
  _CountingTranslationWorker({required super.resolver, required super.db});

  int drainCalls = 0;

  @override
  Future<int> drain({int batchSize = 50}) async {
    drainCalls++;
    return 0;
  }
}

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('l ecran d explication nomme les etapes de l export Moxfield',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet()));
    await tester.pumpAndSettle();

    expect(find.textContaining('moxfield.com'), findsOneWidget);
    expect(find.textContaining('Export'), findsWidgets);
    expect(find.text('Choisir le fichier'), findsOneWidget);
  });

  testWidgets('la verification affiche les colonnes reconnues et le nombre de lignes',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet(
      debugParsed: CollectionParseResult(
        entries: [CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284')],
        recognizedColumns: ['Count', 'Name', 'Edition', 'Collector Number', 'Language', 'Foil'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('1'), findsWidgets);
    expect(find.text('Edition'), findsOneWidget);
    expect(find.text('Importer'), findsOneWidget);
  });

  testWidgets('en mode degrade le bouton dit "Importer quand meme" et les colonnes manquantes sont nommees',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet(
      debugParsed: CollectionParseResult(
        entries: [CollectionEntry(name: 'Sol Ring', quantity: 1)],
        recognizedColumns: ['Count', 'Name'],
        missingIdentityColumns: ['Edition', 'Collector Number'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Importer quand même'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    expect(find.textContaining('Edition'), findsWidgets);
  });

  testWidgets('un refus affiche le message du parser et aucun bouton d import',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet(
      debugParsed: CollectionParseResult(
        refusal: 'Colonne(s) indispensable(s) introuvable(s) : Name.',
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Name'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    expect(find.text('Importer quand même'), findsNothing);
  });

  testWidgets('apres un import, la file de traduction est drainee', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final resolver = CardResolver(api: ScryfallApiService(), db: db);
    final stubImport = _StubImportService(db: db, resolver: resolver);
    final countingWorker = _CountingTranslationWorker(resolver: resolver, db: db);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        collectionImportServiceProvider.overrideWithValue(stubImport),
        translationWorkerProvider.overrideWithValue(countingWorker),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: const MoxfieldImportSheet(
            debugParsed: CollectionParseResult(
              entries: [CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284')],
              recognizedColumns: ['Count', 'Name', 'Edition', 'Collector Number'],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importer'));
    await tester.pumpAndSettle();

    expect(stubImport.importCalls, 1);
    expect(countingWorker.drainCalls, 1);
  });
}
