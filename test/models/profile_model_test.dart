import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/profile_model.dart';

void main() {
  group('Profile', () {
    test('fromJson/toJson roundtrip', () {
      final json = {
        'id': 'p-1',
        'name': 'Alexis',
        'colorValue': 0xFF4CAF50,
        'commanderScryfallId': 'cmd-1',
        'commanderName': 'Atraxa',
        'commanderArtCropUrl': 'https://example.com/atraxa.jpg',
        'secondaryCommanderScryfallId': 'cmd-2',
        'secondaryCommanderName': 'Thrasios',
        'secondaryCommanderArtCropUrl': 'https://example.com/thrasios.jpg',
      };

      final profile = Profile.fromJson(json);
      expect(profile.id, 'p-1');
      expect(profile.name, 'Alexis');
      expect(profile.colorValue, 0xFF4CAF50);
      expect(profile.commanderScryfallId, 'cmd-1');
      expect(profile.commanderName, 'Atraxa');
      expect(profile.commanderArtCropUrl, 'https://example.com/atraxa.jpg');
      expect(profile.secondaryCommanderScryfallId, 'cmd-2');
      expect(profile.secondaryCommanderName, 'Thrasios');

      final output = profile.toJson();
      expect(output['id'], json['id']);
      expect(output['name'], json['name']);
      expect(output['colorValue'], json['colorValue']);
      expect(output['commanderScryfallId'], json['commanderScryfallId']);
      expect(output['secondaryCommanderScryfallId'], json['secondaryCommanderScryfallId']);
    });

    test('fromJson with default colorValue', () {
      final json = {
        'id': 'p-2',
        'name': 'Player 2',
      };

      final profile = Profile.fromJson(json);
      expect(profile.colorValue, 0xFF2196F3);
    });

    test('fromJson with null commander fields', () {
      final json = {
        'id': 'p-3',
        'name': 'No Commander',
        'commanderScryfallId': null,
        'commanderName': null,
        'commanderArtCropUrl': null,
        'secondaryCommanderScryfallId': null,
        'secondaryCommanderName': null,
        'secondaryCommanderArtCropUrl': null,
      };

      final profile = Profile.fromJson(json);
      expect(profile.commanderScryfallId, isNull);
      expect(profile.commanderName, isNull);
      expect(profile.commanderArtCropUrl, isNull);
      expect(profile.secondaryCommanderScryfallId, isNull);
    });

    test('commanderImageUrl returns artCropUrl when available', () {
      final profile = Profile(
        id: 'test',
        name: 'Test',
        commanderScryfallId: 'cmd-1',
        commanderArtCropUrl: 'https://direct-url.com/art.jpg',
      );

      expect(profile.commanderImageUrl, 'https://direct-url.com/art.jpg');
    });

    test('commanderImageUrl returns null when no commander', () {
      final profile = Profile(id: 'test', name: 'Test');
      expect(profile.commanderImageUrl, isNull);
    });

    test('secondaryCommanderImageUrl returns artCropUrl when available', () {
      final profile = Profile(
        id: 'test',
        name: 'Test',
        secondaryCommanderScryfallId: 'cmd-2',
        secondaryCommanderArtCropUrl: 'https://direct-url.com/art2.jpg',
      );

      expect(profile.secondaryCommanderImageUrl, 'https://direct-url.com/art2.jpg');
    });
  });
}
