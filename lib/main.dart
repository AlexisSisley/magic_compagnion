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

import 'package:magic_companion/theme/app_colors.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        appBarTheme:
            const AppBarTheme(backgroundColor: AppColors.textOnPrimary, elevation: 0),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.9),
          selectedItemColor: AppColors.primaryShade800,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
