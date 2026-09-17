// test/providers/game_setup_notifier_test.dart
// Repris de test/controllers/game_setup_controller_test.dart (Sprint 12,
// US-12.7) lors de la migration StateNotifier -> Notifier (Lot 4, tache 2).
// Meme couverture, adaptee mecaniquement :
//  - construction via ProviderContainer, profileServiceProvider surcharge
//    par le FakeProfileService deja present dans ce fichier ;
//  - selectFormat(int life) devient selectFormat(GameFormat) ;
//  - les assertions sur formatLabel deviennent des assertions sur
//    state.format.id / state.format.startingLife (formatLabel a disparu :
//    GameFormat.name donne directement le nom du format).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/profile_model.dart';
import 'package:magic_companion/providers/game_setup_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/profile_service.dart';

// --- Fake ProfileService pour les tests ---

class FakeProfileService {
  final List<Profile> _profiles = [];
  int loadCallCount = 0;
  int saveCallCount = 0;
  int deleteCallCount = 0;
  bool shouldThrow = false;

  Future<List<Profile>> loadProfiles() async {
    loadCallCount++;
    if (shouldThrow) throw Exception('Test error');
    return List.from(_profiles);
  }

  Future<void> saveProfile(Profile profile) async {
    saveCallCount++;
    if (shouldThrow) throw Exception('Test error');
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
    } else {
      _profiles.add(profile);
    }
  }

  Future<void> deleteProfile(String id) async {
    deleteCallCount++;
    if (shouldThrow) throw Exception('Test error');
    _profiles.removeWhere((p) => p.id == id);
  }

  void addTestProfile(Profile p) => _profiles.add(p);
}

final _commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
final _standardFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'standard');

