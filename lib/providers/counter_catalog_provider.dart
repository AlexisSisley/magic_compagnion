// Fichier : lib/providers/counter_catalog_provider.dart
//
// Lot 5, tache 1 : catalogue des compteurs (integres + personnalises).
//
// Le plan proposait un FutureProvider<List<CounterType>>. Decision prise en
// amont (ne pas rouvrir) : c'est un Notifier avec un load() explicite,
// exposant une List<CounterType> synchrone. Raison : le principal
// consommateur est _openPlayerDrawer (life_counter_page.dart), une methode
// synchrone `void` appelee depuis un callback de geste -- y lire un
// FutureProvider obligerait a deballer un AsyncValue a chaque appel pour
// une liste qui ne change qu'a la creation d'un compteur. Meme motif que
// GameSetupNotifier.loadProfiles().
//
// `NotifierProvider` sans argument attend un constructeur sans argument
// (`CounterCatalogNotifier.new`) : `CounterTypeService` ne se passe donc
// pas au constructeur, il se lit dans `build()` via `ref.read`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/counter_type.dart';
import '../services/counter_type_service.dart';
import 'service_providers.dart';

class CounterCatalogNotifier extends Notifier<List<CounterType>> {
  late final CounterTypeService _service;

  @override
  List<CounterType> build() {
    _service = ref.read(counterTypeServiceProvider);
    // Synchrone : seuls les integres sont disponibles avant tout load().
    return List.unmodifiable(CounterType.builtInCounters);
  }

  /// Charge les compteurs personnalises depuis le service et les ajoute
  /// apres les integres. A appeler explicitement (typiquement a l'ouverture
  /// du tiroir joueur ou de l'ecran de gestion des compteurs).
  Future<void> load() async {
    final custom = await _service.loadCustomTypes();
    state = [...CounterType.builtInCounters, ...custom];
  }

  /// Point d'entree pour l'UI (ex. le dialogue de creation de compteur,
  /// tache 4) : sauvegarde [type] et recharge le catalogue.
  ///
  /// Ronde de correction 1 : `CounterTypeService.upsertCustomType` leve en
  /// interne (derniere ligne de defense) quand `type.id` usurpe un
  /// compteur integre -- un dialogue derive l'id du nom saisi, donc un
  /// joueur qui nomme son compteur "Poison" declenche ce cas depuis un
  /// simple `onPressed`. Cette methode ne laisse jamais cette exception
  /// remonter jusqu'a l'UI : elle l'attrape et rend un
  /// [CounterCatalogActionResult] en echec avec un message exploitable,
  /// sur le modele de `GameSetupNotifier.saveProfile` /
  /// `GameSetupActionResult`.
  ///
  /// Tache 4, ronde de correction 1 (Important) : refuse aussi -- SANS
  /// appeler le service -- un `type.id` qui usurpe un compteur
  /// PERSONNALISE deja existant (pas seulement un integre). Sans cette
  /// garde, deux compteurs personnalises nommes de facon a deriver le meme
  /// id (meme nom, deux noms qui se reduisent au meme slug) ecrasaient
  /// silencieusement l'identite visuelle complete du premier (nom, emoji,
  /// couleur, borne) -- aucune valeur numerique n'etait perdue, mais le
  /// premier compteur disparaissait sans un mot, exactement la degradation
  /// silencieuse que ce lot interdit.
  ///
  /// La garde vit ICI, au point d'entree UI, pas dans
  /// `CounterTypeService.upsertCustomType` : ce dernier reste un upsert
  /// generique par [id] (verrouille par
  /// `counter_type_service_test.dart`, "remplace au lieu d'ajouter"),
  /// utilisable par un futur appelant qui aurait reellement besoin de
  /// remplacer un compteur existant (ex. une edition, hors mandat de cette
  /// tache) -- seul CE point d'entree, celui que le dialogue de creation
  /// appelle, doit refuser la creation d'un homonyme plutot que
  /// l'appliquer en douce.
  Future<CounterCatalogActionResult> saveCustomType(CounterType type) async {
    final usurpsExistingCustom =
        state.any((c) => c.id == type.id && !c.isBuiltIn);
    if (usurpsExistingCustom) {
      return const CounterCatalogActionResult(
        success: false,
        message: 'Impossible de créer ce compteur : ce nom est déjà '
            'utilisé par un autre compteur personnalisé. Choisissez-en un '
            'autre.',
      );
    }
    try {
      await _service.upsertCustomType(type);
      await load();
      return const CounterCatalogActionResult(
        success: true,
        message: 'Compteur sauvegardé',
      );
    } on ArgumentError catch (e) {
      return CounterCatalogActionResult(
        success: false,
        message: 'Impossible de créer ce compteur : ${e.message}',
      );
    } catch (_) {
      return const CounterCatalogActionResult(
        success: false,
        message: 'Erreur inattendue lors de la sauvegarde du compteur',
      );
    }
  }
}

/// Resultat d'une action du catalogue de compteurs, rendu par l'UI plutot
/// que leve. Meme forme que `GameSetupActionResult`
/// (`lib/providers/game_setup_notifier.dart`), volontairement dupliquee ici
/// plutot que reutilisee : importer un type nomme "GameSetup..." depuis la
/// feature "compteurs" aurait couple deux features sans rapport pour un
/// simple `{success, message}` -- chaque Notifier de ce depot definit son
/// propre type de resultat d'action.
class CounterCatalogActionResult {
  final bool success;
  final String message;

  const CounterCatalogActionResult({
    this.success = true,
    this.message = '',
  });
}

final counterCatalogProvider =
    NotifierProvider<CounterCatalogNotifier, List<CounterType>>(
  CounterCatalogNotifier.new,
);

/// Resout un [id] de compteur en [CounterType], integre ou personnalise.
/// Rend `null` si aucun compteur du catalogue courant ne porte cet id.
final counterTypeByIdProvider = Provider.family<CounterType?, String>((ref, id) {
  final catalog = ref.watch(counterCatalogProvider);
  for (final type in catalog) {
    if (type.id == id) return type;
  }
  return null;
});
