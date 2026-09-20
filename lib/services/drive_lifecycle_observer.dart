// Fichier : lib/services/drive_lifecycle_observer.dart
// Effets de cycle de vie applicatif lies a Google Drive : sauvegarde
// automatique au passage en arriere-plan, et proposition de restauration au
// demarrage.
//
// Ces membres vivaient dans `app_shell_scaffold.dart`, le widget de
// NAVIGATION. Ce n'est pas de la navigation : c'est du cycle de vie
// applicatif, et le lot E va reecrire ce scaffold. Ils sont donc remontes
// ici, au-dessus du routeur, ou leur duree de vie est celle de l'app plutot
// que celle d'un shell d'onglets.
//
// Le declencheur -- `didChangeAppLifecycleState` -- n'etait couvert par
// aucun test du depot avant ce deplacement. S'il cassait, la sauvegarde
// automatique s'arreterait en silence. Voir
// test/services/drive_lifecycle_observer_test.dart.

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/service_providers.dart';
import '../router/app_routes.dart';
import '../theme/app_text_styles.dart';
import '../theme/magic_palette.dart';

class DriveLifecycleObserver extends ConsumerStatefulWidget {
  const DriveLifecycleObserver({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  final Widget child;

  /// Contexte a utiliser pour tout ce qui s'affiche (dialogue de
  /// restauration, SnackBars, navigation).
  ///
  /// Indispensable : cet observer enveloppe `MaterialApp`, donc SON contexte
  /// n'a ni Navigator, ni ScaffoldMessenger, ni Theme au-dessus de lui --
  /// `showDialog` y leverait. La cle du Navigator du routeur, elle, designe
  /// un contexte situe a l'INTERIEUR de MaterialApp, ou les trois existent.
  ///
  /// Nulle en test : l'observer se contente alors de ne rien afficher, ce qui
  /// permet de tester le declencheur de sauvegarde sans monter un routeur.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  ConsumerState<DriveLifecycleObserver> createState() =>
      _DriveLifecycleObserverState();
}

class _DriveLifecycleObserverState extends ConsumerState<DriveLifecycleObserver>
    with WidgetsBindingObserver {
  /// Contexte d'affichage, ou `null` s'il n'y en a pas encore (ou pas du tout,
  /// en test).
  BuildContext? get _uiContext => widget.navigatorKey?.currentContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkDriveBackupOnStart());
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
      log('Debut sauvegarde automatique Drive...', name: 'DriveLifecycle');
      final jsonString = await backupService.generateBackupJson();
      await driveService.uploadBackup(jsonString);
    }
  }

  Future<void> _checkDriveBackupOnStart() async {
    final driveService = ref.read(googleDriveServiceProvider);
    final signedIn = await driveService.signIn(silent: true);
    if (!signedIn || !mounted) return;

    final backupFile = await driveService.findBackupFile();
    if (backupFile == null || !mounted) return;

    final context = _uiContext;
    if (context == null) return;

    final p = MagicPalette.of(context);
    var dateStr = 'Inconnue';
    final modifiee = backupFile.modifiedTime;
    if (modifiee != null) {
      dateStr = '${modifiee.day}/${modifiee.month} a '
          '${modifiee.hour}:${modifiee.minute}';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.overlay,
        title: Row(
          children: [
            Icon(Icons.cloud_download, color: p.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Sauvegarde trouvee',
                  style: AppTextStyles.sectionTitle(color: p.inkPrimary)),
            ),
          ],
        ),
        content: Text(
          'Une sauvegarde a ete trouvee sur votre Google Drive datant du '
          '$dateStr.\nVoulez-vous la restaurer maintenant ?',
          style: AppTextStyles.text(color: p.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ignorer',
                style: AppTextStyles.buttonText(color: p.inkSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreFromDrive(backupFile.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
            ),
            child: Text('Restaurer',
                style: AppTextStyles.buttonText(color: p.onAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreFromDrive(String fileId) async {
    final driveService = ref.read(googleDriveServiceProvider);
    final backupService = ref.read(backupServiceProvider);

    final context = _uiContext;
    if (context == null) return;
    final p = MagicPalette.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final jsonString = await driveService.downloadBackup(fileId);
      if (jsonString != null) {
        await backupService.restoreFromJson(jsonString);
        final apres = _uiContext;
        if (apres == null) return;
        Navigator.pop(apres);
        ScaffoldMessenger.of(apres).showSnackBar(
          SnackBar(
            content: const Text('Restauration reussie !'),
            backgroundColor: p.success,
          ),
        );
        // Vers l'Accueil, pas vers le compteur : apres une restauration on
        // veut voir sa collection revenue, pas un compteur de vie.
        apres.go(AppRoutes.home);
      }
    } catch (e) {
      final apres = _uiContext;
      if (apres == null) return;
      Navigator.pop(apres);
      ScaffoldMessenger.of(apres).showSnackBar(
        SnackBar(
          content: Text('Erreur restauration : $e'),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
