// Fichier : lib/pages/settings/sections/backup_section.dart
// Etat de connexion Google Drive et sauvegarde automatique.
//
// Bloc DEPLACE depuis `app_shell_scaffold.dart:_buildDrawer`, ou un
// `FutureBuilder<bool>` de connexion vivait au milieu d'un menu de
// navigation. La logique n'est pas reecrite : meme `signIn(silent: true)` au
// rendu, meme confirmation avant deconnexion, meme premiere sauvegarde apres
// connexion.
//
// Un point n'a PAS pu etre repris tel quel : le Drawer appelait sa methode
// privee `_performAutoBackup()`. Une methode privee d'un `State` n'est pas
// atteignable depuis un autre fichier ; son corps (generer le JSON, le
// televerser) est donc inline ici, a l'identique.
//
// Couleurs par MagicPalette : ecran neuf, donc aucun AppColors de surface,
// d'encre ou de semantique (contrainte globale du plan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/service_providers.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/magic_palette.dart';

class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  /// Genere la sauvegarde et la televerse.
  ///
  /// Corps de l'ancien `_performAutoBackup()` du scaffold de navigation.
  Future<void> _sauvegarderMaintenant() async {
    final driveService = ref.read(googleDriveServiceProvider);
    final backupService = ref.read(backupServiceProvider);
    if (!driveService.isSignedIn) return;
    final jsonString = await backupService.generateBackupJson();
    await driveService.uploadBackup(jsonString);
  }

  Future<void> _deconnecter() async {
    final p = MagicPalette.of(context);
    final driveService = ref.read(googleDriveServiceProvider);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.overlay,
        title: Text('Deconnexion',
            style: AppTextStyles.sectionTitle(color: p.inkPrimary)),
        content: Text('Arreter la sauvegarde automatique ?',
            style: AppTextStyles.text(color: p.inkSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Annuler',
                style: AppTextStyles.buttonText(color: p.inkSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Deconnecter',
                style: AppTextStyles.buttonText(color: p.danger)),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await driveService.signOut();
      if (mounted) setState(() {});
    }
  }

  Future<void> _connecter() async {
    final driveService = ref.read(googleDriveServiceProvider);
    final succes = await driveService.signIn(silent: false);
    if (!succes) {
      if (mounted) setState(() {});
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion reussie. Sauvegarde en cours...')),
      );
    }

    await _sauvegarderMaintenant();

    if (mounted) {
      final p = MagicPalette.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Premiere sauvegarde effectuee !'),
          backgroundColor: p.success,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final driveService = ref.read(googleDriveServiceProvider);

    return FutureBuilder<bool>(
      future: driveService.signIn(silent: true),
      builder: (context, snapshot) {
        final connecte = snapshot.data ?? false;
        final email = driveService.currentUser?.email;

        if (connecte) {
          return ListTile(
            leading: Icon(Icons.cloud_done, color: p.success),
            title: Text(email ?? 'Compte Google Drive',
                style: AppTextStyles.text(color: p.inkPrimary, fontSize: 14)),
            subtitle: Text('Sauvegarde auto active',
                style: AppTextStyles.text(color: p.success, fontSize: 11)),
            trailing: IconButton(
              icon: Icon(Icons.logout, color: p.inkSecondary, size: 20),
              tooltip: 'Deconnecter',
              onPressed: _deconnecter,
            ),
          );
        }

        return ListTile(
          leading: Icon(Icons.cloud_off, color: p.inkMuted),
          title: Text('Connexion Google Drive',
              style: AppTextStyles.text(color: p.inkPrimary)),
          subtitle: Text('Activer la sauvegarde auto',
              style: AppTextStyles.text(color: p.inkSecondary, fontSize: 11)),
          onTap: _connecter,
        );
      },
    );
  }
}
