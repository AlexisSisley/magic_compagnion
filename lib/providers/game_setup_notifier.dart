// Fichier : lib/providers/game_setup_notifier.dart
// Lot 4, tâche 2 : GameSetupController (StateNotifier, Sprint 12 US-12.7) →
// GameSetupNotifier (Notifier Riverpod), état du nouveau setup inline.
//
// `int startingLife` est remplacé par `GameFormat format` : le format porte
// aujourd'hui aussi les seuils de mort (maxPoison, maxCommanderDamage,
// lethalAtZeroLife), pas seulement les PV de départ — voir
// lib/models/game_format.dart. `formatLabel` disparaît avec cette migration :
// il dérivait un nom de format à partir des PV de départ, ce que
// `GameFormat.name` donne désormais directement.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_format.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import 'service_providers.dart';

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

/// Format par défaut du setup : Commander (40 PV), identique à
/// `GameFormat.builtInFormats.first`. Dupliqué ici en `const` littéral car
/// une valeur par défaut de paramètre doit être une expression constante —
/// l'indexation d'une liste (même `const`) ne l'est pas.
const _defaultFormat = GameFormat(
  id: 'commander',
  name: 'Commander',
  startingLife: 40,
  minPlayers: 2,
  maxPlayers: 8,
  maxCommanders: 2,
  enabledCounterIds: ['poison', 'energy', 'commander_tax', 'commander_damage'],
  isBuiltIn: true,
);

class GameSetupState {
  final GameFormat format;
  final List<Profile?> selectedProfiles;
  final List<Profile> availableProfiles;
  final bool isLoadingProfiles;
  final bool timerEnabled;

  /// Nombre max de joueurs autorises.
  static const int maxPlayers = 8;

  /// Nombre min de joueurs autorises.
  static const int minPlayers = 2;

  const GameSetupState({
    this.format = _defaultFormat,
    this.selectedProfiles = const [null, null, null, null],
    this.availableProfiles = const [],
    this.isLoadingProfiles = false,
    this.timerEnabled = true,
  });

  GameSetupState copyWith({
    GameFormat? format,
    List<Profile?>? selectedProfiles,
    List<Profile>? availableProfiles,
    bool? isLoadingProfiles,
    bool? timerEnabled,
  }) {
    return GameSetupState(
      format: format ?? this.format,
      selectedProfiles: selectedProfiles ?? this.selectedProfiles,
      availableProfiles: availableProfiles ?? this.availableProfiles,
      isLoadingProfiles: isLoadingProfiles ?? this.isLoadingProfiles,
      timerEnabled: timerEnabled ?? this.timerEnabled,
    );
  }

  /// Nombre actuel de slots joueurs.
  int get playerCount => selectedProfiles.length;

  /// Peut-on ajouter un joueur ?
  bool get canAddPlayer => playerCount < maxPlayers;

  /// Peut-on retirer un joueur ?
  bool get canRemovePlayer => playerCount > minPlayers;

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

// --- NOTIFIER ---

class GameSetupNotifier extends Notifier<GameSetupState> {
  // `NotifierProvider` sans argument attend un constructeur sans argument
  // (`GameSetupNotifier.new`) : `ProfileService` ne se passe donc pas au
  // constructeur, il se lit dans `build()` via `ref.read`.
  late final ProfileService _profileService;

  @override
  GameSetupState build() {
    _profileService = ref.read(profileServiceProvider);
    return const GameSetupState();
  }

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

  /// Change le format de jeu (Commander, Standard, ou un format custom).
  void selectFormat(GameFormat format) {
    state = state.copyWith(format: format);
  }

  /// Active/désactive le chronomètre de partie.
  void setTimerEnabled(bool enabled) {
    state = state.copyWith(timerEnabled: enabled);
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

  /// Retire le slot joueur a [index] (min 2 joueurs restants).
  ///
  /// Ronde de correction 1, tache 3 du lot 4 : avant cette methode, le "-"
  /// d'une case de `SetupSeat` appelait `removePlayer()`, qui retire
  /// toujours le DERNIER slot -- taper sur la case de Bob a 4 joueurs
  /// retirait Dave. `index` est desormais l'identite reelle du slot retire.
  GameSetupActionResult removePlayerAt(int index) {
    if (!state.canRemovePlayer) {
      return const GameSetupActionResult(
        success: false,
        message: 'Minimum 2 joueurs requis',
      );
    }
    if (index < 0 || index >= state.playerCount) {
      return const GameSetupActionResult(
        success: false,
        message: 'Index joueur invalide',
      );
    }
    final updated = List<Profile?>.from(state.selectedProfiles)..removeAt(index);
    state = state.copyWith(selectedProfiles: updated);
    return const GameSetupActionResult(
      success: true,
      message: 'Joueur retire',
    );
  }

  /// Retire le dernier slot joueur (min 2). Delegue a [removePlayerAt] pour
  /// que ce raccourci et le retrait cible partagent les memes gardes.
  GameSetupActionResult removePlayer() => removePlayerAt(state.playerCount - 1);

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
      // Ronde de correction 1, tache 4 : repris de game_setup_modal.dart
      // `_showCreateProfileDialog` (ligne ~837), qui amorcait deja
      // `commanderGallery` avec le commandant PRINCIPAL choisi a la
      // creation -- jamais le secondaire, ce dialogue n'en avait pas.
      // Sans cette entree, player_zone.dart et player_skin_picker.dart
      // n'ont rien a proposer au premier switch de commandant en partie.
      commanderGallery: commanderScryfallId != null
          ? [
              CommanderEntry(
                scryfallId: commanderScryfallId,
                name: commanderName ?? '',
                artCropUrl: commanderArtCropUrl,
              ),
            ]
          : const [],
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

    // Ronde de correction 1, tache 4 : repris de game_setup_modal.dart
    // `_showProfileForm` (ligne ~685), qui ne RAJOUTE jamais d'entree a la
    // galerie a l'edition (contrairement a la creation) mais ne l'ECRASE
    // pas non plus : `commanderGallery: existingProfile?.commanderGallery
    // ?? []`. Avant ce correctif, `updateProfile` reconstruisait toujours
    // un `Profile` sans passer `commanderGallery`, qui retombait donc a
    // `const []` -- toute modification remettait silencieusement la
    // galerie a zero.
    List<CommanderEntry> existingGallery = const [];
    for (final p in state.availableProfiles) {
      if (p.id == existingId) {
        existingGallery = p.commanderGallery;
        break;
      }
    }

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
      commanderGallery: existingGallery,
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

final gameSetupProvider = NotifierProvider<GameSetupNotifier, GameSetupState>(
  GameSetupNotifier.new,
);
