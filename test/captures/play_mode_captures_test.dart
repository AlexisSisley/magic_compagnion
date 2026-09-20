// test/captures/play_mode_captures_test.dart
//
// Captures visuelles bloquantes du lot C (mode Jeu), voir
// docs/superpowers/plans/2026-09-19-refonte-nav-da.md, Task 9.
//
// Tag `capture` (voir dart_test.yaml) : ces PNG dependent du rendu de police
// de la machine qui les produit, donc `flutter test` seul (CI) les ignore.
// Pour les (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/play_mode_captures_test.dart
//
// Meme preambule de polices que grimoire_captures_test.dart : les familles
// sont enregistrees sous leur nom COMPOSE (`Cinzel_700`, `SourceSans3_700`),
// jamais sous le nom nu, sinon le texte rend en tofu sans rien signaler.
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
import 'package:magic_companion/pages/play/play_setup_page.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:magic_companion/router/play_shell.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/theme/magic_palette.dart';
import 'package:magic_companion/widgets/life_counter/game_setup_modal.dart';

import '../support/test_game_session.dart';

Future<void> _loadSystemFont(String family, List<String> absolutePaths) async {
  final loader = FontLoader(family);
  for (final absolutePath in absolutePaths) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      fail(
        'Police systeme introuvable : "$absolutePath" (attendue pour charger '
        'la famille "$family"). Sans elle, cette capture rendrait du texte en '
        'tofu illisible au lieu d\'echouer.',
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
    'SourceSans3_600',
    'SourceSans3_700',
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

/// Absorbe la Future orpheline de `googleFontsTextStyle` (chargement reseau
/// rejete), qui marquerait le test [E] malgre un rendu correct.
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

void main() {
  late AppDatabase db;

  setUp(() {
    // La feuille ouverte au montage lit les profils, donc la base. Sans
    // surcharge, chaque capture construirait une AppDatabase reelle.
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  group('Captures -- mode Jeu', () {
    testWidgets("30 - mise en place : la feuille s'ouvre au montage",
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            // SANS partie en cours : c'est la seule situation ou la feuille
            // s'ouvre d'elle-meme. Avec une partie, on arrive ici en SORTANT
            // du mode Jeu, et surgir "configurer une nouvelle partie" serait
            // l'inverse du geste.
            activeGameProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const PlaySetupPage(),
          ),
        ));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      // Non-vacuite : c'est bien la feuille de configuration qu'on capture,
      // pas la page nue derriere elle.
      expect(find.byType(GameSetupModal), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/30_play_setup.png'));
    });

    testWidgets('33 - mise en place : etat vide avec reprise possible',
        (tester) async {
      // L'autre moitie de l'ecran, et le cas le plus courant : on y arrive
      // en sortant d'une partie par "Fin". La feuille ne surgit pas, et
      // c'est ici que se juge si le bouton de reprise se distingue de celui
      // de configuration.
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeGameProvider.overrideWith((ref) async => buildTestSession()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const PlaySetupPage(),
          ),
        ));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      expect(find.text('Reprendre la partie en cours'), findsOneWidget);
      expect(find.text('Configurer la partie'), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/33_play_setup_etat_vide.png'));
    });

    testWidgets('31 - barre d\'outils de partie, outil Vies actif',
        (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: PlayShell(
            currentLocation: AppRoutes.playCounter,
            child: Builder(builder: (context) {
              final p = MagicPalette.of(context);
              // Le compteur reel n'est pas monte ici : il tire toute la chaine
              // de services de partie. Ce que cette capture regarde est la
              // BARRE, pas son contenu -- d'ou ce corps neutre, qui laisse
              // toute la place a ce qu'on veut juger.
              return ColoredBox(
                color: p.canvas,
                child: Center(
                  child: Text('contenu de la partie',
                      style: AppTextStyles.text(
                          color: p.inkMuted, fontSize: 13)),
                ),
              );
            }),
          ),
        ));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/31_play_barre_outils.png'));
    });

    testWidgets('32 - barre d\'outils, outil Oracle actif', (tester) async {
      // Meme barre, autre outil actif : c'est la seule facon de voir si
      // l'etat actif se distingue vraiment de l'etat inactif.
      _setSurfaceSize(tester, const Size(390, 300));

      await _runGuarded(() async {
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: PlayShell(
            currentLocation: AppRoutes.playOracle,
            child: const SizedBox.shrink(),
          ),
        ));
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/32_play_barre_outils_oracle.png'));
    });
  });
}
