import 'dart:async';

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

/// Double de [TranslationWorker] : compte ses appels a drain() et rend un
/// Future que le test seul controle (via [release]), pour prouver que le
/// bilan s'affiche AVANT que le drain ne se termine -- pas seulement qu'il a
/// ete appele. Un `drain()` qui rend 0 immediatement (comme un simple
/// compteur) ne distinguerait pas `unawaited(drain())` d'un `await
/// drain()` : les deux feraient passer un test qui ne verifie que le nombre
/// d'appels apres un `pumpAndSettle()`.
class _GatedTranslationWorker extends TranslationWorker {
  _GatedTranslationWorker({required super.resolver, required super.db});

  int drainCalls = 0;
  final Completer<int> _gate = Completer<int>();

  @override
  Future<int> drain({int batchSize = 50}) async {
    drainCalls++;
    return _gate.future;
  }

  /// A appeler en fin de test pour ne pas laisser un Future en suspens.
  void release() => _gate.complete(0);
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
        recognizedColumns: ['Count', 'Name', 'Edition', 'Collector Number', 'Foil'],
      ),
    )));
    await tester.pumpAndSettle();

    // Egalite stricte, pas `textContaining('1')` : '1' est une sous-chaine de
    // '1247' comme de 'Collector Number', et l assertion passait meme si le
    // compteur de lignes lues n etait pas rendu du tout.
    expect(find.text('1'), findsOneWidget);
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
    // Une colonne manquante porte une croix en prefixe (indice textuel, pas
    // seulement une couleur -- accessibilite daltonisme) et jamais un
    // adjectif accorde ("absente"/"absent" serait faux sur "Collector
    // Number").
    expect(find.text('✕ Edition'), findsOneWidget);
    expect(find.text('✕ Collector Number'), findsOneWidget);
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

  testWidgets(
      'le bilan s affiche avant que le drain de traduction ne se termine (non-bloquant)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final resolver = CardResolver(api: ScryfallApiService(), db: db);
    final stubImport = _StubImportService(db: db, resolver: resolver);
    final gatedWorker = _GatedTranslationWorker(resolver: resolver, db: db);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        collectionImportServiceProvider.overrideWithValue(stubImport),
        translationWorkerProvider.overrideWithValue(gatedWorker),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: MoxfieldImportSheet(
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
    // Laisse l'import et le lancement du drain s'executer, SANS liberer le
    // Completer du drain. Si `_doImport` attendait le drain (`await` au lieu
    // de `unawaited`), l'ecran resterait bloque avant l'affichage du bilan :
    // ce test echouerait a `pump()` constant, contrairement a un simple
    // compte d'appels apres `pumpAndSettle()`.
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }

    expect(gatedWorker.drainCalls, 1);
    expect(find.text('Import terminé'), findsOneWidget);

    // Nettoyage : libere le Future en suspens pour ne pas le laisser fuiter
    // hors du test.
    gatedWorker.release();
    await tester.pump();
  });

  testWidgets(
      'un echec de lecture du fichier affiche un message, sans jamais rester silencieux',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir le fichier'));
    // Aucun handler n'est enregistre pour le canal de plateforme de
    // file_picker dans un test widget : l'appel echoue reellement
    // (MissingPluginException). C'est un echec authentique de la meme
    // famille que ceux vises par ce test -- permission refusee, fichier
    // supprime entre la selection et la lecture, encodage invalide -- pas
    // un echec simule.
    await tester.pumpAndSettle();

    expect(find.textContaining('Impossible de lire le fichier'), findsOneWidget);
    // L'utilisateur reste sur l'ecran d'explication : aucun ecran de
    // verification ne s'est ouvert sur un resultat invalide.
    expect(find.text('Choisir le fichier'), findsOneWidget);
  });
}