/// Construit un ProviderContainer avec [fake] injecte a la place du vrai
/// ProfileService, et programme sa destruction en fin de test.
ProviderContainer _makeContainer(_FakeProfileServiceAdapter fake) {
  final container = ProviderContainer(
    overrides: [profileServiceProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

GameSetupNotifier _makeNotifier(_FakeProfileServiceAdapter fake) =>
    _makeContainer(fake).read(gameSetupProvider.notifier);

void main() {
  // ============================================================
  // GameSetupState - Tests unitaires purs sur l'etat immutable
  // ============================================================

  group('GameSetupState', () {
    test('initial state has correct defaults', () {
      const state = GameSetupState();

      expect(state.format.id, 'commander');
      expect(state.format.startingLife, 40);
      expect(state.selectedProfiles, hasLength(4));
      expect(state.selectedProfiles.every((p) => p == null), true);
      expect(state.availableProfiles, isEmpty);
      expect(state.isLoadingProfiles, false);
      expect(state.timerEnabled, true);
    });

    test('copyWith preserves values when no arguments given', () {
      final state = GameSetupState(
        format: _standardFormat,
        isLoadingProfiles: true,
      );

      final copied = state.copyWith();
      expect(copied.format.startingLife, 20);
      expect(copied.isLoadingProfiles, true);
    });

    test('copyWith overrides specified values', () {
      const state = GameSetupState();
      final updated = state.copyWith(
        format: _standardFormat,
        isLoadingProfiles: true,
      );

      expect(updated.format.startingLife, 20);
      expect(updated.isLoadingProfiles, true);
      // Unchanged
      expect(updated.selectedProfiles, hasLength(4));
    });

    test('copyWith updates selectedProfiles', () {
      const state = GameSetupState();
      final profile = Profile(id: '1', name: 'Test');
      final updated = state.copyWith(
        selectedProfiles: [profile, null, null, null],
      );

      expect(updated.selectedProfiles[0], equals(profile));
      expect(updated.selectedProfiles[1], isNull);
    });

    test('copyWith updates availableProfiles', () {
      const state = GameSetupState();
      final profiles = [
        Profile(id: '1', name: 'Alice'),
        Profile(id: '2', name: 'Bob'),
      ];
      final updated = state.copyWith(availableProfiles: profiles);

      expect(updated.availableProfiles, hasLength(2));
      expect(updated.availableProfiles[0].name, 'Alice');
    });

    test('copyWith updates timerEnabled', () {
      const state = GameSetupState();
      final updated = state.copyWith(timerEnabled: false);

      expect(updated.timerEnabled, false);
    });
  });

  // ============================================================
  // GameSetupState computed properties
  // ============================================================

  group('GameSetupState computed properties', () {
    test('playerCount returns length of selectedProfiles', () {
      const state = GameSetupState(selectedProfiles: [null, null, null, null]);
      expect(state.playerCount, 4);
    });

    test('canAddPlayer is true when less than 8 players', () {
      const state = GameSetupState(selectedProfiles: [null, null]);
      expect(state.canAddPlayer, true);
    });

    test('canAddPlayer is false when 8 players', () {
      final state = GameSetupState(
        selectedProfiles: List.filled(8, null),
      );
      expect(state.canAddPlayer, false);
    });

    test('canRemovePlayer is true when more than 2 players', () {
      const state = GameSetupState(selectedProfiles: [null, null, null]);
      expect(state.canRemovePlayer, true);
    });

    test('canRemovePlayer is false when 2 players', () {
      const state = GameSetupState(selectedProfiles: [null, null]);
      expect(state.canRemovePlayer, false);
    });

    test('format.id is commander for the Commander format', () {
      final state = GameSetupState(format: _commanderFormat);
      expect(state.format.id, 'commander');
    });

    test('format.id is standard for the Standard format', () {
      final state = GameSetupState(format: _standardFormat);
      expect(state.format.id, 'standard');
    });

    test('allSlotsAssigned is false when any slot is null', () {
      final state = GameSetupState(
        selectedProfiles: [Profile(id: '1', name: 'A'), null],
      );
      expect(state.allSlotsAssigned, false);
    });

    test('allSlotsAssigned is true when all slots are filled', () {
      final state = GameSetupState(
        selectedProfiles: [
          Profile(id: '1', name: 'A'),
          Profile(id: '2', name: 'B'),
        ],
      );
      expect(state.allSlotsAssigned, true);
    });

    test('assignedCount counts non-null profiles', () {
      final state = GameSetupState(
        selectedProfiles: [
          Profile(id: '1', name: 'A'),
          null,
          Profile(id: '3', name: 'C'),
          null,
        ],
      );
      expect(state.assignedCount, 2);
    });

    test('maxPlayers is 8', () {
      expect(GameSetupState.maxPlayers, 8);
    });

    test('minPlayers is 2', () {
      expect(GameSetupState.minPlayers, 2);
    });
  });

  // ============================================================
  // GameSetupActionResult
  // ============================================================

  group('GameSetupActionResult', () {
    test('default values are success=true, message empty', () {
      const result = GameSetupActionResult();
      expect(result.success, true);
      expect(result.message, '');
    });

    test('can create failure result', () {
      const result = GameSetupActionResult(
        success: false,
        message: 'Erreur test',
      );
      expect(result.success, false);
      expect(result.message, 'Erreur test');
    });
  });

  // ============================================================
  // defaultProfileColorValues
  // ============================================================

  group('defaultProfileColorValues', () {
    test('contains 10 colors', () {
      expect(defaultProfileColorValues, hasLength(10));
    });

    test('all values are valid ARGB color integers', () {
      for (final color in defaultProfileColorValues) {
        // ARGB format: alpha channel should be 0xFF (fully opaque)
        expect(color >> 24, 0xFF, reason: 'Color $color should have alpha 0xFF');
      }
    });

    test('first color is red shade', () {
      // 0xFFB71C1C = Colors.red.shade900
      expect(defaultProfileColorValues[0], 0xFFB71C1C);
    });

    test('second color is blue shade', () {
      // 0xFF0D47A1 = Colors.blue.shade900
      expect(defaultProfileColorValues[1], 0xFF0D47A1);
    });
  });

  // ============================================================
  // GameSetupNotifier - selectFormat
  // ============================================================

  group('GameSetupNotifier.selectFormat', () {
    test('selectFormat changes format to Commander (40)', () {
      final container = _makeContainer(_FakeProfileServiceAdapter());
      final notifier = container.read(gameSetupProvider.notifier);

      notifier.selectFormat(_standardFormat);
      notifier.selectFormat(_commanderFormat);

      expect(container.read(gameSetupProvider).format.startingLife, 40);
      expect(container.read(gameSetupProvider).format.id, 'commander');
    });

    test('selectFormat changes format to Standard (20)', () {
      final container = _makeContainer(_FakeProfileServiceAdapter());
      final notifier = container.read(gameSetupProvider.notifier);

      notifier.selectFormat(_standardFormat);

      expect(container.read(gameSetupProvider).format.startingLife, 20);
      expect(container.read(gameSetupProvider).format.id, 'standard');
    });

    // NOTE (Lot 4, tache 2) : le cas "initial life is preserved from
    // constructor" de l'ancien GameSetupController (qui prenait
    // `initialLife` en parametre de constructeur) n'a pas d'equivalent ici.
    // Un NotifierProvider sans argument prend un constructeur sans
    // argument (piege deja paye au lot 1) : GameSetupNotifier ne peut donc
    // plus recevoir de format initial personnalise via son constructeur.
    // L'etat initial est toujours GameSetupState() par defaut (Commander,
    // 40 PV) ; ce test est intentionnellement non porte, pas oublie.
  });

  // ============================================================
  // GameSetupNotifier - addPlayer / removePlayer
  // ============================================================

  group('GameSetupNotifier.addPlayer', () {
    test('addPlayer adds a null slot', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());

      expect(notifier.state.playerCount, 4);
      final result = notifier.addPlayer();
      expect(result.success, true);
      expect(notifier.state.playerCount, 5);
      expect(notifier.state.selectedProfiles.last, isNull);
    });

    test('addPlayer fails when at max (8)', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());

      // Add to reach 8
      notifier.addPlayer(); // 5
      notifier.addPlayer(); // 6
      notifier.addPlayer(); // 7
      notifier.addPlayer(); // 8
      expect(notifier.state.playerCount, 8);

      final result = notifier.addPlayer();
      expect(result.success, false);
      expect(result.message, contains('maximum'));
      expect(notifier.state.playerCount, 8);
    });
  });

  group('GameSetupNotifier.removePlayer', () {
    test('removePlayer removes last slot', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());

      expect(notifier.state.playerCount, 4);
      final result = notifier.removePlayer();
      expect(result.success, true);
      expect(notifier.state.playerCount, 3);
    });

    test('removePlayer fails when at min (2)', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());

      notifier.removePlayer(); // 3
      notifier.removePlayer(); // 2
      expect(notifier.state.playerCount, 2);

      final result = notifier.removePlayer();
      expect(result.success, false);
      expect(result.message, contains('2 joueurs'));
      expect(notifier.state.playerCount, 2);
    });
  });

  // ============================================================
  // GameSetupNotifier - removePlayerAt (ronde de correction 1, tache 3 du
  // lot 4) : `removePlayer()` retire toujours le dernier slot, ce qui ne
  // correspond pas a "retirer la case sur laquelle on tape" -- voir
  // `removePlayer removes last slot (delegation)` ci-dessous pour la
  // garantie que le raccourci reste inchange.
  // ============================================================

  group('GameSetupNotifier.removePlayerAt', () {
    test('removePlayerAt removes the slot at the given index, not the last',
        () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());
      notifier.assignProfile(0, Profile(id: 'a', name: 'Alice'));
      notifier.assignProfile(1, Profile(id: 'b', name: 'Bob'));
      notifier.assignProfile(2, Profile(id: 'c', name: 'Carol'));
      notifier.assignProfile(3, Profile(id: 'd', name: 'Dave'));

      final result = notifier.removePlayerAt(1);
      expect(result.success, true);
      expect(notifier.state.playerCount, 3);
      expect(
        notifier.state.selectedProfiles.map((p) => p?.name).toList(),
        ['Alice', 'Carol', 'Dave'],
      );
    });

    test('removePlayerAt fails when at min (2)', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());
      notifier.removePlayerAt(0); // 3
      notifier.removePlayerAt(0); // 2
      expect(notifier.state.playerCount, 2);

      final result = notifier.removePlayerAt(0);
      expect(result.success, false);
      expect(result.message, contains('2 joueurs'));
      expect(notifier.state.playerCount, 2);
    });

    test('removePlayerAt fails on an out-of-bounds index', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());

      final tooHigh = notifier.removePlayerAt(4);
      expect(tooHigh.success, false);
      expect(tooHigh.message, contains('Index'));
      expect(notifier.state.playerCount, 4);

      final negative = notifier.removePlayerAt(-1);
      expect(negative.success, false);
      expect(notifier.state.playerCount, 4);
    });

    test('removePlayer removes last slot (delegation)', () {
      // Garantit que le raccourci `removePlayer()` reste un simple appel a
      // `removePlayerAt(playerCount - 1)`, pour que les tests existants
      // repris de la tache 2 restent verts sans retouche.
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());
      notifier.assignProfile(3, Profile(id: 'd', name: 'Dave'));

      final result = notifier.removePlayer();
      expect(result.success, true);
      expect(notifier.state.playerCount, 3);
      expect(notifier.state.selectedProfiles.any((p) => p?.name == 'Dave'),
          false);
    });
  });

  // ============================================================
  // GameSetupNotifier - assignProfile
  // ============================================================

  group('GameSetupNotifier.assignProfile', () {
    test('assignProfile sets profile at valid index', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());
      final profile = Profile(id: '1', name: 'Test Player');

      final result = notifier.assignProfile(0, profile);
      expect(result.success, true);
      expect(notifier.state.selectedProfiles[0]?.name, 'Test Player');
    });

    test('assignProfile with null resets slot to guest', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());
      final profile = Profile(id: '1', name: 'Test Player');
      notifier.assignProfile(0, profile);

      final result = notifier.assignProfile(0, null);
      expect(result.success, true);
      expect(notifier.state.selectedProfiles[0], isNull);
    });

    test('assignProfile fails with negative index', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());

      final result = notifier.assignProfile(-1, null);
      expect(result.success, false);
      expect(result.message, contains('invalide'));
    });

    test('assignProfile fails with out-of-bounds index', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());

      final result = notifier.assignProfile(10, null);
      expect(result.success, false);
      expect(result.message, contains('invalide'));
    });

    test('assignProfile preserves other slots', () {
      final notifier = _makeNotifier(_FakeProfileServiceAdapter());
      final p1 = Profile(id: '1', name: 'Alice');
      final p2 = Profile(id: '2', name: 'Bob');

      notifier.assignProfile(0, p1);
      notifier.assignProfile(2, p2);

      expect(notifier.state.selectedProfiles[0]?.name, 'Alice');
      expect(notifier.state.selectedProfiles[1], isNull);
      expect(notifier.state.selectedProfiles[2]?.name, 'Bob');
      expect(notifier.state.selectedProfiles[3], isNull);
    });
  });

  // ============================================================
  // GameSetupNotifier - loadProfiles
  // ============================================================

  group('GameSetupNotifier.loadProfiles', () {
    test('loadProfiles populates availableProfiles', () async {
      final fake = _FakeProfileServiceAdapter();
      fake.profiles = [
        Profile(id: '1', name: 'Alice'),
        Profile(id: '2', name: 'Bob'),
      ];

      final notifier = _makeNotifier(fake);
      await notifier.loadProfiles();

      expect(notifier.state.availableProfiles, hasLength(2));
      expect(notifier.state.availableProfiles[0].name, 'Alice');
      expect(notifier.state.isLoadingProfiles, false);
    });

    test('loadProfiles sets isLoadingProfiles during load', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      // Before loading
      expect(notifier.state.isLoadingProfiles, false);

      // After loading
      await notifier.loadProfiles();
      expect(notifier.state.isLoadingProfiles, false);
    });

    test('loadProfiles handles errors gracefully', () async {
      final fake = _FakeProfileServiceAdapter(shouldThrow: true);
      final notifier = _makeNotifier(fake);

      await notifier.loadProfiles();
      expect(notifier.state.isLoadingProfiles, false);
      expect(notifier.state.availableProfiles, isEmpty);
    });
  });

  // ============================================================
  // GameSetupNotifier - saveProfile
  // ============================================================

  group('GameSetupNotifier.saveProfile', () {
    test('saveProfile saves and reloads profiles', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final profile = Profile(id: '1', name: 'New Player');
      final result = await notifier.saveProfile(profile);

      expect(result.success, true);
      expect(notifier.state.availableProfiles, hasLength(1));
      expect(notifier.state.availableProfiles[0].name, 'New Player');
    });

    test('saveProfile returns failure on error', () async {
      final fake = _FakeProfileServiceAdapter(shouldThrow: true);
      final notifier = _makeNotifier(fake);

      final profile = Profile(id: '1', name: 'New Player');
      final result = await notifier.saveProfile(profile);

      expect(result.success, false);
      expect(result.message, contains('Erreur'));
    });
  });

  // ============================================================
  // GameSetupNotifier - deleteProfile
  // ============================================================

  group('GameSetupNotifier.deleteProfile', () {
    test('deleteProfile removes from available and slots', () async {
      final fake = _FakeProfileServiceAdapter();
      final profile = Profile(id: '1', name: 'Alice');
      fake.profiles = [profile];

      final notifier = _makeNotifier(fake);
      await notifier.loadProfiles();

      // Assign to slot 0
      notifier.assignProfile(0, profile);
      expect(notifier.state.selectedProfiles[0]?.name, 'Alice');

      // Delete
      final result = await notifier.deleteProfile('1');
      expect(result.success, true);
      expect(notifier.state.selectedProfiles[0], isNull);
      expect(notifier.state.availableProfiles, isEmpty);
    });

    test('deleteProfile returns failure on error', () async {
      final fake = _FakeProfileServiceAdapter(shouldThrow: true);
      final notifier = _makeNotifier(fake);

      final result = await notifier.deleteProfile('1');
      expect(result.success, false);
      expect(result.message, contains('Erreur'));
    });
  });

  // ============================================================
  // GameSetupNotifier - createProfile
  // ============================================================

  group('GameSetupNotifier.createProfile', () {
    test('createProfile creates and saves a new profile', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: 'New Player',
        colorValue: 0xFF0D47A1,
        commanderName: 'Atraxa',
      );

      expect(result, isNotNull);
      expect(result!.name, 'New Player');
      expect(result.colorValue, 0xFF0D47A1);
      expect(result.commanderName, 'Atraxa');
      expect(notifier.state.availableProfiles, hasLength(1));
    });

    test('createProfile returns null for empty name', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: '',
        colorValue: 0xFF0D47A1,
      );

      expect(result, isNull);
      expect(notifier.state.availableProfiles, isEmpty);
    });

    test('createProfile returns null for whitespace-only name', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: '   ',
        colorValue: 0xFF0D47A1,
      );

      expect(result, isNull);
    });

    test('createProfile trims name', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: '  Alice  ',
        colorValue: 0xFF0D47A1,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Alice');
    });

    test('createProfile sets all optional fields', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: 'Test',
        colorValue: 0xFFB71C1C,
        commanderScryfallId: 'scry-1',
        commanderName: 'Atraxa',
        commanderArtCropUrl: 'https://example.com/art.jpg',
        secondaryCommanderScryfallId: 'scry-2',
        secondaryCommanderName: 'Thrasios',
        secondaryCommanderArtCropUrl: 'https://example.com/art2.jpg',
      );

      expect(result, isNotNull);
      expect(result!.commanderScryfallId, 'scry-1');
      expect(result.commanderName, 'Atraxa');
      expect(result.commanderArtCropUrl, 'https://example.com/art.jpg');
      expect(result.secondaryCommanderScryfallId, 'scry-2');
      expect(result.secondaryCommanderName, 'Thrasios');
      expect(result.secondaryCommanderArtCropUrl, 'https://example.com/art2.jpg');
    });

    // Ronde de correction 1, tache 4 : `game_setup_modal.dart`
    // (`_showCreateProfileDialog`, ligne ~837) amorcait `commanderGallery`
    // avec le commandant principal choisi a la creation. `createProfile`
    // ne le faisait pas (construisait toujours `const []`), ce qui restait
    // invisible tant que rien ne creait de profil AVEC un commandant en
    // passant par le notifier -- la case de la table (tache 4) est le
    // premier chemin a le faire. La modale disparait en tache 6 : sans ce
    // correctif, ce comportement est perdu definitivement.
    test('createProfile amorce commanderGallery avec le commandant '
        'principal, comme le faisait _showCreateProfileDialog', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: 'Test',
        colorValue: 0xFFB71C1C,
        commanderScryfallId: 'scry-1',
        commanderName: 'Atraxa',
        commanderArtCropUrl: 'https://example.com/art.jpg',
      );

      expect(result, isNotNull);
      expect(result!.commanderGallery, hasLength(1));
      expect(result.commanderGallery.first.scryfallId, 'scry-1');
      expect(result.commanderGallery.first.name, 'Atraxa');
      expect(result.commanderGallery.first.artCropUrl,
          'https://example.com/art.jpg');
    });

    test('createProfile ne cree pas d\'entree de galerie sans commandant',
        () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: 'Test sans commandant',
        colorValue: 0xFFB71C1C,
      );

      expect(result, isNotNull);
      expect(result!.commanderGallery, isEmpty);
    });

    test(
        'createProfile n\'amorce PAS la galerie avec le commandant '
        'secondaire (absent de _showCreateProfileDialog, qui n\'avait pas '
        'de partenaire)', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.createProfile(
        name: 'Test partenaire seul',
        colorValue: 0xFFB71C1C,
        secondaryCommanderScryfallId: 'scry-2',
        secondaryCommanderName: 'Thrasios',
      );

      expect(result, isNotNull);
      expect(result!.commanderGallery, isEmpty);
    });
  });

  // ============================================================
  // GameSetupNotifier - updateProfile
  // ============================================================

  group('GameSetupNotifier.updateProfile', () {
    test('updateProfile updates existing profile', () async {
      final fake = _FakeProfileServiceAdapter();
      final original = Profile(id: '1', name: 'Alice');
      fake.profiles = [original];

      final notifier = _makeNotifier(fake);
      await notifier.loadProfiles();

      final result = await notifier.updateProfile(
        existingId: '1',
        name: 'Alice Updated',
        colorValue: 0xFFB71C1C,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Alice Updated');
      expect(result.colorValue, 0xFFB71C1C);
    });

    // Ronde de correction 1, tache 4 : verifie plutot que suppose --
    // `_showProfileForm` (game_setup_modal.dart, ligne ~685) ne rajoute
    // JAMAIS d'entree de galerie a l'edition (contrairement a la
    // creation) mais NE L'ECRASE PAS non plus : `commanderGallery:
    // existingProfile?.commanderGallery ?? []`. Avant ce correctif,
    // `updateProfile` reconstruisait toujours un `Profile` sans passer
    // `commanderGallery`, qui retombait donc a `const []` -- une
    // modification remettait silencieusement la galerie a zero.
    test(
        'updateProfile preserve la galerie existante (ne l\'ecrase pas a '
        'zero), comme le faisait _showProfileForm', () async {
      final fake = _FakeProfileServiceAdapter();
      final original = Profile(
        id: '1',
        name: 'Alice',
        commanderGallery: const [
          CommanderEntry(scryfallId: 'scry-1', name: 'Atraxa'),
        ],
      );
      fake.profiles = [original];

      final notifier = _makeNotifier(fake);
      await notifier.loadProfiles();

      final result = await notifier.updateProfile(
        existingId: '1',
        name: 'Alice Updated',
        colorValue: 0xFFB71C1C,
      );

      expect(result, isNotNull);
      expect(result!.commanderGallery, hasLength(1));
      expect(result.commanderGallery.first.scryfallId, 'scry-1');
      expect(result.commanderGallery.first.name, 'Atraxa');
    });

    test('updateProfile returns null for empty name', () async {
      final fake = _FakeProfileServiceAdapter();
      final notifier = _makeNotifier(fake);

      final result = await notifier.updateProfile(
        existingId: '1',
        name: '',
        colorValue: 0xFF0D47A1,
      );

      expect(result, isNull);
    });

    test('updateProfile updates profile in assigned slots', () async {
      final fake = _FakeProfileServiceAdapter();
      final original = Profile(id: '1', name: 'Alice');
      fake.profiles = [original];

      final notifier = _makeNotifier(fake);
      await notifier.loadProfiles();
      notifier.assignProfile(0, original);

      final result = await notifier.updateProfile(
        existingId: '1',
        name: 'Alice Updated',
        colorValue: 0xFFB71C1C,
      );

      expect(result, isNotNull);
      expect(notifier.state.selectedProfiles[0]?.name, 'Alice Updated');
    });

    test('updateProfile does not affect unrelated slots', () async {
      final fake = _FakeProfileServiceAdapter();
      final p1 = Profile(id: '1', name: 'Alice');
      final p2 = Profile(id: '2', name: 'Bob');
      fake.profiles = [p1, p2];

      final notifier = _makeNotifier(fake);
      await notifier.loadProfiles();
      notifier.assignProfile(0, p1);
      notifier.assignProfile(1, p2);

      await notifier.updateProfile(
        existingId: '1',
        name: 'Alice Updated',
        colorValue: 0xFFB71C1C,
      );

      // Bob unchanged
      expect(notifier.state.selectedProfiles[1]?.name, 'Bob');
    });
  });
}

// --- Fake ProfileService que le notifier peut utiliser ---
// Comme ProfileService n'est pas abstract, on cree un wrapper testable.

class _FakeProfileServiceAdapter extends ProfileService {
  List<Profile> profiles = [];
  bool shouldThrow;

  _FakeProfileServiceAdapter({this.shouldThrow = false}) : super();

  @override
  Future<List<Profile>> loadProfiles() async {
    if (shouldThrow) throw Exception('Test error');
    return List.from(profiles);
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    if (shouldThrow) throw Exception('Test error');
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
  }

  @override
  Future<void> deleteProfile(String id) async {
    if (shouldThrow) throw Exception('Test error');
    profiles.removeWhere((p) => p.id == id);
  }
}
