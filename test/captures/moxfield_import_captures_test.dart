// test/captures/moxfield_import_captures_test.dart
//
// Captures visuelles bloquantes du chantier "import Moxfield" (sept taches,
// voir .superpowers/sdd/2026-09-19-import-moxfield/task-8-brief.md). Sa spec
// fait de la validation visuelle une porte bloquante : les tests de widgets
// (`test/widgets/collection/moxfield_import_sheet_test.dart`,
// `moxfield_import_report_test.dart`) verifient la presence de textes et de
// boutons -- ils ne disent rien de la lisibilite reelle. Ce fichier ne
// verifie rien par assertion : il rend les quatre ecrans du parcours en PNG
// reel via `matchesGoldenFile`, pour qu'un humain les regarde avant merge.
// Modele suivi a la lettre : `test/captures/life_counter_captures_test.dart`
// -- lire son commentaire de fichier pour le detail de chaque mecanisme
// repris ici (deuxieme exemple, plus proche : `identite_tirage_langue_
// captures_test.dart`, meme chantier de import).
//
// Tag `capture` (voir dart_test.yaml) : ces PNG dependent du rendu de police
// de la machine qui les produit, donc `flutter test` seul (CI) les ignore.
// Pour les (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/moxfield_import_captures_test.dart
//
// `--run-skipped` est necessaire EN PLUS de `--tags capture` : la config
// `skip:` de dart_test.yaml s'applique meme quand le tag est explicitement
// selectionne -- voir le commentaire de fichier du modele pour le detail.
//
// Polices reelles (voir `_loadSystemFont` / `setUpAll`, copiees telles
// quelles depuis le modele) : le binding de test headless de cette machine
// ne rend AUCUN glyphe reel par defaut -- on charge donc de vraies polices
// systeme sur disque (Segoe UI, Segoe UI Emoji) sous les noms de famille
// attendus par le rendu. 'Roboto' -- repli Flutter par defaut, utilise par
// les boutons de ce parcours qui n'ont pas de style Cinzel explicite
// ("Annuler", "Importer"/"Importer quand meme", "Fermer"). 'Cinzel_700' et
// 'Cinzel_regular' -- les deux SEULS poids de `AppTextStyles` reellement
// utilises par `MoxfieldImportSheet`/`MoxfieldImportReport` : identifies en
// lisant `app_text_styles.dart` (pas en imprimant a l'execution comme le
// modele -- lecture suffisante ici, tous les appels passent soit un
// `fontWeight: FontWeight.bold` explicite (w700 -> 'Cinzel_700' :
// `sectionTitle`, `pageTitle`, `buttonText`, le numero de `_step`), soit
// aucun poids (w400 par defaut de `google_fonts` -> 'Cinzel_regular' :
// `body`, `label`, la puce `_chip`, le nom de carte de `_namesPanel`). Pas de
// `MaterialIcons` charge ici, contrairement au modele : ces quatre ecrans ne
// rendent aucune `Icon` (verifie en lisant les deux fichiers source), un
// chargement bonus serait donc mort. Aucune police n'est copiee dans le
// depot, aucune dependance n'est ajoutee au pubspec.
//
// Widgets reels, pas de reconstitution : `MoxfieldImportSheet` avec son
// parametre `debugParsed` (couture de test documentee sur le widget lui-meme)
// pour les ecrans 20/21/23, un vrai tap sur "Importer" avec un
// `CollectionImportService` bouchon (meme pattern que
// `moxfield_import_sheet_test.dart`) pour atteindre l'ecran de bilan (22) --
// jamais `MoxfieldImportReport` seul reconstruit a la main avec des donnees
// inventees hors du parcours.
@Tags(['capture'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_import_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/widgets/collection/moxfield_import_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// Double de service, memes classes que
// `test/widgets/collection/moxfield_import_sheet_test.dart` -- pas une
// nouvelle reconstitution : le bilan (capture 22) doit venir d'un vrai
// parcours (debugParsed -> tap "Importer" -> resultat), avec seulement le
// reseau/la base coupes.
// ============================================================

/// Rend un resultat fixe et "realiste" (compteurs + cartes tagees nommees),
/// sans jamais toucher au reseau ni a la base.
class _StubImportService extends CollectionImportService {
  _StubImportService({required super.db, required super.resolver});

  @override
  Future<CollectionImportResult> import(
    CollectionParseResult parsed, {
    required String preferredLang,
  }) async {
    return const CollectionImportResult(
      imported: 1189,
      added: 340,
      updated: 831,
      tagged: 18,
      taggedNames: [
        'Lightning Bolt',
        'Sol Ring',
        'Brainstorm',
        'Counterspell',
      ],
    );
  }
}

/// Se termine immediatement (contrairement au double gate du test de widget
/// original, dont le but est de prouver le non-blocage) : cette capture ne
/// juge que l'etat final affiche, pas la course entre bilan et drain.
class _NoopTranslationWorker extends TranslationWorker {
  _NoopTranslationWorker({required super.resolver, required super.db});

  @override
  Future<int> drain({int batchSize = 50}) async => 0;
}

// ============================================================
// Theme + polices reelles -- copie fidele du mecanisme du modele (voir son
// commentaire de fichier pour le detail de chaque trouvaille). Seuls les
// noms de familles composees changent, pour matcher les poids reellement
// utilises par ce chantier (voir le commentaire de fichier ci-dessus).
// ============================================================

ThemeData _appTheme() => ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
    );

Future<void> _loadSystemFont(String family, List<String> absolutePaths) async {
  final loader = FontLoader(family);
  for (final absolutePath in absolutePaths) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      fail(
        'Police systeme introuvable : "$absolutePath" (attendue pour charger '
        'la famille "$family"). Sans elle, cette capture rendrait du texte en '
        'tofu illisible au lieu d\'echouer -- voir le commentaire de fichier '
        'sur `_loadSystemFont`. Ajuste le chemin pour la machine qui '
        'regenere ces PNG.',
      );
    }
    final bytes = file.readAsBytesSync();
    final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
    loader.addFont(Future.value(byteData));
  }
  await loader.load();
}

