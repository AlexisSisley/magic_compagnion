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
