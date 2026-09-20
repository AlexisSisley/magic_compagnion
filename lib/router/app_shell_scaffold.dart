// Fichier : lib/router/app_shell_scaffold.dart
// Shell scaffold avec BottomNavigationBar et Drawer.
// Extrait de app_router.dart pour modularisation.

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/magic_palette.dart';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/service_providers.dart';
import 'app_routes.dart';

/// Shell scaffold avec BottomNavigationBar et Drawer.
/// Remplace l'ancien AppShell de main.dart.
class AppShellScaffold extends ConsumerStatefulWidget {
  final String currentLocation;
  final Widget child;

  const AppShellScaffold({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold>
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
      log('D\u00e9but sauvegarde automatique Drive...', name: 'AppShell');
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
              '${backupFile.modifiedTime!.day}/${backupFile.modifiedTime!.month} \u00e0 ${backupFile.modifiedTime!.hour}:${backupFile.modifiedTime!.minute}';
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.scaffoldBackground,
            title: const Row(
              children: [
                Icon(Icons.cloud_download, color: AppColors.accent),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Sauvegarde trouv\u00e9e',
                        style: TextStyle(color: AppColors.textPrimary))),
              ],
            ),
            content: Text(
              'Une sauvegarde a \u00e9t\u00e9 trouv\u00e9e sur votre Google Drive datant du $dateStr.\nVoulez-vous la restaurer maintenant ?',
              style: AppTextStyles.text(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ignorer',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  _restoreFromDrive(backupFile.id!, driveService, backupService);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900),
                child: const Text('Restaurer',
                    style: TextStyle(color: AppColors.textPrimary)),
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
                content: Text('Restauration r\u00e9ussie !'),
                backgroundColor: AppColors.success),
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
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = locationToTabIndex(widget.currentLocation);
    // US-LC02 : Mode fullscreen sans AppBar pour le compteur (tab0)
    final isLifeCounterTab = tabIndex == 0;

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
          backgroundColor: AppColors.transparent,
          drawer: _buildDrawer(context),
          // US-LC02 : Pas de SafeArea pour le Life Counter (fullscreen)
          body: isLifeCounterTab ? widget.child : SafeArea(child: widget.child),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: tabIndex,
            onTap: (index) => _onTabTapped(context, index),
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              // US-LC01 : tab0 = Life Counter avec icone coeur
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
    return Drawer(
      backgroundColor: AppColors.scaffoldBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.textOnPrimary,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                        size: 48, color: AppColors.borderMedium)),
                const SizedBox(height: 16),
                Text('Magic Companion',
                    style: AppTextStyles.bold(fontSize: 24)),
                Text('Outils & R\u00e9f\u00e9rences',
                    style: AppTextStyles.text(color: AppColors.primaryShade800, fontSize: 14)),
              ],
            ),
          ),

          const Divider(color: AppColors.borderLight),

          // --- SECTION JEU ---
          // US-LC03 : Dashboard deplace des tabs vers le Drawer
          _drawerItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: AppRoutes.dashboard,
          ),
          _drawerItem(
            icon: Icons.history,
            label: 'Historique Parties',
            route: AppRoutes.gameHistory,
          ),
          ListTile(
            leading: Icon(Icons.sports_esports,
                color: MagicPalette.of(context).accent),
            title: Text('Mode Jeu', style: AppTextStyles.sectionTitle()),
            subtitle: Text('Compteur, tournoi, oracle, regles, probabilites',
                style: AppTextStyles.text(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              context.go(AppRoutes.playSetup);
            },
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.menu_book, color: AppColors.accentOrange),
              title: Text('Grimoire Code',
                  style: AppTextStyles.bold()),
              subtitle: const Text('Interrogez votre codebase',
                  style: TextStyle(color: AppColors.borderFaint, fontSize: 10)),
              tileColor: Colors.green.withValues(alpha: 0.1),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.grimoire);
              },
            ),

          // --- SECTION OUTILS ---
          const Divider(color: AppColors.borderLight),
          _drawerItem(
            icon: Icons.menu_book,
            label: 'Glossaire',
            route: AppRoutes.glossary,
          ),

          const Divider(color: AppColors.borderLight),
          ListTile(
            leading:
                const Icon(Icons.group_outlined, color: AppColors.textSecondary),
            title: Text('Gestion des Profils',
                style: AppTextStyles.text()),
            subtitle: const Text(
                'G\u00e9rez vos joueurs et leurs commandants',
                style: TextStyle(color: AppColors.borderFaint, fontSize: 10)),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.profiles);
            },
          ),
          _drawerItem(
            icon: Icons.settings,
            label: 'Param\u00e8tres & Sauvegarde',
            route: AppRoutes.settings,
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
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: AppTextStyles.text()),
      onTap: () {
        Navigator.pop(context); // ferme le drawer
        context.push(route);
      },
    );
  }

}
