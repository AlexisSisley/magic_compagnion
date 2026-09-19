// Fichier : lib/main.dart
//
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣴⣶⣶⣶⣶⣴⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⣠⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣄⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀
// ⠀⠀⠀⣼⣿⣿⣿⣿⣿⡟⠁⠀⣠⣤⣤⣤⣤⣄⠀⠈⢻⣿⣿⣿⣿⣿⣧⠀⠀⠀
// ⠀⠀⢸⣿⣿⣿⣿⣿⡟⠀⠀⣼⣿⣿⣿⣿⣿⣿⣧⠀⠀⢻⣿⣿⣿⣿⣿⡇⠀⠀
// ⠀⠀⢸⣿⣿⣿⣿⣿⡇⠀⠀⠈⠛⠿⣿⣿⠿⠛⠁⠀⠀⢸⣿⣿⣿⣿⣿⡇⠀⠀
// ⠀⠀⠀⢿⣿⣿⣿⣿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⡿⠀⠀⠀
// ⠀⠀⠀⠀⠻⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⠟⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣶⣤⣀⣀⣤⣶⣿⣿⣿⣿⣿⠟⠁⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠈⠛⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠛⠁⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠛⠛⠛⠛⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//
// If you're reading this, you've gone too deep into the Grand Line.
// Turn back now... or join the crew.
// "Wealth, fame, power. The man who had everything in this world...
//  The Pirate King, Gold Roger."
// The One Piece is Real.
//

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'providers/service_providers.dart';
import 'data/database/app_database.dart';
import 'data/migration/migration_service.dart';
import 'router/app_router.dart';
import 'services/card_resolver.dart';
import 'services/print_backfill_service.dart';
import 'services/scryfall_api_service.dart';
import 'services/translation_worker.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Egg: Jolly Roger console art (debug only) ---
  assert(() {
    debugPrint('');
    debugPrint('  ╔══════════════════════════════════════╗');
    debugPrint('  ║  ☠  MUGIWARA COMPANION ENGINE  ☠    ║');
    debugPrint('  ║                                      ║');
    debugPrint('  ║  "The One Piece... is REAL!"         ║');
    debugPrint('  ║         — Edward Newgate              ║');
    debugPrint('  ╚══════════════════════════════════════╝');
    debugPrint('');
    return true;
  }());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('fr_FR');

  // Migration transparente SharedPreferences -> drift (Sprint 4)
  final db = AppDatabase();
  final migrationService = MigrationService(db);
  await migrationService.migrateIfNeeded();

  // Reprise de l'existant (identite de tirage) : met en cache le tirage des
  // cartes deja stockees (deck + collection), pour que la projection
  // d'affichage dispose d'un oracleId meme pour ce qui a ete importe avant
  // ce lot. Lancee sans `await` : ne doit jamais retarder le premier
  // affichage. `runOnce` est protegee par un drapeau AppSettings et ne pose
  // ce drapeau qu'en cas de succes -- une panne (pas de reseau au premier
  // lancement, etc.) sera retentee au prochain demarrage plutot que perdue.
  //
  // UNE SEULE instance de ScryfallApiService pour toute l'application : le
  // limiteur 10 req/s est un champ d'INSTANCE. Construire ici un
  // `ScryfallApiService()` neuf, distinct du singleton de
  // `scryfallApiServiceProvider`, donnait au backfill son propre quota --
  // jusqu'a 20 req/s au premier lancement apres mise a jour, precisement
  // quand le backfill est le plus gros. Scryfall repond 429, le drapeau ne se
  // pose pas, et tout recommence au lancement suivant. L'instance (et le
  // resolveur qui la porte) est donc construite une fois et injectee dans le
  // ProviderScope : backfill, worker de traduction et interface partagent le
  // meme limiteur.
  final api = ScryfallApiService();
  final resolver = CardResolver(api: api, db: db);

  final printBackfillService = PrintBackfillService(
    db: db,
    resolver: resolver,
  );
  unawaited(printBackfillService.runOnce());

  // Reprise de la file de traduction : la spec promet qu'« une importation
  // interrompue reprend au lancement suivant ». Sans ce drain au demarrage,
  // les taches enfilees par un import (ou un scan) que l'utilisateur n'a pas
  // suivi d'un passage par le glossaire ne partaient jamais. Sans `await`,
  // comme le backfill : le premier affichage ne l'attend pas.
  final translationWorker = TranslationWorker(resolver: resolver, db: db);
  unawaited(translationWorker.drain());

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        scryfallApiServiceProvider.overrideWithValue(api),
        cardResolverProvider.overrideWithValue(resolver),
        translationWorkerProvider.overrideWithValue(translationWorker),
      ],
      child: MagicCompanionApp(),
    ),
  );
}

class MagicCompanionApp extends StatelessWidget {
  MagicCompanionApp({super.key});

  /// Router cree une seule fois (et non a chaque rebuild de build()).
  /// Fix US-14.5 : evite de recreer le GoRouter a chaque rebuild,
  /// ce qui causait des pertes de state de navigation.
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Magic Companion',
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
      theme: buildAppTheme(),
    );
  }
}
