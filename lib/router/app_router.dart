// Fichier : lib/router/app_router.dart
// Configuration centralisée go_router (Sprint 5)
// Toutes les routes de l'application sont définies ici.

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../chat_screen.dart';
import '../data/glossary_data.dart';
import '../models/deck_model.dart';
import '../models/game_history_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/scryfall_set_model.dart';
import '../models/wishlist_model.dart';
import '../pages/cards/card_detail_page.dart';
import '../pages/cards/card_search_page.dart';
import '../pages/collections/collection_page.dart';
import '../pages/collections/global_stats_page.dart';
import '../pages/collections/set_detail_page.dart';
import '../pages/collections/set_stats_page.dart';
import '../pages/decks/deck_detail_page.dart';
import '../pages/decks/deck_list_page.dart';
import '../pages/glossary/glossary_detail_page.dart';
import '../pages/glossary/glossary_page.dart';
import '../pages/glossary/turn_guide_page.dart';
import '../pages/life_counter/game_history_detail_page.dart';
import '../pages/life_counter/game_history_page.dart';
import '../pages/life_counter/life_counter_page.dart';
import '../pages/oracle/magic_oracle_page.dart';
import '../pages/scans/scan_history_page.dart';
import '../pages/scans/scanner_page.dart';
import '../pages/settings/profile_management_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/tools/hypergeometric_page.dart';
import '../pages/tournaments/tournament_page.dart';
import '../pages/wishlists/wishlist_detail_page.dart';
import '../providers/service_providers.dart';

/// Noms de routes pour navigation type-safe.
class AppRoutes {
  // Onglets principaux (shell)
  static const String lifeCounter = '/';
  static const String scanner = '/scanner';
  static const String search = '/search';
  static const String decks = '/decks';
  static const String collection = '/collection';

  // Drawer routes
  static const String gameHistory = '/game-history';
  static const String tournament = '/tournament';
  static const String oracle = '/oracle';
  static const String grimoire = '/grimoire';
  static const String calculator = '/calculator';
  static const String glossary = '/glossary';
  static const String turnGuide = '/glossary/turn-guide';
  static const String profiles = '/profiles';
  static const String settings = '/settings';

  // Detail routes (push par-dessus le shell)
  static const String cardDetail = '/cards/detail';
  static const String glossaryDetail = '/glossary/detail';
  static const String globalStats = '/collection/stats';
  static const String setDetail = '/collection/set';
  static const String setStats = '/collection/set/stats';
  static const String wishlistDetail = '/wishlists/detail';
  static const String deckDetail = '/decks/detail';
  static const String gameHistoryDetail = '/game-history/detail';
  static const String scanHistory = '/scanner/history';
}

/// Index des onglets dans le BottomNavigationBar.
int _locationToTabIndex(String location) {
  if (location.startsWith('/scanner')) return 1;
  if (location.startsWith('/search')) return 2;
  if (location.startsWith('/decks')) return 3;
  if (location.startsWith('/collection')) return 4;
  return 0;
}

