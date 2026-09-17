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
    await service.upsertCustomType(shield);
    await service.upsertCustomType(loyalty);

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

    // Tâche 4, ronde de correction 1 (Important) : jusqu'ici, nommer deux
    // compteurs PERSONNALISÉS de façon à dériver le même id (même nom, ou
    // deux noms qui se réduisent au même slug) écrasait silencieusement le
    // premier -- CounterTypeService.saveCustomType fait un upsert par
    // conception (voir counter_type_service_test.dart, "remplace au lieu
    // d'ajouter", verrouillé côté service et volontairement inchangé
    // ci-dessous). Rien ne se perdait en VALEUR numérique, mais toute
    // l'identité visuelle du premier (nom, emoji, couleur, borne) partait
    // sans un mot -- exactement le genre de dégradation silencieuse que ce
    // lot interdit. La garde vit ici, au point d'entrée UI, pas dans le
    // service : c'est ce point d'entrée-ci que le dialogue de création
    // (tâche 4) appelle, et le service reste un upsert générique pour
    // d'éventuels futurs appelants qui en auraient besoin (ex. une édition).
    test(
        'un second saveCustomType avec le même id qu\'un personnalisé '
        'existant est refusé -- sans cette garde, l\'écrasement silencieux '
        'remplacerait nom/emoji/couleur/borne du premier sans un mot',
        () async {
      const original = CounterType(
        id: 'custom_shield',
        name: 'Bouclier',
        emoji: '🛡️',
        color: 0xFF2196F3,
        maxValue: 20,
      );
      const impostor = CounterType(
        id: 'custom_shield',
        name: 'Autre Nom',
        emoji: '🔥',
        color: 0xFF000000,
        maxValue: 5,
      );

      final firstResult = await getNotifier().saveCustomType(original);
      expect(firstResult.success, isTrue);

      final secondResult = await getNotifier().saveCustomType(impostor);

      expect(secondResult.success, isFalse);
      expect(secondResult.message, isNotEmpty);

      final catalog = container.read(counterCatalogProvider);
      expect(catalog.where((c) => c.id == 'custom_shield'), hasLength(1),
          reason: 'toujours une seule entrée pour cet id -- ni doublon ni '
              'suppression');
      final entry =
          catalog.firstWhere((c) => c.id == 'custom_shield');
      // Preuve de discriminance : nom, emoji, couleur ET borne du PREMIER
      // sont intacts -- pas seulement son id ou le nombre d'entrées. Un
      // correctif qui se contenterait de bloquer l'ajout d'une DEUXIÈME
      // entrée (sans empêcher le remplacement de la première) laisserait
      // ces quatre champs changer silencieusement.
      expect(entry.name, 'Bouclier');
      expect(entry.emoji, '🛡️');
      expect(entry.color, 0xFF2196F3);
      expect(entry.maxValue, 20);
    });

    test(
        'le refus d\'un homonyme personnalisé n\'affecte pas la création '
        'd\'un compteur avec un id réellement différent', () async {
      const original = CounterType(
        id: 'custom_shield',
        name: 'Bouclier',
        emoji: '🛡️',
        color: 0xFF2196F3,
      );
      const other = CounterType(
        id: 'custom_loyalty',
        name: 'Loyauté',
        emoji: '🌀',
        color: 0xFF9C27B0,
      );

      await getNotifier().saveCustomType(original);
      final result = await getNotifier().saveCustomType(other);

      expect(result.success, isTrue);
      final catalog = container.read(counterCatalogProvider);
      expect(catalog.map((c) => c.id),
          containsAll(['custom_shield', 'custom_loyalty']));
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
      await service.upsertCustomType(shield);
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
