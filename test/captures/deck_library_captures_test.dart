// test/captures/deck_library_captures_test.dart
//
// Captures visuelles de la bibliotheque de decks redessinee (chantier C,
// critere 6.2) : grille a une, deux et trois colonnes, feuille de dossiers, et
// etat vide filtre. Un test de widget mesure des contraintes mais ne dit rien
// de la lisibilite : ces PNG sont faits pour etre regardes.
//
// `DeckListPage` n'est pas montable (singleton `LocalCardService` qui parse
// 166 Mo d'oracle via `compute()`) : on monte donc `DeckFilterBar` et
// `DeckLibraryGrid` dans un `Scaffold` au fond de l'application. Le reseau est
// coupe en test : la tuile avec commandant montre le repli de `ScryfallImage`,
// ce qui est attendu. La feuille de filtres n'est pas capturee : elle exige un
// `DeckListController` complet (services et base).
//
// Tag `capture` : les PNG dependent des polices de la machine. Pour les
// (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/deck_library_captures_test.dart
@Tags(['capture'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/controllers/deck_list_filters.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_filter_bar.dart';
import 'package:magic_companion/widgets/decks/deck_library_grid.dart';
import 'package:magic_companion/widgets/decks/deck_list_card.dart';
import 'package:magic_companion/widgets/decks/deck_tags_sheet.dart';

// ---------------------------------------------------------------------------
// Preambule de polices -- repris de grimoire_captures_test.dart.
// ---------------------------------------------------------------------------

/// Charge une pile de polices REELLES du systeme (jamais copiees dans le
/// depot, jamais une dependance pubspec) sous UNE seule famille [family].
///
/// Echoue bruyamment si l'un des [absolutePaths] n'existe pas : une capture
/// qui retombe silencieusement sur du tofu est exactement le piege que ce
/// mecanisme existe pour eviter.
Future<void> _loadSystemFont(String family, List<String> absolutePaths) async {
  final loader = FontLoader(family);
  for (final absolutePath in absolutePaths) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      fail(
        'Police systeme introuvable : "$absolutePath" (attendue pour charger '
        'la famille "$family"). Sans elle, cette capture rendrait du texte en '
        'tofu illisible au lieu d\'echouer. Ajuste le chemin pour la machine '
        'qui regenere ces PNG.',
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

/// Les familles composees dont ces captures ont besoin.
///
/// Relevees en imprimant `.fontFamily` : `pageTitle`/`sectionTitle` donnent
/// `Cinzel_700`, `cardTitle`/`appBarTitle` `Cinzel_600`, et cote Source Sans
/// 3, `body`/`subtitle`/`label`/`text` donnent `SourceSans3_regular` tandis
/// que `bold`/`buttonText`/`tabActive` donnent `SourceSans3_700`.
///
/// L'emoji EN PREMIER dans la pile : verifie par probe A/B dans le fichier
/// modele, le moteur committe la police du premier fichier qui couvre le
/// texte du passage, il ne retente pas glyphe par glyphe.
Future<void> _loadRealFontsForCaptures() async {
  final textAndEmoji = [
    '$_windowsFontsDir\\seguiemj.ttf',
    '$_windowsFontsDir\\segoeui.ttf',
  ];
  for (final family in [
    'Roboto',
    'Cinzel_700',
    'Cinzel_600',
    'Cinzel_regular',
    'SourceSans3_regular',
    'SourceSans3_700',
    'SourceSans3_600',
  ]) {
    await _loadSystemFont(family, textAndEmoji);
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final materialIconsPath =
        '$flutterRoot\\bin\\cache\\artifacts\\material_fonts\\MaterialIcons-Regular.otf';
    if (File(materialIconsPath).existsSync()) {
      await _loadSystemFont('MaterialIcons', [materialIconsPath]);
    }
  }
}

/// Voir `_runGuarded` dans identite_tirage_langue_captures_test.dart : la
/// Future orpheline de `googleFontsTextStyle` (chargement reseau rejete,
/// coupe par `allowRuntimeFetching = false`) doit etre absorbee par une zone
/// a soi, sinon le test reste marque [E] malgre un rendu correct.
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

void _setSurfaceSize(WidgetTester tester, Size size) {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}


// ---------------------------------------------------------------------------

Deck _deck(String name, String format, List<String> colors,
        {String? commander, int cards = 60, List<String> tags = const []}) =>
    Deck(
      id: name,
      name: name,
      format: format,
      colors: colors,
      commanderScryfallId: commander,
      tags: tags,
      mainboard: [DeckCard(scryfallId: name, name: name, quantity: cards)],
    );

/// Six decks : deux avec commandant, un incolore, un a deux tags, un nom tres
/// long, et des decks sans commandant.
List<Deck> _sixDecks() => [
      _deck('Atraxa Superfriends', 'Commander', const ['W', 'U', 'B', 'G'],
          commander: 'd0d33d52-3d28-4635-b985-51e126289259',
          cards: 107,
          tags: const ['Casual', 'cEDH']),
      _deck('Burn Mono-Rouge', 'Modern', const ['R'], cards: 60),
      _deck('Azorius Controle Tempo Moderne Edition Longue', 'Standard',
          const ['W', 'U'],
          cards: 75),
      _deck('Elfes', 'Legacy', const [], cards: 1),
      _deck('Golgari Cimetiere', 'Commander', const ['B', 'G'],
          commander: 'f2b9983e-20d4-4d12-9e2c-ec6d9a345787', cards: 99),
      _deck('Tron', 'Modern', const [], cards: 60, tags: const ['Tournoi']),
    ];

const _prices = {
  'Atraxa Superfriends': 289.4,
  'Burn Mono-Rouge': 120.0,
  'Azorius Controle Tempo Moderne Edition Longue': 412.0,
  'Elfes': 0.0,
  'Golgari Cimetiere': 87.0,
  'Tron': 1250.0,
};

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  Widget harness(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
            backgroundColor: AppColors.scaffoldBackground, body: child),
      );

  Widget library(List<Deck> decks, {bool libraryEmpty = false}) {
    const criteria = DeckFilterCriteria(
      format: 'Commander',
      priceRange: (0, 300),
    );
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DeckFilterBar(
              criteria: criteria,
              activeCount: activeFilterCount(criteria),
              onOpenFilters: () {},
              onSort: (_) {},
              onClear: (_) {},
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          DeckLibraryGrid(
            decks: decks,
            libraryEmpty: libraryEmpty,
            onClearAll: () {},
            tileBuilder: (d) => DeckListCard(
              deck: d,
              totalPrice: _prices[d.name] ?? 0,
              onTap: () {},
              confirmDismiss: (_) async => false,
              onDismissed: () {},
            ),
          ),
        ],
      ),
    );
  }

  group('Captures -- bibliotheque de decks', () {
    for (final (name, size, columns) in [
      ('1_colonne_390', const Size(390, 844), 1),
      ('2_colonnes_840', const Size(840, 700), 2),
      ('3_colonnes_1280', const Size(1280, 800), 3),
    ]) {
      testWidgets('bibliotheque a $columns colonne(s)', (tester) async {
        _setSurfaceSize(tester, size);
        await _runGuarded(() async {
          await tester.pumpWidget(harness(library(_sixDecks())));
          await tester.pump(const Duration(milliseconds: 300));
        });

        expect(tester.takeException(), isNull);
        expect(deckLibraryColumns(size.width), columns);
        expect(find.byType(DeckListCard), findsWidgets);
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/deck_library_$name.png'));
      });
    }

    testWidgets('etat vide filtre', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));
      await _runGuarded(() async {
        await tester.pumpWidget(harness(library(const [])));
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(tester.takeException(), isNull);
      expect(find.text('Aucun deck ne correspond'), findsOneWidget);
      expect(find.text('Tout effacer'), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/deck_library_vide_filtre.png'));
    });

    testWidgets('feuille de dossiers', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));
      await _runGuarded(() async {
        await tester.pumpWidget(harness(Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDeckTagsSheet(
                context,
                deckName: 'Atraxa Superfriends',
                current: const ['Casual'],
                known: const ['Casual', 'cEDH', 'Tournoi'],
              ),
              child: const Text('ouvrir'),
            ),
          ),
        )));
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckTagsSheet), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/deck_library_dossiers.png'));
    });
  });
}