/// Crée et configure le GoRouter de l'application.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.lifeCounter,
    debugLogDiagnostics: kDebugMode,
    routes: [
      // Shell route pour le BottomNavigationBar + Drawer
      ShellRoute(
        builder: (context, state, child) {
          return _AppShellScaffold(
            currentLocation: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LifeCounterPage(),
            ),
          ),
          GoRoute(
            path: '/scanner',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ScannerPage(),
            ),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CardSearchPage(),
            ),
          ),
          GoRoute(
            path: '/decks',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DeckListPage(),
            ),
          ),
          GoRoute(
            path: '/collection',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CollectionPage(),
            ),
          ),
        ],
      ),

      // Routes du Drawer (push par-dessus le shell)
      GoRoute(
        path: AppRoutes.gameHistory,
        builder: (context, state) => const GameHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.tournament,
        builder: (context, state) => TournamentPage(),
      ),
      GoRoute(
        path: AppRoutes.oracle,
        builder: (context, state) => const MagicOraclePage(),
      ),
      GoRoute(
        path: AppRoutes.grimoire,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.calculator,
        builder: (context, state) => const HypergeometricPage(),
      ),
      GoRoute(
        path: AppRoutes.glossary,
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text('Glossaire', style: GoogleFonts.cinzel())),
          backgroundColor: const Color(0xFF1A1A1A),
          body: const GlossaryPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.turnGuide,
        builder: (context, state) => const TurnGuidePage(),
      ),
      GoRoute(
        path: AppRoutes.profiles,
        builder: (context, state) => const ProfileManagementPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),

      // --- Routes de détail (push par-dessus le shell) ---
      GoRoute(
        path: AppRoutes.cardDetail,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RecognitionResultPage(
            cardName: extra?['cardName'] as String?,
            imagePath: extra?['imagePath'] as String?,
            isContinuousScan: extra?['isContinuousScan'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.glossaryDetail,
        builder: (context, state) {
          final keyword = state.extra as Keyword;
          return GlossaryDetailPage(keyword: keyword);
        },
      ),
      GoRoute(
        path: AppRoutes.globalStats,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return GlobalStatsPage(
            collection: extra['collection'] as List<DeckCard>,
            fullCardData: extra['fullCardData'] as List<ScryfallCard>,
            totalValue: extra['totalValue'] as double,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.setDetail,
        builder: (context, state) {
          final set = state.extra as ScryfallSet;
          return SetDetailPage(set: set);
        },
      ),
      GoRoute(
        path: AppRoutes.setStats,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return SetStatsPage(
            targetSet: extra['targetSet'] as ScryfallSet,
            myCollection: extra['myCollection'] as List<DeckCard>,
            fullSetData: extra['fullSetData'] as List<ScryfallCard>,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.wishlistDetail,
        builder: (context, state) {
          final wishlist = state.extra as Wishlist;
          return WishlistDetailPage(wishlist: wishlist);
        },
      ),
      GoRoute(
        path: AppRoutes.deckDetail,
        builder: (context, state) {
          final deck = state.extra as Deck;
          return DeckDetailPage(deck: deck);
        },
      ),
      GoRoute(
        path: AppRoutes.gameHistoryDetail,
        builder: (context, state) {
          final game = state.extra as GameHistoryItem;
          return GameHistoryDetailPage(game: game);
        },
      ),
      GoRoute(
        path: AppRoutes.scanHistory,
        builder: (context, state) => const ScanHistoryPage(),
      ),
    ],
  );
}

/// Shell scaffold avec BottomNavigationBar et Drawer.
/// Remplace l'ancien AppShell de main.dart.
class _AppShellScaffold extends ConsumerStatefulWidget {
  final String currentLocation;
  final Widget child;

  const _AppShellScaffold({
    required this.currentLocation,
    required this.child,
  });

  @override
  ConsumerState<_AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<_AppShellScaffold>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDriveBackupOnStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _performAutoBackup();
    }
  }

  Future<void> _performAutoBackup() async {
    final driveService = ref.read(googleDriveServiceProvider);
    final backupService = ref.read(backupServiceProvider);
    if (driveService.isSignedIn) {
      log('Début sauvegarde automatique Drive...', name: 'AppShell');
      final jsonString = await backupService.generateBackupJson();
      await driveService.uploadBackup(jsonString);
    }
  }

  Future<void> _checkDriveBackupOnStart() async {
    final driveService = ref.read(googleDriveServiceProvider);
    final backupService = ref.read(backupServiceProvider);
    final signedIn = await driveService.signIn(silent: true);

    if (signedIn) {
      final backupFile = await driveService.findBackupFile();

      if (backupFile != null && mounted) {
        String dateStr = 'Inconnue';
        if (backupFile.modifiedTime != null) {
          dateStr =
              '${backupFile.modifiedTime!.day}/${backupFile.modifiedTime!.month} à ${backupFile.modifiedTime!.hour}:${backupFile.modifiedTime!.minute}';
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Row(
              children: [
                Icon(Icons.cloud_download, color: Colors.blueAccent),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Sauvegarde trouvée',
                        style: TextStyle(color: Colors.white))),
              ],
            ),
            content: Text(
              'Une sauvegarde a été trouvée sur votre Google Drive datant du $dateStr.\nVoulez-vous la restaurer maintenant ?',
              style: GoogleFonts.cinzel(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ignorer',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  _restoreFromDrive(backupFile.id!, driveService, backupService);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900),
                child: const Text('Restaurer',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _restoreFromDrive(String fileId, dynamic driveService, dynamic backupService) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final jsonString = await driveService.downloadBackup(fileId);
      if (jsonString != null) {
        await backupService.restoreFromJson(jsonString);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Restauration réussie !'),
                backgroundColor: Colors.green),
          );
          context.go(AppRoutes.lifeCounter);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur restauration : $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = _locationToTabIndex(widget.currentLocation);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background_texture_black.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          drawer: _buildDrawer(context),
          body: SafeArea(child: widget.child),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: tabIndex,
            onTap: (index) => _onTabTapped(context, index),
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Icon(Icons.favorite), label: 'Compteur'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.camera_alt), label: 'Scanner'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.search), label: 'Recherche'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.style_outlined), label: 'Decks'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined), label: 'Collection'),
            ],
          ),
        ),
      ],
    );
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.lifeCounter);
      case 1:
        context.go(AppRoutes.scanner);
      case 2:
        context.go(AppRoutes.search);
      case 3:
        context.go(AppRoutes.decks);
      case 4:
        context.go(AppRoutes.collection);
    }
  }

  Widget _buildDrawer(BuildContext context) {
    final driveService = ref.read(googleDriveServiceProvider);

    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset('assets/icone.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(Icons.auto_awesome,
                        size: 48, color: Colors.white24)),
                const SizedBox(height: 16),
                Text('Magic Companion',
                    style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text('Outils & Références',
                    style: GoogleFonts.cinzel(
                        color: Colors.yellow.shade800, fontSize: 14)),
              ],
            ),
          ),

          // --- INDICATEUR DE CONNEXION DRIVE ---
          FutureBuilder<bool>(
            future: driveService.signIn(silent: true),
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              final userEmail = driveService.currentUser?.email;

              if (isConnected) {
                return Container(
                  color: Colors.green.withValues(alpha: 0.1),
                  child: ListTile(
                    leading:
                        const Icon(Icons.cloud_done, color: Colors.green),
                    title: Text(userEmail ?? 'Compte Google',
                        style: GoogleFonts.cinzel(
                            color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Sauvegarde auto active',
                        style: TextStyle(
                            color: Colors.greenAccent, fontSize: 10)),
                    trailing: IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.white54, size: 20),
                      tooltip: 'Déconnecter',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: const Text('Déconnexion',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                                'Arrêter la sauvegarde automatique ?',
                                style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Annuler')),
                              TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Déconnecter',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await driveService.signOut();
                          if (mounted) setState(() {});
                        }
                      },
                    ),
                  ),
                );
              } else {
                return ListTile(
                  leading:
                      const Icon(Icons.cloud_off, color: Colors.white54),
                  title: Text('Connexion Drive',
                      style: GoogleFonts.cinzel(color: Colors.white)),
                  subtitle: const Text('Activer la sauvegarde auto',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 10)),
                  onTap: () async {
                    bool success =
                        await driveService.signIn(silent: false);

                    if (success) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Connexion réussie. Sauvegarde en cours...')),
                        );
                      }

                      await _performAutoBackup();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Première sauvegarde effectuée !'),
                              backgroundColor: Colors.green),
                        );
                      }
                    }

                    if (mounted) setState(() {});
                  },
                );
              }
            },
          ),

          const Divider(color: Colors.white10),

          // --- SECTION JEU ---
          _drawerItem(
            icon: Icons.history,
            label: 'Historique Parties',
            route: AppRoutes.gameHistory,
          ),
          _drawerItem(
            icon: Icons.emoji_events_outlined,
            label: 'Gestion Tournoi',
            route: AppRoutes.tournament,
          ),
          ListTile(
            leading:
                const Icon(Icons.all_inclusive, color: Colors.purpleAccent),
            title: Text('Oracle (IA)',
                style: GoogleFonts.cinzel(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Posez vos questions de règles',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
            tileColor: Colors.purple.withValues(alpha: 0.1),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.oracle);
            },
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.orangeAccent),
              title: Text('Grimoire Code',
                  style: GoogleFonts.cinzel(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Interrogez votre codebase',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
              tileColor: Colors.green.withValues(alpha: 0.1),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.grimoire);
              },
            ),

          // --- SECTION OUTILS ---
          const Divider(color: Colors.white10),
          _drawerItem(
            icon: Icons.calculate_outlined,
            label: 'Calculateur Proba',
            route: AppRoutes.calculator,
          ),
          _drawerItem(
            icon: Icons.menu_book,
            label: 'Glossaire',
            route: AppRoutes.glossary,
          ),

          const Divider(color: Colors.white10),
          ListTile(
            leading:
                const Icon(Icons.group_outlined, color: Colors.white70),
            title: Text('Gestion des Profils',
                style: GoogleFonts.cinzel(color: Colors.white)),
            subtitle: const Text(
                'Gérez vos joueurs et leurs commandants',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.profiles);
            },
          ),
          _drawerItem(
            icon: Icons.settings,
            label: 'Paramètres & Sauvegarde',
            route: AppRoutes.settings,
          ),

          // --- BOUTON À PROPOS ---
          ListTile(
            leading:
                const Icon(Icons.info_outline, color: Colors.white30),
            title: Text('À propos & Licences',
                style: GoogleFonts.cinzel(color: Colors.white54)),
            onTap: () {
              Navigator.pop(context);
              _showAppAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: GoogleFonts.cinzel(color: Colors.white)),
      onTap: () {
        Navigator.pop(context); // ferme le drawer
        context.push(route);
      },
    );
  }

  Future<void> _showAppAboutDialog(BuildContext context) async {
    final PackageInfo info = await PackageInfo.fromPlatform();

    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Magic Companion',
      applicationVersion: 'v${info.version} (Build ${info.buildNumber})',
      applicationIcon: Image.asset(
        'assets/icone.png',
        width: 60,
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.auto_awesome, size: 48, color: Colors.white24),
      ),
      applicationLegalese: '© 2025 - Compagnon non-officiel',
      children: [
        const SizedBox(height: 24),
        Text(
          'Développé avec Flutter et Passion.',
          style: GoogleFonts.cinzel(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        const Text(
          "Ce projet utilise l'API Scryfall pour les données de cartes. "
          'Les informations textuelles et graphiques littérales et artistiques '
          'présentées sur ce site au sujet de Magic: The Gathering, y compris les images de cartes, '
          'le mana, et le symbole Tap sont la propriété de Wizards of the Coast, LLC.',
          style: TextStyle(color: Colors.white30, fontSize: 10),
        ),
      ],
    );
  }
}
