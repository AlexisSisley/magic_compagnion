// Fichier : lib/controllers/game_setup_controller.dart
// Sprint 12, US-12.7 : Controller pour GameSetupModal.
// Extrait la logique metier (format, joueurs, profils) du widget.

import 'package:flutter_riverpod/legacy.dart';

import '../models/profile_model.dart';
import '../services/profile_service.dart';

// --- RESULT OBJECT pour les actions ---

class GameSetupActionResult {
  final bool success;
  final String message;

  const GameSetupActionResult({
    this.success = true,
    this.message = '',
  });
}

// --- ETAT IMMUTABLE ---

class GameSetupState {
  final int startingLife;
  final List<Profile?> selectedProfiles;
  final List<Profile> availableProfiles;
  final bool isLoadingProfiles;

  /// Nombre max de joueurs autorises.
  static const int maxPlayers = 8;

  /// Nombre min de joueurs autorises.
  static const int minPlayers = 2;

  const GameSetupState({
    this.startingLife = 40,
    this.selectedProfiles = const [null, null, null, null],
    this.availableProfiles = const [],
    this.isLoadingProfiles = false,
  });

  GameSetupState copyWith({
    int? startingLife,
    List<Profile?>? selectedProfiles,
    List<Profile>? availableProfiles,
    bool? isLoadingProfiles,
  }) {
    return GameSetupState(
      startingLife: startingLife ?? this.startingLife,
      selectedProfiles: selectedProfiles ?? this.selectedProfiles,
      availableProfiles: availableProfiles ?? this.availableProfiles,
      isLoadingProfiles: isLoadingProfiles ?? this.isLoadingProfiles,
    );
  }

  /// Nombre actuel de slots joueurs.
  int get playerCount => selectedProfiles.length;

  /// Peut-on ajouter un joueur ?
  bool get canAddPlayer => playerCount < maxPlayers;

  /// Peut-on retirer un joueur ?
  bool get canRemovePlayer => playerCount > minPlayers;

  /// Le format actuel (Commander ou Standard) base sur les PV.
  String get formatLabel => startingLife == 40 ? 'Commander' : 'Standard';

  /// True si tous les slots sont remplis (aucun null).
  bool get allSlotsAssigned => selectedProfiles.every((p) => p != null);

  /// Nombre de profils assignes (non-null).
  int get assignedCount => selectedProfiles.where((p) => p != null).length;
}

// --- COULEURS PAR DEFAUT POUR LES PROFILS ---

/// Couleurs par defaut proposees lors de la creation de profils.
const List<int> defaultProfileColorValues = [
  0xFFB71C1C, // Colors.red.shade900
  0xFF0D47A1, // Colors.blue.shade900
  0xFF2E7D32, // Colors.green.shade800
  0xFF4A148C, // Colors.purple.shade900
  0xFFE65100, // Colors.orange.shade900
  0xFF004D40, // Colors.teal.shade900
  0xFF4E342E, // Colors.brown.shade800
  0xFF880E4F, // Colors.pink.shade900
  0xFF1A237E, // Colors.indigo.shade900
  0xFF424242, // AppColors.greyShade800
];

// --- CONTROLLER ---

class GameSetupController extends StateNotifier<GameSetupState> {
  final ProfileService _profileService;

  GameSetupController({
    required ProfileService profileService,
    int initialLife = 40,
  })  : _profileService = profileService,
        super(GameSetupState(startingLife: initialLife));

  /// Charge la liste de profils depuis le service.
  Future<void> loadProfiles() async {
    state = state.copyWith(isLoadingProfiles: true);
    try {
      final profiles = await _profileService.loadProfiles();
      state = state.copyWith(
        availableProfiles: profiles,
        isLoadingProfiles: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingProfiles: false);
    }
  }

  /// Change le format de jeu (Commander=40, Standard=20, ou custom).
  void selectFormat(int life) {
    state = state.copyWith(startingLife: life);
  }

  /// Assigne un profil a un slot joueur donne.
  /// [index] doit etre dans les bornes de selectedProfiles.
  /// [profile] peut etre null pour remettre le slot en "Invite".
  GameSetupActionResult assignProfile(int index, Profile? profile) {
    if (index < 0 || index >= state.playerCount) {
      return const GameSetupActionResult(
        success: false,
        message: 'Index joueur invalide',
      );
    }
    final updated = List<Profile?>.from(state.selectedProfiles);
    updated[index] = profile;
    state = state.copyWith(selectedProfiles: updated);
    return const GameSetupActionResult(
      success: true,
      message: 'Profil assigne',
    );
  }

