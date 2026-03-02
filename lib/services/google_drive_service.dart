// Fichier : lib/services/google_drive_service.dart
import 'dart:convert';
import 'dart:developer';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GoogleDriveService {
  // Scopes : driveFile permet d'accéder/créer SEULEMENT les fichiers créés par cette app
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  
  GoogleSignInAccount? _currentUser;
  
  // Nom du fichier sur le Drive
  static const String _backupFileName = 'magic_companion_auto_backup.json';

  /// Connecte l'utilisateur
  /// Si [silent] est true, ne tente pas d'ouvrir la popup si l'utilisateur n'est pas déjà caché.
  Future<bool> signIn({bool silent = true}) async {
    try {
      if (silent) {
        _currentUser = await _googleSignIn.signInSilently();
      } else {
        // On force la popup SEULEMENT si silent est faux
        _currentUser = await _googleSignIn.signIn();
      }
      return _currentUser != null;
    } catch (e) {
      log('Erreur Google Sign In: $e', name: 'GoogleDriveService');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  bool get isSignedIn => _currentUser != null;
  
  // Pour afficher les infos dans le menu
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Cherche s'il existe une sauvegarde
  Future<drive.File?> findBackupFile() async {
    if (_currentUser == null) return null;

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    
    final driveApi = drive.DriveApi(client);
    
    final fileList = await driveApi.files.list(
      q: "name = '$_backupFileName' and trashed = false",
      $fields: 'files(id, name, modifiedTime)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first;
    }
    return null;
  }

  /// Télécharge le contenu de la sauvegarde
  Future<String?> downloadBackup(String fileId) async {
    if (_currentUser == null) return null;
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    
    final driveApi = drive.DriveApi(client);
    
    final drive.Media media = await driveApi.files.get(
      fileId, 
      downloadOptions: drive.DownloadOptions.fullMedia
    ) as drive.Media;

    final List<int> dataStore = [];
    await for (final data in media.stream) {
      dataStore.addAll(data);
    }
    return utf8.decode(dataStore);
  }

  /// Upload (Écrase ou Crée) la sauvegarde
  Future<void> uploadBackup(String jsonContent) async {
    // Si pas connecté, on tente une reconnexion silencieuse, mais PAS de popup
    if (_currentUser == null) {
      final success = await signIn(silent: true);
      if (!success) return; 
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return;
    
    final driveApi = drive.DriveApi(client);
    
    final List<int> contentBytes = utf8.encode(jsonContent);
    final drive.Media media = drive.Media(
      Stream.fromIterable([contentBytes]), 
      contentBytes.length
    );

    final existingFile = await findBackupFile();

    if (existingFile != null) {
      await driveApi.files.update(
        drive.File(), 
        existingFile.id!, 
        uploadMedia: media
      );
      log('Sauvegarde Drive mise à jour : ${existingFile.id}', name: 'GoogleDriveService');
    } else {
      final fileToUpload = drive.File();
      fileToUpload.name = _backupFileName;
      
      await driveApi.files.create(
        fileToUpload, 
        uploadMedia: media
      );
      log('Nouvelle sauvegarde Drive créée.', name: 'GoogleDriveService');
    }
  }
}