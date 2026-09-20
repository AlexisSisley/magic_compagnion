// test/captures/grimoire_captures_test.dart
//
// Captures visuelles bloquantes du lot B (palette Grimoire + typographie),
// voir docs/superpowers/plans/2026-09-19-refonte-nav-da.md, Task 5. Ce
// fichier ne verifie presque rien par assertion : il rend ces cinq ecrans en
// PNG reel via `matchesGoldenFile`, pour qu'un humain les regarde avant de
// passer au lot C -- un test de widget mesure des contraintes, il ne dit rien
// de la lisibilite.
//
// Tag `capture` (voir dart_test.yaml) : ces PNG dependent du rendu de police
// de la machine qui les produit, donc `flutter test` seul (CI) les ignore.
// Pour les (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/grimoire_captures_test.dart
//
// Polices reelles : meme mecanisme que life_counter_captures_test.dart, dont
// le commentaire de fichier explique en detail pourquoi il faut lire de
// vraies polices systeme et les enregistrer sous le nom COMPOSE que
// google_fonts attend (`Cinzel_700`, jamais `Cinzel`). Le lot B ajoute Source
// Sans 3 au texte courant : ses familles composees sont donc enregistrees ici
// a cote de celles de Cinzel. Les noms ont ete releves en imprimant
// `.fontFamily` de chaque helper d'AppTextStyles -- les deviner ne marche
// pas, et une famille manquante rend du tofu en silence.
@Tags(['capture'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/widgets/cards/card_detail_info_sections.dart';
import 'package:magic_companion/widgets/decks/deck_list_card.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/theme/magic_palette.dart';

// ---------------------------------------------------------------------------
// Preambule de polices -- repris de life_counter_captures_test.dart.
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

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  Widget harness(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      );

  group('Captures -- palette et typographie Grimoire', () {
    testWidgets('20 - echelle des surfaces et des encres', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(harness(Builder(builder: (context) {
          final p = MagicPalette.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in {
                'canvas': p.canvas,
                'raised': p.raised,
                'overlay': p.overlay,
                'line': p.line,
              }.entries)
                Container(
                  height: 60,
                  color: entry.value,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      Text(entry.key, style: AppTextStyles.text(fontSize: 14)),
                ),
            ],
          );
        })));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/20_grimoire_surfaces.png'));
    });

    testWidgets('21 - semantique contre couleurs de mana', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(harness(Builder(builder: (context) {
          final p = MagicPalette.of(context);
          return ColoredBox(
            color: p.canvas,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final c in [p.success, p.warning, p.danger, p.info])
                      CircleAvatar(backgroundColor: c, radius: 22),
                  ],
                ),
                const SizedBox(height: 24),
                Text('feedback', style: AppTextStyles.text(fontSize: 13)),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final c in [
                      AppColors.manaWhite,
                      AppColors.manaBlue,
                      AppColors.manaBlack,
                      AppColors.manaRed,
                      AppColors.manaGreen,
                    ])
                      CircleAvatar(backgroundColor: c, radius: 22),
                  ],
                ),
                const SizedBox(height: 24),
                Text('mana', style: AppTextStyles.text(fontSize: 13)),
              ],
            ),
          );
        })));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/21_grimoire_semantique_vs_mana.png'));
    });

    testWidgets('22 - echelle typographique complete', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(harness(Builder(builder: (context) {
          final p = MagicPalette.of(context);
          return ColoredBox(
            color: p.canvas,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Titre de page', style: AppTextStyles.pageTitle()),
                  Text('Titre de section', style: AppTextStyles.sectionTitle()),
                  Text('Titre de carte', style: AppTextStyles.cardTitle()),
                  const SizedBox(height: 20),
                  Text(
                      'Sol Ring est un artefact incolore qui produit deux manas '
                      'incolores. Il est banni en Legacy et restreint en Vintage.',
                      style: AppTextStyles.body()),
                  const SizedBox(height: 12),
                  Text('Sous-titre', style: AppTextStyles.subtitle()),
                  Text('Label 12px', style: AppTextStyles.label()),
                  Text('Texte bold', style: AppTextStyles.bold()),
                ],
              ),
            ),
          );
        })));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/22_grimoire_typographie.png'));
    });
  });

  // -------------------------------------------------------------------------
  // Deux captures sur de VRAIS widgets de l'app.
  //
  // Les trois ci-dessus sont des specimens : elles montrent la palette et
  // l'echelle typographique, pas l'app. Or la Task 4 a modifie 59 fichiers par
  // un `sed` aveugle, dont 52 n'ont aucun test, et aucun des 1349 tests du
  // depot ne regarde une police. Ce sont celles-ci qui diront si la migration
  // a casse une mise en page : un texte qui passe de Cinzel a Source Sans 3
  // change de largeur, et un libelle qui tenait sur une ligne peut deborder.
  //
  // Ce sont les WIDGETS qui sont montes, pas les pages entieres. `DeckListPage`
  // et `CollectionPage` ne sont pas montables dans une capture : leurs
  // controllers attendent `LocalCardService.loadLocalData()`, qui lit
  // `assets/json/oracle-cards.json` (166 Mo) et le parse via `compute()` --
  // un isolate qui ne rend jamais la main sous le binding de test. Le service
  // est un singleton a constructeur prive, donc non surchargeable. Verifie :
  // la page reste sur son indicateur de chargement indefiniment. C'est la
  // meme approche que les trois fichiers de capture existants du depot, qui
  // rendent `DeckCardTile` ou `MoxfieldImportSheet`, jamais une page complete.
  // -------------------------------------------------------------------------

  group('Captures -- widgets reels apres migration typographique', () {
    // Ni commandant ni couleurs, et ce n'est pas un appauvrissement gratuit :
    // les deux font partir une requete reseau que le binding de test ne peut
    // pas satisfaire. La vignette de commandant est un `ScryfallImage`
    // (illustration distante), et chaque pastille de couleur est un SVG de
    // symbole de mana charge depuis Scryfall -- celui-ci echoue en
    // "Bad state: Invalid SVG data" et interrompt `pumpWidget`. Ce que cette
    // capture regarde est le TEXTE (nom, format, compte, prix), c'est-a-dire
    // ce que la migration typographique a deplace.
    Deck deck(String name, String format, List<String> colors) => Deck(
          id: name,
          name: name,
          format: format,
          colors: colors,
        );

    testWidgets('23 - tuiles de liste de decks', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      final decks = [
        deck('Atraxa Superfriends', 'Commander', const []),
        deck('Burn Mono-Rouge', 'Modern', const []),
        deck('Azorius Controle Tempo Moderne Edition Longue', 'Standard',
            const []),
        deck('Elfes', 'Legacy', const []),
      ];

      await _runGuarded(() async {
        await tester.pumpWidget(harness(Builder(builder: (context) {
          final p = MagicPalette.of(context);
          return ColoredBox(
            color: p.canvas,
            child: ListView(
              children: [
                for (final d in decks)
                  DeckListCard(
                    key: ValueKey(d.id),
                    deck: d,
                    totalPrice: 142.5,
                    onTap: () {},
                    confirmDismiss: (_) async => false,
                    onDismissed: () {},
                  ),
              ],
            ),
          );
        })));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      // Preuve de non-vacuite : sans elle, une capture vide passerait pour un
      // succes.
      expect(find.textContaining('Atraxa', findRichText: true), findsWidgets);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/23_grimoire_deck_list.png'));
    });

    testWidgets('24 - fiche carte : texte de regles, legalites, prix',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(harness(Builder(builder: (context) {
          final p = MagicPalette.of(context);
          return ColoredBox(
            color: p.canvas,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Sol Ring', style: AppTextStyles.pageTitle()),
                const SizedBox(height: 4),
                Text('Artefact — Legendaire', style: AppTextStyles.subtitle()),
                const SizedBox(height: 12),
                CardDetailInfoCard(
                  title: 'Texte de regles',
                  child: Text(
                    '{T} : Ajoutez {C}{C}.\n\n'
                    "Sol Ring est l'artefact le plus joue du format Commander. "
                    'Il est banni en Legacy et restreint en Vintage, ce qui en '
                    "fait l'une des rares cartes a subir les deux sanctions.",
                    style: AppTextStyles.body(),
                  ),
                ),
                const SizedBox(height: 12),
                const CardDetailLegalities(legalities: {
                  'standard': 'not_legal',
                  'modern': 'not_legal',
                  'legacy': 'banned',
                  'vintage': 'restricted',
                  'commander': 'legal',
                  'pauper': 'not_legal',
                }),
                const SizedBox(height: 12),
                const CardDetailPriceInfo(prices: {
                  'eur': '1.49',
                  'eur_foil': '12.80',
                  'usd': '1.62',
                  'usd_foil': '14.20',
                }),
              ],
            ),
          );
        })));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Sol Ring', findRichText: true), findsWidgets);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/24_grimoire_fiche_carte.png'));
    });
  });
}