  /// Ajoute un slot joueur (max 8).
  GameSetupActionResult addPlayer() {
    if (!state.canAddPlayer) {
      return const GameSetupActionResult(
        success: false,
        message: 'Nombre maximum de joueurs atteint (8)',
      );
    }
    final updated = List<Profile?>.from(state.selectedProfiles)..add(null);
    state = state.copyWith(selectedProfiles: updated);
    return const GameSetupActionResult(
      success: true,
      message: 'Joueur ajoute',
    );
  }

  /// Retire le dernier slot joueur (min 2).
  GameSetupActionResult removePlayer() {
    if (!state.canRemovePlayer) {
      return const GameSetupActionResult(
        success: false,
        message: 'Minimum 2 joueurs requis',
      );
    }
    final updated = List<Profile?>.from(state.selectedProfiles)..removeLast();
    state = state.copyWith(selectedProfiles: updated);
    return const GameSetupActionResult(
      success: true,
      message: 'Joueur retire',
    );
  }

  /// Sauvegarde un profil (creation ou mise a jour) et recharge la liste.
  Future<GameSetupActionResult> saveProfile(Profile profile) async {
    try {
      await _profileService.saveProfile(profile);
      await loadProfiles();
      return const GameSetupActionResult(
        success: true,
        message: 'Profil sauvegarde',
      );
    } catch (e) {
      return GameSetupActionResult(
        success: false,
        message: 'Erreur sauvegarde profil: $e',
      );
    }
  }

  /// Supprime un profil et recharge la liste.
  /// Retire aussi le profil des slots joueurs s'il y etait assigne.
  Future<GameSetupActionResult> deleteProfile(String profileId) async {
    try {
      await _profileService.deleteProfile(profileId);

      // Retirer le profil des slots joueurs
      final updated = state.selectedProfiles.map((p) {
        return (p != null && p.id == profileId) ? null : p;
      }).toList();

      state = state.copyWith(selectedProfiles: updated);
      await loadProfiles();

      return const GameSetupActionResult(
        success: true,
        message: 'Profil supprime',
      );
    } catch (e) {
      return GameSetupActionResult(
        success: false,
        message: 'Erreur suppression profil: $e',
      );
    }
  }

  /// Cree un nouveau profil a partir des donnees du formulaire.
  /// Retourne le profil cree ou null si le nom est vide.
  Future<Profile?> createProfile({
    required String name,
    required int colorValue,
    String? commanderScryfallId,
    String? commanderName,
    String? commanderArtCropUrl,
    String? secondaryCommanderScryfallId,
    String? secondaryCommanderName,
    String? secondaryCommanderArtCropUrl,
  }) async {
    if (name.trim().isEmpty) return null;

    final profile = Profile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      colorValue: colorValue,
      commanderScryfallId: commanderScryfallId,
      commanderName: commanderName,
      commanderArtCropUrl: commanderArtCropUrl,
      secondaryCommanderScryfallId: secondaryCommanderScryfallId,
      secondaryCommanderName: secondaryCommanderName,
      secondaryCommanderArtCropUrl: secondaryCommanderArtCropUrl,
    );

    await saveProfile(profile);
    return profile;
  }

  /// Met a jour un profil existant avec les donnees du formulaire.
  /// Retourne le profil mis a jour ou null si le nom est vide.
  Future<Profile?> updateProfile({
    required String existingId,
    required String name,
    required int colorValue,
    String? commanderScryfallId,
    String? commanderName,
    String? commanderArtCropUrl,
    String? secondaryCommanderScryfallId,
    String? secondaryCommanderName,
    String? secondaryCommanderArtCropUrl,
  }) async {
    if (name.trim().isEmpty) return null;

    final profile = Profile(
      id: existingId,
      name: name.trim(),
      colorValue: colorValue,
      commanderScryfallId: commanderScryfallId,
      commanderName: commanderName,
      commanderArtCropUrl: commanderArtCropUrl,
      secondaryCommanderScryfallId: secondaryCommanderScryfallId,
      secondaryCommanderName: secondaryCommanderName,
      secondaryCommanderArtCropUrl: secondaryCommanderArtCropUrl,
    );

    await saveProfile(profile);

    // Mettre a jour le profil dans les slots joueurs si present
    final updated = state.selectedProfiles.map((p) {
      return (p != null && p.id == existingId) ? profile : p;
    }).toList();
    state = state.copyWith(selectedProfiles: updated);

    return profile;
  }
}
