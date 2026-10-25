// test/captures/deck_page_captures_test.dart
//
// Captures visuelles de la page d'un deck (chantier D, spec §6.2) : la VRAIE
// `DeckDetailPage`, montee sur une base en memoire avec `buildAppTheme()`.
// On regarde le bandeau dans ses trois etats (un commandant, un partenaire,
// aucun), la grille d'artworks groupee par categorie (memorisee pour ce deck,
// le defaut etant le type) avec une carte verrouillee, puis la liste en mode
// compact (groupee par type), a 840x700 et 390x844. Enfin, au telephone,
// l'onglet Liste juste apres un petit defilement : le bandeau est sorti et
// les puces, avec les interrupteurs au bout, restent au-dessus des cartes.
//
// Sans reseau, les arts (commandant et vignettes) affichent leurs replis : les
// donnees de carte (type, texte oracle, cout, prix) viennent d'un faux
// Scryfall, donc categories, CMC moyen et prix sont reels, pas les images.
//
// Tag `capture` (voir dart_test.yaml). Pour (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/deck_page_captures_test.dart
// Les polices reelles sont chargees comme dans grimoire_captures_test.dart.
@Tags(['capture'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/pages/decks/deck_detail_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/deck_view_prefs.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_commander_header.dart';

// ---------------------------------------------------------------------------
// Preambule de polices -- repris de grimoire_captures_test.dart.
// ---------------------------------------------------------------------------

/// Charge une pile de polices REELLES du systeme sous UNE seule famille
/// [family]. Echoue bruyamment si un chemin manque : une capture qui retombe
/// sur du tofu en silence est le piege que ce mecanisme evite.
Future<void> _loadSystemFont(String family, List<String> absolutePaths) async {
  final loader = FontLoader(family);
  for (final absolutePath in absolutePaths) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      fail(
        'Police systeme introuvable : "$absolutePath" (attendue pour charger '
        'la famille "$family"). Ajuste le chemin pour la machine qui '
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

/// Familles composees que google_fonts attend (`Cinzel_700`, jamais `Cinzel`).
/// L'emoji EN PREMIER dans la pile : le moteur committe la police du premier
/// fichier qui couvre le passage.
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
    // « Aucun commandant defini » est en italique : sans cette famille, le
    // texte sort en blocs vides.
    'SourceSans3_italic',
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

/// Erreurs ASYNCHRONES attendues hors ligne dans le harnais de test : polices
/// google_fonts non telechargeables, plugins natifs (shared_preferences,
/// path_provider) absents, SVG de symboles de mana qui ne se chargent pas.
/// Tout le reste est une vraie erreur.
bool _isExpectedOfflineError(Object error) {
  final text = error.toString();
  return error is MissingPluginException ||
      text.contains('Invalid SVG data') ||
      text.contains('GoogleFonts.config.allowRuntimeFetching is false');
}

/// La Future orpheline de `googleFontsTextStyle` (chargement reseau rejete)
/// doit etre absorbee par une zone a soi, sinon le test reste marque [E]
/// malgre un rendu correct. Seules les erreurs hors ligne attendues sont
/// absorbees : la premiere autre (seed, mount...) est relancee a la fin, pour
/// que le test echoue sur sa vraie cause.
Future<void> _runGuarded(Future<void> Function() body) async {
  final done = Completer<void>();
  Object? unexpected;
  StackTrace? unexpectedStack;
  runZonedGuarded(
    () async {
      try {
        await body();
      } finally {
        if (!done.isCompleted) done.complete();
      }
    },
    (error, stack) {
      if (_isExpectedOfflineError(error)) return;
      if (unexpected == null) {
        unexpected = error;
        unexpectedStack = stack;
      }
    },
  );
  await done.future;
  if (unexpected != null) {
    Error.throwWithStackTrace(unexpected!, unexpectedStack!);
  }
}

// ---------------------------------------------------------------------------
// Donnees : un deck Commander couvrant toutes les categories.
// ---------------------------------------------------------------------------

/// (id, nom, ligne de type, texte oracle, cmc, cout, prix EUR, quantite)
typedef _Fixture = (String, String, String, String, num, String, String, int);

const List<_Fixture> _fixtures = [
  ('sol', 'Sol Ring', 'Artifact', '{T}: Add {C}{C}.', 1, '{1}', '1.50', 1),
  (
    'signet',
    'Arcane Signet',
    'Artifact',
    '{T}: Add one mana of any color.',
    2,
    '{2}',
    '1.20',
    1,
  ),
  (
    'cult',
    'Cultivate',
    'Sorcery',
    'Search your library for up to two basic land cards and put them onto the battlefield.',
    3,
    '{2}{G}',
    '0.40',
    1,
  ),
  (
    'rhystic',
    'Rhystic Study',
    'Enchantment',
    'Whenever an opponent casts a spell, you may draw a card.',
    3,
    '{2}{U}',
    '30.00',
    1,
  ),
  (
    'arena',
    'Phyrexian Arena',
    'Enchantment',
    'At the beginning of your upkeep, you draw a card and you lose 1 life.',
    3,
    '{1}{B}{B}',
    '4.00',
    1,
  ),
  (
    'swords',
    'Swords to Plowshares',
    'Instant',
    'Exile target creature.',
    1,
    '{W}',
    '3.00',
    1,
  ),
  (
    'counter',
    'Counterspell',
    'Instant',
    'Counter target spell.',
    2,
    '{U}{U}',
    '2.00',
    1,
  ),
  (
    'beast',
    'Beast Within',
    'Instant',
    'Destroy target permanent.',
    3,
    '{2}{G}',
    '0.80',
    1,
  ),
  (
    'wrath',
    'Wrath of God',
    'Sorcery',
    'Destroy all creatures.',
    4,
    '{2}{W}{W}',
    '5.00',
    1,
  ),
  (
    'hero',
    'Heroic Intervention',
    'Instant',
    'Permanents you control gain hexproof and indestructible until end of turn.',
    2,
    '{1}{G}',
    '6.00',
    1,
  ),
  (
    'tutor',
    'Demonic Tutor',
    'Sorcery',
    'Search your library for a card.',
    2,
    '{1}{B}',
    '25.00',
    1,
  ),
  (
    'oracle',
    "Thassa's Oracle",
    'Creature — Merfolk Wizard',
    'When this enters, look at the top X cards. If X is greater, you win the game.',
    2,
    '{U}{U}',
    '1.00',
    1,
  ),
  (
    'witness',
    'Eternal Witness',
    'Creature — Human Shaman',
    'When this enters, you may return target card from your graveyard to your hand.',
    3,
    '{1}{G}{G}',
    '2.50',
    1,
  ),
  ('bear', 'Grizzly Bears', 'Creature — Bear', '', 2, '{1}{G}', '0.10', 2),
  (
    'elf',
    'Llanowar Elves',
    'Creature — Elf Druid',
    '{T}: Add {G}.',
    1,
    '{G}',
    '0.50',
    1,
  ),
  (
    'angel',
    'Serra Angel',
    'Creature — Angel',
    'Flying, vigilance',
    5,
    '{3}{W}{W}',
    '0.30',
    1,
  ),
  (
    'tower',
    'Command Tower',
    'Land',
    '{T}: Add one mana of any color.',
    0,
    '',
    '1.00',
    1,
  ),
  (
    'forest',
    'Forest',
    'Basic Land — Forest',
    '{T}: Add {G}.',
    0,
    '',
    '0.05',
    8,
  ),
  (
    'plains',
    'Plains',
    'Basic Land — Plains',
    '{T}: Add {W}.',
    0,
    '',
    '0.05',
    6,
  ),
  (
    'top',
    "Sensei's Divining Top",
    'Artifact',
    'Look at the top three cards of your library.',
    1,
    '{1}',
    '3.00',
    1,
  ),
  (
    'cmdr',
    'Atraxa, Praetors Voice',
    'Legendary Creature — Phyrexian Angel Horror',
    'Flying, vigilance, deathtouch, lifelink',
    4,
    '{G}{W}{U}{B}',
    '12.00',
    1,
  ),
  (
    'cmdr2',
    'Thrasios, Triton Hero',
    'Legendary Creature — Merfolk Wizard',
    'Partner',
    2,
    '{G}{U}',
    '1.00',
    1,
  ),
];

Map<String, dynamic> _json(_Fixture f) => {
  'id': f.$1,
  'name': f.$2,
  'type_line': f.$3,
  'oracle_text': f.$4,
  'cmc': f.$5,
  'mana_cost': f.$6,
  'prices': {'eur': f.$7},
  'color_identity': ['G', 'W'],
};

/// Scryfall hors ligne : renvoie les donnees des cartes du jeu d'essai, mais
/// aucune image (le reseau est coupe, les arts retombent sur leurs replis).
class _FakeApi extends ScryfallApiService {
  @override
  Future<Map<String, dynamic>> fetchCollection(
    List<Map<String, dynamic>> identifiers,
  ) async => {'data': _fixtures.map(_json).toList()};
}

// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  late AppDatabase db;

  Future<void> seed({
    String? commander,
    String? partner,
    DeckGrouping? grouping,
  }) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertDeck(
      DecksCompanion.insert(
        id: 'd1',
        name: 'Atraxa Superfriends',
        colors: const Value('["G","W","U","B"]'),
      ),
    );
    for (final f in _fixtures.where((f) => !f.$1.startsWith('cmdr'))) {
      // Une carte corrigee a la main : une creature taguee « Pioche ».
      final locked = f.$1 == 'witness';
      await db.upsertDeckCard(
        deckId: 'd1',
        board: 'main',
        scryfallId: f.$1,
        cardName: f.$2,
        quantityToAdd: f.$8,
        newTags: locked ? const ['Pioche'] : null,
        tagsEdited: locked ? true : null,
      );
    }
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'side',
      scryfallId: 'top',
      cardName: "Sensei's Divining Top",
      quantityToAdd: 1,
    );
    for (final id in ['elf', 'angel', 'tutor', 'signet']) {
      await db.upsertDeckCard(
        deckId: 'd1',
        board: 'considering',
        scryfallId: id,
        cardName: id,
        quantityToAdd: 1,
      );
    }
    for (final id in ['sol', 'rhystic']) {
      await db.upsertDeckCard(
        deckId: 'd1',
        board: 'wishlist',
        scryfallId: id,
        cardName: id,
        quantityToAdd: 1,
      );
    }
    final service = DeckService(database: db);
    if (commander != null) await service.setCommander('d1', commander);
    if (partner != null) await service.setCommander('d1', partner, slot: 2);
    if (grouping != null) {
      await saveDeckViewPrefs(db, 'd1', DeckViewPrefs(grouping: grouping));
    }
  }

  Future<void> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final deck = (await DeckService(
      database: db,
    ).loadDecks()).firstWhere((d) => d.id == 'd1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          scryfallApiServiceProvider.overrideWithValue(_FakeApi()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: DeckDetailPage(deck: deck),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const sizes = {'840': Size(840, 700), '390': Size(390, 844)};

  group('Captures -- bandeau de la page d\'un deck', () {
    final states = <String, ({String? cmd, String? partner})>{
      'un_commandant': (cmd: 'cmdr', partner: null),
      'partenaire': (cmd: 'cmdr', partner: 'cmdr2'),
      'sans_commandant': (cmd: null, partner: null),
    };
    for (final state in states.entries) {
      for (final size in sizes.entries) {
        testWidgets('bandeau ${state.key} a ${size.key}', (tester) async {
          await _runGuarded(() async {
            await seed(
              commander: state.value.cmd,
              partner: state.value.partner,
            );
            await mount(tester, size.value);
          });
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(DeckCommanderHeader)).height,
            DeckCommanderHeader.height,
          );
          // Le bandeau vit maintenant dans le viewport du NestedScrollView,
          // qui a sa propre frontiere de peinture (fond transparent) : on
          // capture la page entiere, comme le faisaient ces PNG avant.
          await expectLater(
            find.byType(DeckDetailPage),
            matchesGoldenFile(
              'goldens/deck_page_bandeau_${state.key}_${size.key}.png',
            ),
          );
        });
      }
    }
  });

  group('Captures -- onglet Liste de la page d\'un deck', () {
    for (final size in sizes.entries) {
      testWidgets('grille par categorie defilee a ${size.key}', (tester) async {
        await _runGuarded(() async {
          await seed(commander: 'cmdr', grouping: DeckGrouping.tag);
          await mount(tester, size.value);
          // Le haut de page est deja montre par les captures du bandeau :
          // on descend pour voir plusieurs categories et la carte verrouillee.
          await tester.drag(
            find.text('RAMP'),
            Offset(0, size.key == '840' ? -330 : -520),
          );
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        });
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/deck_page_grille_defilee_${size.key}.png'),
        );
      });

      testWidgets('liste compacte a ${size.key}', (tester) async {
        await _runGuarded(() async {
          await seed(commander: 'cmdr');
          await mount(tester, size.value);
          await tester.tap(find.byIcon(Icons.view_list));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        });
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/deck_page_liste_compacte_${size.key}.png'),
        );
      });
    }

    testWidgets('bandeau sorti apres un defilement a 390', (tester) async {
      await _runGuarded(() async {
        await seed(commander: 'cmdr');
        await mount(tester, sizes['390']!);
        // Juste assez pour sortir le bandeau (180 px) : la liste, elle,
        // repart presque de son debut.
        await tester.drag(
          find.textContaining('Créatures (').first,
          const Offset(0, -200),
          warnIfMissed: false,
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
      expect(tester.takeException(), isNull);
      expect(find.byType(DeckCommanderHeader).hitTestable(), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/deck_page_liste_bandeau_sorti_390.png'),
      );
    });
  });
}
