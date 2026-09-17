// test/captures/identite_tirage_langue_captures_test.dart
//
// Captures visuelles bloquantes du chantier "identite de tirage et langue
// d'affichage" (dix taches, voir
// .superpowers/sdd/2026-09-17-identite-tirage-langue/progress.md). Sa spec
// fait de la validation visuelle une porte bloquante : les tests de widgets
// (`test/widgets/decks/deck_card_title_test.dart`) mesurent des contraintes
// (maxLines, hauteur constante, presence du texte) -- ils ne disent rien de
// la lisibilite reelle. Ce fichier ne verifie rien par assertion : il rend
// ces cinq ecrans en PNG reel via `matchesGoldenFile`, pour qu'un humain les
// regarde avant merge. Modele suivi a la lettre :
// `test/captures/life_counter_captures_test.dart` -- lire son commentaire de
// fichier pour le detail de chaque mecanisme repris ici.
//
// Tag `capture` (voir dart_test.yaml) : ces PNG dependent du rendu de police
// de la machine qui les produit, donc `flutter test` seul (CI) les ignore.
// Pour les (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/identite_tirage_langue_captures_test.dart
//
// `--run-skipped` est necessaire EN PLUS de `--tags capture` : la config
// `skip:` de dart_test.yaml s'applique meme quand le tag est explicitement
// selectionne -- voir le commentaire de fichier du modele pour le detail.
//
// Polices reelles (voir `_loadSystemFont` / `setUpAll`, copiees telles
// quelles depuis le modele) : le binding de test headless de cette machine
// ne rend AUCUN glyphe reel par defaut -- on charge donc de vraies polices
// systeme sur disque (Segoe UI, Segoe UI Emoji, MaterialIcons du SDK
// Flutter) sous les noms de famille attendus par le rendu ('Roboto' --
// repli Flutter par defaut et style des badges/prix/tags de ce chantier,
// 'Cinzel_700'/'Cinzel_regular' -- les deux poids de `AppTextStyles`
// reellement utilises par `DeckCardTile` et `VersionsSelectorSheet`, voir
// le detail sous chaque style dans ces deux fichiers). Aucune police n'est
// copiee dans le depot, aucune dependance n'est ajoutee au pubspec.
//
// Reseau : `VersionsSelectorSheet` (capture 14) appelle
// `ScryfallApiService.searchCards` via Dio pour lister les tirages d'une
// carte. Pas de nouvelle dependance pour le simuler : `HttpClientAdapter`
// est deja expose par le paquet `dio` (dependance existante) -- voir
// `_CannedJsonAdapter` plus bas, qui repond un JSON fabrique a la main sans
// jamais toucher le reseau, pour que cette capture soit deterministe et ne
// depende pas d'un acces internet au moment de la (re)generation.
@Tags(['capture'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/providers/card_display_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/widgets/cards/versions_selector_sheet.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';

// ============================================================
// Fixtures -- cartes reelles (voir le brief de tache), pas des noms
// inventes : une capture qui ne montre pas une identite reelle ne prouve
// rien sur la lisibilite en conditions reelles.
// ============================================================

DeckCard _solRing() =>
    DeckCard(scryfallId: 'ltc-284', name: 'Sol Ring', quantity: 1);
DeckCard _thrill() => DeckCard(
    scryfallId: 'eld-146', name: 'Thrill of Possibility', quantity: 1);
DeckCard _cultivate() =>
    DeckCard(scryfallId: 'm21-177', name: 'Cultivate', quantity: 1);
DeckCard _counterspell() =>
    DeckCard(scryfallId: 'mh2-267', name: 'Counterspell', quantity: 1);

/// BRO 237 -- nom francais anormalement long (raison du choix par le brief) :
/// c'est la capture qui juge a l'oeil la troncature sur une ligne.
DeckCard _liberateur() => DeckCard(
    scryfallId: 'bro-237',
    name: "Liberator, Urza's Battle Thopter",
    quantity: 1);

/// SLD 141 -- Secret Lair jamais imprime en francais : cas reel de repli
/// (pas un cas fabrique), voir le brief de tache.
DeckCard _dreadbore() =>
    DeckCard(scryfallId: 'sld-141', name: 'Dreadbore', quantity: 1);

const _frSolRing =
    CardDisplay(name: 'Anneau solaire', lang: 'fr', isFallback: false);
const _frThrill = CardDisplay(
    name: 'Frisson de probabilité', lang: 'fr', isFallback: false);
const _frCultivate =
    CardDisplay(name: 'Culture', lang: 'fr', isFallback: false);
const _frCounterspell =
    CardDisplay(name: 'Contresort', lang: 'fr', isFallback: false);
const _frLiberateur = CardDisplay(
  name: "Libérateur, mécanoptère de combat d'Urza",
  lang: 'fr',
  isFallback: false,
);
const _enDreadboreFallback =
    CardDisplay(name: 'Dreadbore', lang: 'en', isFallback: true);

/// Oracle id fictif -- constant entre les 11 tirages fabriques pour la
/// capture 14, comme le serait un vrai oracle id Scryfall pour tous les
/// tirages d'une meme carte.
const _thrillOracleId = 'fixture-oracle-thrill-of-possibility';

/// Les 11 langues dans lesquelles Scryfall repertorie effectivement
/// "Thrill of Possibility" (voir le brief de tache) -- l'ordre est celui du
/// brief, pas un tri alphabetique, pour rester tracable a la demande.
const _thrillLangs = [
  'en',
  'de',
  'es',
  'fr',
  'it',
  'ja',
  'ko',
  'pt',
  'ru',
  'zhs',
  'zht',
];

/// JSON Scryfall minimal (mais valide pour `ScryfallCard.fromJson`) pour un
/// tirage de "Thrill of Possibility" dans [lang]. Pas de `image_uris` --
/// volontaire : `imageUrl`/`smallImageUrl` restent vides, `Image.network('')`
/// echoue immediatement sur son `errorBuilder` (icone de repli) plutot que de
/// dependre d'un acces reseau reel pendant la capture.
Map<String, dynamic> _thrillVersionJson(String lang) => {
      'id': 'fixture-thrill-$lang',
      'oracle_id': _thrillOracleId,
      'name': 'Thrill of Possibility',
      'lang': lang,
      'set_name': 'Throne of Eldraine',
      'set': 'eld',
      'collector_number': '146',
      'rarity': 'common',
      'type_line': 'Sorcery',
      'mana_cost': '{1}{R}',
      'prices': {'eur': '0.10', 'usd': '0.15'},
      'legalities': <String, dynamic>{},
      'purchase_uris': <String, dynamic>{},
      'color_identity': ['R'],
    };

// ============================================================
// Reseau fabrique pour la capture 14 -- voir le commentaire de fichier.
// ============================================================

/// Repond toujours le meme JSON, quelle que soit l'URI demandee : suffisant
/// ici puisque `VersionsSelectorSheet` ne fait qu'un seul appel
/// (`GET /cards/search?...`) pendant son cycle de vie.
class _CannedJsonAdapter implements HttpClientAdapter {
  _CannedJsonAdapter(this._json);

  final String _json;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      _json,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ScryfallApiService _fakeThrillApiService() {
  final json = jsonEncode({
    'data': _thrillLangs.map(_thrillVersionJson).toList(),
    'has_more': false,
  });
  final dio = Dio()..httpClientAdapter = _CannedJsonAdapter(json);
  return ScryfallApiService(dio: dio);
}

// ============================================================
// Theme + polices reelles -- copie fidele du mecanisme de
// `life_counter_captures_test.dart` (voir son commentaire de fichier pour
// le detail de chaque trouvaille). Seuls les noms de familles composees
// changent, pour matcher les poids reellement utilises par ce chantier
// (voir le commentaire de fichier ci-dessus).
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

/// Charge les polices reelles necessaires a ces captures : `AppTextStyles`
/// n'utilise ici que deux poids de Cinzel -- w700 (`fontWeight: bold`, ex.
/// `DeckCardTile` quantite/`VersionsSelectorSheet` titre) et w400/regular
/// (nom de carte sans poids explicite) -- identifies en imprimant
/// `.fontFamily` comme documente dans le modele. Segoe UI (texte) et Segoe
/// UI Emoji (aucun emoji dans ces ecrans, charge quand meme par coherence
/// avec le mecanisme du modele et gratuit) sous les DEUX noms composes.
Future<void> _loadRealFontsForCaptures() async {
  final textStack = [
    '$_windowsFontsDir\\seguiemj.ttf',
    '$_windowsFontsDir\\segoeui.ttf',
  ];
  await _loadSystemFont('Roboto', textStack);
  await _loadSystemFont('Cinzel_700', textStack); // fontWeight: FontWeight.bold
  await _loadSystemFont('Cinzel_regular', textStack); // sans fontWeight explicite

  // Bonus, comme dans le modele : icones Material (check_circle, star,
  // more_vert, close, image_not_supported) sinon en tofu.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final materialIconsPath =
        '$flutterRoot\\bin\\cache\\artifacts\\material_fonts\\MaterialIcons-Regular.otf';
    if (File(materialIconsPath).existsSync()) {
      await _loadSystemFont('MaterialIcons', [materialIconsPath]);
    }
  }
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

/// Une liste de deck (vraie `DeckCardTile`, pas une reconstitution) sur un
/// ecran de taille telephone portrait -- le meme gabarit que
/// `deck_card_list_tab.dart` rend en usage reel.
Widget _deckList(List<Widget> tiles) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _appTheme(),
      home: Scaffold(
        body: SafeArea(
          child: ListView(children: tiles),
        ),
      ),
    );

Widget _tile(DeckCard card, {CardDisplay? display}) => DeckCardTile(
      card: card,
      scryfallCard: null,
      isInCollection: false,
      display: display,
      onMore: () {},
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  group('Captures -- identite de tirage et langue d\'affichage', () {
    testWidgets(
        '10 - liste de deck avant projection : noms anglais du tirage possede',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(_deckList([
          _tile(_solRing()),
          _tile(_thrill()),
          _tile(_cultivate()),
          _tile(_counterspell()),
        ]));
        await tester.pumpAndSettle();
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/10_liste_deck_anglais.png'),
      );
    });

    testWidgets(
        '11 - meme liste, projections arrivees : noms francais -- preuve du but atteint',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(_deckList([
          _tile(_solRing(), display: _frSolRing),
          _tile(_thrill(), display: _frThrill),
          _tile(_cultivate(), display: _frCultivate),
          _tile(_counterspell(), display: _frCounterspell),
        ]));
        await tester.pumpAndSettle();
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/11_liste_deck_francais.png'),
      );
    });

    testWidgets(
        '12 - meme liste + nom francais trop long : troncature une ligne, hauteur constante',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(_deckList([
          _tile(_solRing(), display: _frSolRing),
          _tile(_thrill(), display: _frThrill),
          _tile(_cultivate(), display: _frCultivate),
          _tile(_counterspell(), display: _frCounterspell),
          _tile(_liberateur(), display: _frLiberateur),
        ]));
        await tester.pumpAndSettle();
      });

      // Pas d'exception de debordement (RenderFlex) : pumpAndSettle
      // leverait sinon -- la meme garantie que
      // `deck_card_title_test.dart:141`, mais ici sur l'ecran entier.
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/12_nom_long_tronque.png'),
      );
    });

    testWidgets(
        '13 - meme liste + carte sans VF : badge ambre de repli lisible, sans debordement',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(_deckList([
          _tile(_solRing(), display: _frSolRing),
          _tile(_thrill(), display: _frThrill),
          _tile(_cultivate(), display: _frCultivate),
          _tile(_counterspell(), display: _frCounterspell),
          _tile(_dreadbore(), display: _enDreadboreFallback),
        ]));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/13_badge_repli.png'),
      );
    });

    testWidgets(
        '14 - selecteur de versions : une meme carte en onze langues Scryfall',
        (tester) async {
      // Fenetre nettement plus haute qu'un telephone reel : le sheet occupe
      // 85% de la hauteur d'ecran (`VersionsSelectorSheet` -- voir son
      // `Container(height: ... * 0.85)`) et sa `GridView` (2 colonnes,
      // `childAspectRatio: 0.65`) a besoin d'environ 6 rangees pour montrer
      // les 11 tirages fabriques sans scroll. A 844 de haut (gabarit
      // telephone des autres captures), seules 4 des 11 langues restent
      // visibles avant que le reste ne soit coupe par le bord du sheet --
      // verifie en le regardant. Ici on privilegie montrer les onze langues
      // en un seul PNG (le but de cette capture) plutot que la fidelite au
      // gabarit telephone.
      _setSurfaceSize(tester, const Size(390, 2200));

      await _runGuarded(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scryfallApiServiceProvider.overrideWithValue(
                _fakeThrillApiService(),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _appTheme(),
              home: Scaffold(
                body: VersionsSelectorSheet(
                  oracleId: _thrillOracleId,
                  currentCardId: 'fixture-thrill-en',
                  onVersionSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/14_selecteur_versions_multilingue.png'),
      );
    });
  });
}
