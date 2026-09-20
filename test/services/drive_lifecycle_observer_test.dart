// Fichier : test/services/drive_lifecycle_observer_test.dart
// La sauvegarde automatique Google Drive, et surtout son DECLENCHEUR.
//
// `didChangeAppLifecycleState` n'apparaissait dans aucun test du depot avant
// ce fichier. Si le deplacement du scaffold vers l'observer casse le
// declencheur, la sauvegarde s'arrete EN SILENCE : aucun test ne rougit, et
// on ne s'en apercoit qu'apres avoir perdu des donnees. C'est le risque le
// plus grave de ce lot, d'ou ces tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/backup_service.dart';
import 'package:magic_companion/services/drive_lifecycle_observer.dart';
import 'package:magic_companion/services/google_drive_service.dart';

/// Double de `GoogleDriveService` qui compte ses televersements.
///
/// Sous-classe plutot que mock : le service est une classe concrete sans
/// interface, et seules les quatre methodes que l'observer appelle sont
/// redefinies.
class _FakeDriveService extends GoogleDriveService {
  _FakeDriveService({required this.signedIn});

  final bool signedIn;
  int uploadCount = 0;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<bool> signIn({bool silent = true}) async => signedIn;

  /// Aucune sauvegarde distante : la proposition de restauration au demarrage
  /// n'est pas ce que ces tests mesurent, et elle ouvrirait un dialogue.
  @override
  Future<drive.File?> findBackupFile() async => null;

  @override
  Future<void> uploadBackup(String jsonContent) async {
    uploadCount++;
  }
}

class _FakeBackupService extends BackupService {
  int generateCount = 0;

  @override
  Future<String> generateBackupJson() async {
    generateCount++;
    return '{}';
  }
}

void main() {
  Widget harness({
    required _FakeDriveService drive,
    required _FakeBackupService backup,
    Widget enfant = const Text('app'),
  }) =>
      ProviderScope(
        overrides: [
          googleDriveServiceProvider.overrideWithValue(drive),
          backupServiceProvider.overrideWithValue(backup),
        ],
        child: MaterialApp(home: DriveLifecycleObserver(child: enfant)),
      );

  testWidgets('rend son enfant sans le modifier', (tester) async {
    await tester.pumpWidget(harness(
      drive: _FakeDriveService(signedIn: false),
      backup: _FakeBackupService(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('une mise en pause declenche la sauvegarde automatique',
      (tester) async {
    // LE test de ce lot.
    final drive = _FakeDriveService(signedIn: true);
    final backup = _FakeBackupService();

    await tester.pumpWidget(harness(drive: drive, backup: backup));
    await tester.pumpAndSettle();

    expect(drive.uploadCount, 0,
        reason: 'rien ne doit partir avant le passage en arriere-plan');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(drive.uploadCount, 1,
        reason: 'passer en arriere-plan doit televerser une sauvegarde');
    expect(backup.generateCount, 1,
        reason: 'le JSON televerse doit etre genere, pas invente');
  });

  testWidgets("ne televerse rien si l'utilisateur n'est pas connecte",
      (tester) async {
    final drive = _FakeDriveService(signedIn: false);
    final backup = _FakeBackupService();

    await tester.pumpWidget(harness(drive: drive, backup: backup));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(drive.uploadCount, 0);
    expect(backup.generateCount, 0,
        reason: 'generer un JSON qu on ne televersera pas est du travail perdu');
  });

  testWidgets('un retour au premier plan ne declenche rien', (tester) async {
    // Le pendant du test precedent : l'observer ne doit pas sauvegarder a
    // chaque soubresaut du cycle de vie, seulement en pause.
    final drive = _FakeDriveService(signedIn: true);
    final backup = _FakeBackupService();

    await tester.pumpWidget(harness(drive: drive, backup: backup));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(drive.uploadCount, 0);
  });

  testWidgets('se desabonne du binding a la destruction', (tester) async {
    final drive = _FakeDriveService(signedIn: true);
    final backup = _FakeBackupService();

    await tester.pumpWidget(harness(drive: drive, backup: backup));
    await tester.pumpAndSettle();

    // Meme ProviderScope, memes surcharges : Riverpod interdit d'en changer
    // le nombre entre deux pumps. Seul l'observer disparait, ce qui est
    // exactement ce qu'on veut mesurer.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        googleDriveServiceProvider.overrideWithValue(drive),
        backupServiceProvider.overrideWithValue(backup),
      ],
      child: const MaterialApp(home: Text('autre')),
    ));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(drive.uploadCount, 0,
        reason: 'un observer detruit ne doit plus rien televerser');
  });
}
