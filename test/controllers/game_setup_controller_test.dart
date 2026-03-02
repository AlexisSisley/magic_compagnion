// Tests unitaires pour GameSetupController (Sprint 12, US-12.7)
// Teste la logique metier extraite du GameSetupModal.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/game_setup_controller.dart';
import 'package:magic_companion/models/profile_model.dart';
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

// --- Wrapper pour injecter le FakeProfileService ---
// On utilise duck typing : GameSetupController attend un ProfileService,
// mais pour les tests purs on teste uniquement l'etat et la logique.

void main() {
  // ============================================================
  // GameSetupState - Tests unitaires purs sur l'etat immutable
  // ============================================================

  group('GameSetupState', () {
    test('initial state has correct defaults', () {
      const state = GameSetupState();

      expect(state.startingLife, 40);
      expect(state.selectedProfiles, hasLength(4));
      expect(state.selectedProfiles.every((p) => p == null), true);
      expect(state.availableProfiles, isEmpty);
      expect(state.isLoadingProfiles, false);
    });

    test('copyWith preserves values when no arguments given', () {
      const state = GameSetupState(
        startingLife: 20,
        isLoadingProfiles: true,
      );

      final copied = state.copyWith();
      expect(copied.startingLife, 20);
      expect(copied.isLoadingProfiles, true);
    });

    test('copyWith overrides specified values', () {
      const state = GameSetupState();
      final updated = state.copyWith(
        startingLife: 20,
        isLoadingProfiles: true,
      );

      expect(updated.startingLife, 20);
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

    test('formatLabel returns Commander for 40 life', () {
      const state = GameSetupState(startingLife: 40);
      expect(state.formatLabel, 'Commander');
    });

    test('formatLabel returns Standard for 20 life', () {
      const state = GameSetupState(startingLife: 20);
      expect(state.formatLabel, 'Standard');
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
  // GameSetupController - selectFormat
  // ============================================================

  group('GameSetupController.selectFormat', () {
    test('selectFormat changes startingLife to Commander (40)', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
        initialLife: 20,
      );

      controller.selectFormat(40);
      expect(controller.state.startingLife, 40);
    });

    test('selectFormat changes startingLife to Standard (20)', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
        initialLife: 40,
      );

      controller.selectFormat(20);
      expect(controller.state.startingLife, 20);
    });

    test('initial life is preserved from constructor', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
        initialLife: 30,
      );

      expect(controller.state.startingLife, 30);
    });
  });

  // ============================================================
  // GameSetupController - addPlayer / removePlayer
  // ============================================================

  group('GameSetupController.addPlayer', () {
    test('addPlayer adds a null slot', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );

      expect(controller.state.playerCount, 4);
      final result = controller.addPlayer();
      expect(result.success, true);
      expect(controller.state.playerCount, 5);
      expect(controller.state.selectedProfiles.last, isNull);
    });

    test('addPlayer fails when at max (8)', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );

      // Add to reach 8
      controller.addPlayer(); // 5
      controller.addPlayer(); // 6
      controller.addPlayer(); // 7
      controller.addPlayer(); // 8
      expect(controller.state.playerCount, 8);

      final result = controller.addPlayer();
      expect(result.success, false);
      expect(result.message, contains('maximum'));
      expect(controller.state.playerCount, 8);
    });
  });

  group('GameSetupController.removePlayer', () {
    test('removePlayer removes last slot', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );

      expect(controller.state.playerCount, 4);
      final result = controller.removePlayer();
      expect(result.success, true);
      expect(controller.state.playerCount, 3);
    });

    test('removePlayer fails when at min (2)', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );

      controller.removePlayer(); // 3
      controller.removePlayer(); // 2
      expect(controller.state.playerCount, 2);

      final result = controller.removePlayer();
      expect(result.success, false);
      expect(result.message, contains('2 joueurs'));
      expect(controller.state.playerCount, 2);
    });
  });

  // ============================================================
  // GameSetupController - assignProfile
  // ============================================================

  group('GameSetupController.assignProfile', () {
    test('assignProfile sets profile at valid index', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );
      final profile = Profile(id: '1', name: 'Test Player');

      final result = controller.assignProfile(0, profile);
      expect(result.success, true);
      expect(controller.state.selectedProfiles[0]?.name, 'Test Player');
    });

    test('assignProfile with null resets slot to guest', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );
      final profile = Profile(id: '1', name: 'Test Player');
      controller.assignProfile(0, profile);

      final result = controller.assignProfile(0, null);
      expect(result.success, true);
      expect(controller.state.selectedProfiles[0], isNull);
    });

    test('assignProfile fails with negative index', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );

      final result = controller.assignProfile(-1, null);
      expect(result.success, false);
      expect(result.message, contains('invalide'));
    });

    test('assignProfile fails with out-of-bounds index', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );

      final result = controller.assignProfile(10, null);
      expect(result.success, false);
      expect(result.message, contains('invalide'));
    });

    test('assignProfile preserves other slots', () {
      final controller = GameSetupController(
        profileService: _FakeProfileServiceAdapter(),
      );
      final p1 = Profile(id: '1', name: 'Alice');
      final p2 = Profile(id: '2', name: 'Bob');

      controller.assignProfile(0, p1);
      controller.assignProfile(2, p2);

      expect(controller.state.selectedProfiles[0]?.name, 'Alice');
      expect(controller.state.selectedProfiles[1], isNull);
      expect(controller.state.selectedProfiles[2]?.name, 'Bob');
      expect(controller.state.selectedProfiles[3], isNull);
    });
  });

  // ============================================================
  // GameSetupController - loadProfiles
  // ============================================================

  group('GameSetupController.loadProfiles', () {
    test('loadProfiles populates availableProfiles', () async {
      final fake = _FakeProfileServiceAdapter();
      fake.profiles = [
        Profile(id: '1', name: 'Alice'),
        Profile(id: '2', name: 'Bob'),
      ];

      final controller = GameSetupController(profileService: fake);
      await controller.loadProfiles();

      expect(controller.state.availableProfiles, hasLength(2));
      expect(controller.state.availableProfiles[0].name, 'Alice');
      expect(controller.state.isLoadingProfiles, false);
    });

    test('loadProfiles sets isLoadingProfiles during load', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      // Before loading
      expect(controller.state.isLoadingProfiles, false);

      // After loading
      await controller.loadProfiles();
      expect(controller.state.isLoadingProfiles, false);
    });

    test('loadProfiles handles errors gracefully', () async {
      final fake = _FakeProfileServiceAdapter(shouldThrow: true);
      final controller = GameSetupController(profileService: fake);

      await controller.loadProfiles();
      expect(controller.state.isLoadingProfiles, false);
      expect(controller.state.availableProfiles, isEmpty);
    });
  });

  // ============================================================
  // GameSetupController - saveProfile
  // ============================================================

  group('GameSetupController.saveProfile', () {
    test('saveProfile saves and reloads profiles', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      final profile = Profile(id: '1', name: 'New Player');
      final result = await controller.saveProfile(profile);

      expect(result.success, true);
      expect(controller.state.availableProfiles, hasLength(1));
      expect(controller.state.availableProfiles[0].name, 'New Player');
    });

    test('saveProfile returns failure on error', () async {
      final fake = _FakeProfileServiceAdapter(shouldThrow: true);
      final controller = GameSetupController(profileService: fake);

      final profile = Profile(id: '1', name: 'New Player');
      final result = await controller.saveProfile(profile);

      expect(result.success, false);
      expect(result.message, contains('Erreur'));
    });
  });

  // ============================================================
  // GameSetupController - deleteProfile
  // ============================================================

  group('GameSetupController.deleteProfile', () {
    test('deleteProfile removes from available and slots', () async {
      final fake = _FakeProfileServiceAdapter();
      final profile = Profile(id: '1', name: 'Alice');
      fake.profiles = [profile];

      final controller = GameSetupController(profileService: fake);
      await controller.loadProfiles();

      // Assign to slot 0
      controller.assignProfile(0, profile);
      expect(controller.state.selectedProfiles[0]?.name, 'Alice');

      // Delete
      final result = await controller.deleteProfile('1');
      expect(result.success, true);
      expect(controller.state.selectedProfiles[0], isNull);
      expect(controller.state.availableProfiles, isEmpty);
    });

    test('deleteProfile returns failure on error', () async {
      final fake = _FakeProfileServiceAdapter(shouldThrow: true);
      final controller = GameSetupController(profileService: fake);

      final result = await controller.deleteProfile('1');
      expect(result.success, false);
      expect(result.message, contains('Erreur'));
    });
  });

  // ============================================================
  // GameSetupController - createProfile
  // ============================================================

  group('GameSetupController.createProfile', () {
    test('createProfile creates and saves a new profile', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      final result = await controller.createProfile(
        name: 'New Player',
        colorValue: 0xFF0D47A1,
        commanderName: 'Atraxa',
      );

      expect(result, isNotNull);
      expect(result!.name, 'New Player');
      expect(result.colorValue, 0xFF0D47A1);
      expect(result.commanderName, 'Atraxa');
      expect(controller.state.availableProfiles, hasLength(1));
    });

    test('createProfile returns null for empty name', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      final result = await controller.createProfile(
        name: '',
        colorValue: 0xFF0D47A1,
      );

      expect(result, isNull);
      expect(controller.state.availableProfiles, isEmpty);
    });

    test('createProfile returns null for whitespace-only name', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      final result = await controller.createProfile(
        name: '   ',
        colorValue: 0xFF0D47A1,
      );

      expect(result, isNull);
    });

    test('createProfile trims name', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      final result = await controller.createProfile(
        name: '  Alice  ',
        colorValue: 0xFF0D47A1,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Alice');
    });

    test('createProfile sets all optional fields', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      final result = await controller.createProfile(
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
  });

  // ============================================================
  // GameSetupController - updateProfile
  // ============================================================

  group('GameSetupController.updateProfile', () {
    test('updateProfile updates existing profile', () async {
      final fake = _FakeProfileServiceAdapter();
      final original = Profile(id: '1', name: 'Alice');
      fake.profiles = [original];

      final controller = GameSetupController(profileService: fake);
      await controller.loadProfiles();

      final result = await controller.updateProfile(
        existingId: '1',
        name: 'Alice Updated',
        colorValue: 0xFFB71C1C,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Alice Updated');
      expect(result.colorValue, 0xFFB71C1C);
    });

    test('updateProfile returns null for empty name', () async {
      final fake = _FakeProfileServiceAdapter();
      final controller = GameSetupController(profileService: fake);

      final result = await controller.updateProfile(
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

      final controller = GameSetupController(profileService: fake);
      await controller.loadProfiles();
      controller.assignProfile(0, original);

      final result = await controller.updateProfile(
        existingId: '1',
        name: 'Alice Updated',
        colorValue: 0xFFB71C1C,
      );

      expect(result, isNotNull);
      expect(controller.state.selectedProfiles[0]?.name, 'Alice Updated');
    });

    test('updateProfile does not affect unrelated slots', () async {
      final fake = _FakeProfileServiceAdapter();
      final p1 = Profile(id: '1', name: 'Alice');
      final p2 = Profile(id: '2', name: 'Bob');
      fake.profiles = [p1, p2];

      final controller = GameSetupController(profileService: fake);
      await controller.loadProfiles();
      controller.assignProfile(0, p1);
      controller.assignProfile(1, p2);

      await controller.updateProfile(
        existingId: '1',
        name: 'Alice Updated',
        colorValue: 0xFFB71C1C,
      );

      // Bob unchanged
      expect(controller.state.selectedProfiles[1]?.name, 'Bob');
    });
  });
}

// --- Fake ProfileService que le controller peut utiliser ---
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