String get _windowsFontsDir {
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  return '$systemRoot\\Fonts';
}

/// Charge les polices reelles necessaires a ces quatre ecrans -- voir le
/// commentaire de fichier pour l'identification des poids ('Cinzel_700' et
/// 'Cinzel_regular', pas 'Cinzel_600' comme le modele : ce chantier n'utilise
/// jamais `cardTitle`).
Future<void> _loadRealFontsForCaptures() async {
  final textAndEmoji = [
    '$_windowsFontsDir\\seguiemj.ttf',
    '$_windowsFontsDir\\segoeui.ttf',
  ];
  await _loadSystemFont('Roboto', textAndEmoji);
  await _loadSystemFont('Cinzel_700', textAndEmoji);
  await _loadSystemFont('Cinzel_regular', textAndEmoji);
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

/// Voir le commentaire de fichier du modele sur `_runGuarded` : la Future
/// orpheline de `googleFontsTextStyle` (chargement reseau rejete, coupe par
/// `GoogleFonts.config.allowRuntimeFetching = false`) doit etre absorbee par
/// une zone a soi, pas seulement un try/catch, sinon le test reste marque
/// [E] malgre un rendu correct.
Future<void> _runGuarded(Future<void> Function() body) async {
  final done = Completer<void>();
  runZonedGuarded(() async {
    try {
      await body();
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }, (error, stack) {
    if (!done.isCompleted) done.complete();
  });
  await done.future;
}

/// Un lot de lignes "realiste" -- 1247 comme la maquette de reference, pas un
/// chiffre rond invente : seul le compte importe ici (`linesRead`), le
/// contenu de chaque entree n'est jamais affiche par l'ecran de verification.
List<CollectionEntry> _entries(int count) => List.generate(
      count,
      (i) => CollectionEntry(
        name: 'Carte $i',
        quantity: 1,
        setCode: 'set',
        collectorNumber: '$i',
      ),
      growable: false,
    );

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _appTheme(),
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  group('Captures -- import Moxfield', () {
    testWidgets('20 - ecran d\'explication : les quatre etapes de l\'export',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(_host(const MoxfieldImportSheet()));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/20_moxfield_explication.png'),
      );
    });

    testWidgets(
        '21 - ecran de verification : 1247 lignes, six colonnes reconnues',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(_host(MoxfieldImportSheet(
          debugParsed: CollectionParseResult(
            entries: _entries(1247),
            recognizedColumns: const [
              'Count',
              'Name',
              'Edition',
              'Collector Number',
              'Foil',
            ],
          ),
        )));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/21_moxfield_verification.png'),
      );
    });

    testWidgets(
        '22 - ecran de bilan : les quatre compteurs et les cartes tagees nommees',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final resolver = CardResolver(api: ScryfallApiService(), db: db);
      final stubImport = _StubImportService(db: db, resolver: resolver);
      final noopWorker = _NoopTranslationWorker(resolver: resolver, db: db);

      await _runGuarded(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionImportServiceProvider.overrideWithValue(stubImport),
              translationWorkerProvider.overrideWithValue(noopWorker),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _appTheme(),
              home: Scaffold(
                body: MoxfieldImportSheet(
                  debugParsed: CollectionParseResult(
                    entries: _entries(1247),
                    recognizedColumns: const [
                      'Count',
                      'Name',
                      'Edition',
                      'Collector Number',
                      'Foil',
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Importer'));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      // Preuve qu'on capture bien l'ecran de bilan, pas la verification.
      expect(find.text('Import terminé'), findsOneWidget);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/22_moxfield_bilan.png'),
      );
    });

    testWidgets(
        '23 - ecran degrade : colonnes d\'identite manquantes en ambre, '
        '"Importer quand meme"', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(_host(MoxfieldImportSheet(
          debugParsed: CollectionParseResult(
            entries: _entries(1247),
            recognizedColumns: const ['Count', 'Name', 'Foil'],
            missingIdentityColumns: const ['Edition', 'Collector Number'],
          ),
        )));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      expect(find.text('Importer quand même'), findsOneWidget);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/23_moxfield_degrade.png'),
      );
    });
  });
}
