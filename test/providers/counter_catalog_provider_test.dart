// test/providers/counter_catalog_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/providers/counter_catalog_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/counter_type_service.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  CounterCatalogNotifier getNotifier() =>
      container.read(counterCatalogProvider.notifier);

  test('counterTypeServiceProvider expose bien un CounterTypeService', () {
    expect(container.read(counterTypeServiceProvider), isA<CounterTypeService>());
  });

  test('build() rend synchroniquement les quatre integres, dans l\'ordre, avant tout load()', () {
    final catalog = container.read(counterCatalogProvider);

    expect(catalog, hasLength(4));
    expect(catalog.map((c) => c.id).toList(), [
      'poison',
      'energy',
      'commander_tax',
      'commander_damage',
    ]);
  });

  test('load() ajoute les personnalises apres les integres, sans en perdre aucun', () async {
    final service = container.read(counterTypeServiceProvider);
    const shield = CounterType(
      id: 'custom_shield',
      name: 'Shield',
      emoji: '🛡️',
      color: 0xFF2196F3,
      maxValue: 20,
    );
    const loyalty = CounterType(
      id: 'custom_loyalty',
      name: 'Loyalty',
      emoji: '🌀',
      color: 0xFF9C27B0,
      maxValue: null,
    );
    await service.saveCustomType(shield);
    await service.saveCustomType(loyalty);

    await getNotifier().load();
    final catalog = container.read(counterCatalogProvider);

    // Preuve de discriminance : on verifie l'IDENTITE de chaque entree
    // (id -> proprietes), pas seulement le nombre total. Un catalogue qui
    // aurait remplace un integre par un personnalise resterait a 6 entrees
    // avec un test qui ne compte que hasLength(6).
    expect(catalog, hasLength(6));
    expect(catalog.map((c) => c.id).toList(), [
      'poison',
      'energy',
      'commander_tax',
      'commander_damage',
      'custom_shield',
      'custom_loyalty',
    ]);
    final builtInPoison = catalog.firstWhere((c) => c.id == 'poison');
    expect(builtInPoison.isBuiltIn, isTrue);
    expect(builtInPoison.maxValue, 10);
    final customShield = catalog.firstWhere((c) => c.id == 'custom_shield');
    expect(customShield.isBuiltIn, isFalse);
    expect(customShield.maxValue, 20);
    final customLoyalty = catalog.firstWhere((c) => c.id == 'custom_loyalty');
    expect(customLoyalty.maxValue, isNull);
  });

  test('load() ne duplique pas les integres quand aucun personnalise n\'existe', () async {
    await getNotifier().load();
    final catalog = container.read(counterCatalogProvider);

    expect(catalog, hasLength(4));
  });

  group('saveCustomType (point d\'entree UI, ne leve jamais)', () {
    test('cree un compteur personnalise, rend un succes, et le catalogue le reflete', () async {
      const shield = CounterType(
        id: 'custom_shield',
        name: 'Shield',
        emoji: '🛡️',
        color: 0xFF2196F3,
        maxValue: 20,
      );

      final result = await getNotifier().saveCustomType(shield);

      expect(result.success, isTrue);
      expect(result.message, isNotEmpty);
      final catalog = container.read(counterCatalogProvider);
      expect(catalog.map((c) => c.id).toList(), [
        'poison',
        'energy',
        'commander_tax',
        'commander_damage',
        'custom_shield',
      ]);
    });

    test(
        'ronde de correction 1 : nommer un compteur "Poison" (id derive '
        'usurpant un integre) rend un echec avec un message non vide, '
        'sans lever, et laisse le catalogue inchange', () async {
      final beforeIds =
          container.read(counterCatalogProvider).map((c) => c.id).toList();

      // Meme id que le compteur poison integre : c'est ce que produirait le
      // dialogue de creation (tache 4, pas de champ id, derive du nom) si un
      // joueur nomme son compteur personnalise "Poison".
      const impostor = CounterType(
        id: 'poison',
        name: 'Poison',
        emoji: '☠️',
        color: 0xFF000000,
        maxValue: 999,
      );

      final result = await getNotifier().saveCustomType(impostor);

      expect(result.success, isFalse);
      expect(result.message, isNotEmpty);

      // Preuve de discriminance : meme LONGUEUR et meme SEQUENCE d'ids
      // qu'avant la tentative -- pas seulement le compte, sinon un
      // remplacement silencieux de "poison" par l'usurpateur passerait.
      final afterIds =
          container.read(counterCatalogProvider).map((c) => c.id).toList();
      expect(afterIds, beforeIds);
      expect(afterIds, hasLength(4));
    });
  });

  group('resolution id -> CounterType', () {
    test('resout un id integre', () {
      final resolved = container.read(counterTypeByIdProvider('poison'));
      expect(resolved, isNotNull);
      expect(resolved!.name, 'Poison');
    });

    test('resout un id personnalise apres load()', () async {
      final service = container.read(counterTypeServiceProvider);
      const shield = CounterType(
        id: 'custom_shield',
        name: 'Shield',
        emoji: '🛡️',
        color: 0xFF2196F3,
        maxValue: 20,
      );
      await service.saveCustomType(shield);
      await getNotifier().load();

      final resolved = container.read(counterTypeByIdProvider('custom_shield'));
      expect(resolved, isNotNull);
      expect(resolved!.name, 'Shield');
    });

    test('rend null pour un id inconnu', () {
      final resolved = container.read(counterTypeByIdProvider('does_not_exist'));
      expect(resolved, isNull);
    });
  });
}
