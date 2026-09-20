// test/captures/navigation_captures_test.dart
//
// Captures visuelles bloquantes du lot E (navigation), voir
// docs/superpowers/plans/2026-09-19-refonte-nav-da.md, Task 17.
//
// Tag `capture` (voir dart_test.yaml) : ces PNG dependent du rendu de police
// de la machine qui les produit, donc `flutter test` seul (CI) les ignore.
// Pour les (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/navigation_captures_test.dart
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
import 'package:magic_companion/pages/onboarding/onboarding_page.dart';
import 'package:magic_companion/pages/settings/settings_page.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Absorbe la Future orpheline de `googleFontsTextStyle` : coupee par
/// `allowRuntimeFetching = false`, elle est rejetee mais pas avalee.
///
/// La zone n'enveloppe QUE le montage, jamais les `expect` : une zone avale
/// ce qui leve a l'interieur, et une assertion qui echoue y passerait pour un
/// succes.
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

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({kHasSeenOnboarding: true});
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// Ni `pumpAndSettle` (le shimmer du tableau de bord boucle sans fin) ni
  /// `runAsync` (qui reveillerait le telechargement de polices).
  Future<void> pompe(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('Captures -- navigation', () {
    // Prechauffage, sans golden. La texture de fond du shell est une
    // AssetImage : son decodage est asynchrone, et la PREMIERE capture d'un
    // fichier la rend avant qu'elle soit prete -- fond blanc, titre
    // illisible. On prendrait l'artefact pour un defaut de DA. Un montage
    // jete d'avance amorce le cache d'images pour les captures qui suivent.
    testWidgets("00 - prechauffage du cache d'images", (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));
      await _runGuarded(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: createAppRouter(),
          ),
        ));
        await pompe(tester);
      });
    });

    // Montees sur le VRAI routeur, pas sur HomePage seule : le shell porte
    // le fond texture et la barre d'onglets. Isolee, la page se rend sur du
    // blanc et son titre devient illisible -- un artefact de montage qu'on
    // prendrait pour un defaut de DA.
    testWidgets('40 - Accueil, sans partie en cours', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeGameProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          routerConfig: createAppRouter(),
        ),
      ));
        await pompe(tester);
      });

      expect(find.text('Lancer une partie'), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/40_nav_accueil.png'));
    });

    testWidgets('41 - Accueil, avec une partie a reprendre', (tester) async {
      _setSurfaceSize(tester, const Size(390, 844));

      await _runGuarded(() async {
        await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeGameProvider.overrideWith((ref) async => buildTestSession()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          routerConfig: createAppRouter(),
        ),
      ));
        await pompe(tester);
      });

      expect(find.text('Reprendre la partie'), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/41_nav_accueil_reprise.png'));
    });

    testWidgets("42 - barre d'onglets du shell, cinq libelles", (tester) async {
      // Montee sur le VRAI routeur : c'est la barre que l'app affiche, pas
      // une reconstitution. Surface courte pour que la barre occupe l'image.
      _setSurfaceSize(tester, const Size(390, 320));

      await _runGuarded(() async {
        await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          routerConfig: createAppRouter(),
        ),
      ));
        await pompe(tester);
      });

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/42_nav_barre_onglets.png'));
    });

    testWidgets('43 - Reglages, ses sections deroulees', (tester) async {
      // Haute exprès : la page est une ListView, et un gabarit telephone ne
      // construirait que ce qui tient a l'ecran.
      _setSurfaceSize(tester, const Size(390, 1600));

      await _runGuarded(() async {
        await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const SettingsPage(),
        ),
      ));
        await pompe(tester);
      });

      expect(find.text('SAUVEGARDE'), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/43_nav_reglages.png'));
    });
  });
}
