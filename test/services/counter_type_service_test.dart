// test/services/counter_type_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/services/counter_type_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CounterTypeService', () {
    test('upsertCustomType puis loadCustomTypes conserve id/name/emoji/color/maxValue (maxValue non nul)', () async {
      final service = CounterTypeService();
      const type = CounterType(
        id: 'custom_shield',
        name: 'Shield',
        emoji: '🛡️',
        color: 0xFF2196F3,
        maxValue: 20,
      );

      await service.upsertCustomType(type);
      final loaded = await service.loadCustomTypes();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'custom_shield');
      expect(loaded.single.name, 'Shield');
      expect(loaded.single.emoji, '🛡️');
      expect(loaded.single.color, 0xFF2196F3);
      expect(loaded.single.maxValue, 20);
    });

    test('upsertCustomType puis loadCustomTypes conserve un maxValue nul (illimite)', () async {
      final service = CounterTypeService();
      const type = CounterType(
        id: 'custom_loyalty',
        name: 'Loyalty',
        emoji: '🌀',
        color: 0xFF9C27B0,
        maxValue: null,
      );

      await service.upsertCustomType(type);
      final loaded = await service.loadCustomTypes();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'custom_loyalty');
      expect(loaded.single.maxValue, isNull);
    });

    test('upsertCustomType deux fois avec le meme id remplace au lieu d\'ajouter', () async {
      final service = CounterTypeService();
      const original = CounterType(
        id: 'custom_shield',
        name: 'Shield',
        emoji: '🛡️',
        color: 0xFF2196F3,
        maxValue: 20,
      );
      const updated = CounterType(
        id: 'custom_shield',
        name: 'Shield Plus',
        emoji: '🛡️',
        color: 0xFF00FF00,
        maxValue: 30,
      );

      await service.upsertCustomType(original);
      await service.upsertCustomType(updated);
      final loaded = await service.loadCustomTypes();

      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'Shield Plus');
      expect(loaded.single.maxValue, 30);
    });

    test('deleteCustomType retire le type', () async {
      final service = CounterTypeService();
      const type = CounterType(
        id: 'custom_shield',
        name: 'Shield',
        emoji: '🛡️',
        color: 0xFF2196F3,
        maxValue: 20,
      );
      await service.upsertCustomType(type);

      await service.deleteCustomType('custom_shield');
      final loaded = await service.loadCustomTypes();

      expect(loaded, isEmpty);
    });

    test('deleteCustomType sur un id absent ne leve pas', () async {
      final service = CounterTypeService();
      await expectLater(service.deleteCustomType('does_not_exist'), completes);
      expect(await service.loadCustomTypes(), isEmpty);
    });

    test('loadCustomTypes rend une liste vide quand la cle est absente', () async {
      final service = CounterTypeService();
      expect(await service.loadCustomTypes(), isEmpty);
    });

    test('loadCustomTypes rend une liste vide sur JSON invalide, sans lever', () async {
      SharedPreferences.setMockInitialValues({
        'custom_counter_types': 'not valid json {{{',
      });
      final service = CounterTypeService();

      final loaded = await service.loadCustomTypes();

      expect(loaded, isEmpty);
    });

    test('loadCustomTypes rend une liste vide sur JSON valide auquel il manque un champ requis, sans lever', () async {
      // JSON syntaxiquement valide (une liste avec un objet), mais 'id'
      // (champ requis par CounterType.fromJson) est absent.
      SharedPreferences.setMockInitialValues({
        'custom_counter_types': '[{"name": "Broken", "emoji": "?", "color": 0}]',
      });
      final service = CounterTypeService();

      final loaded = await service.loadCustomTypes();

      expect(loaded, isEmpty);
    });

    test('upsertCustomType avec l\'id d\'un integre est refuse', () async {
      final service = CounterTypeService();
      const impostor = CounterType(
        id: 'poison',
        name: 'Fake Poison',
        emoji: '💀',
        color: 0xFF000000,
        maxValue: 999,
      );

      await expectLater(service.upsertCustomType(impostor), throwsArgumentError);

      // Le catalogue de types personnalises ne contient toujours rien : le
      // refus n'a pas ete silencieusement accepte.
      expect(await service.loadCustomTypes(), isEmpty);
    });

    test('upsertCustomType refuse chacun des quatre ids integres', () async {
      final service = CounterTypeService();
      for (final builtIn in CounterType.builtInCounters) {
        final impostor = CounterType(
          id: builtIn.id,
          name: 'Impostor',
          emoji: '❓',
          color: 0xFF123456,
        );
        await expectLater(
          service.upsertCustomType(impostor),
          throwsArgumentError,
          reason: 'id integre usurpe : ${builtIn.id}',
        );
      }
      expect(await service.loadCustomTypes(), isEmpty);
    });
  });
}
