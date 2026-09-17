// Fichier : lib/services/counter_type_service.dart
//
// Lot 5, tache 1 : persistance des compteurs personnalises crees par
// l'utilisateur. Meme forme que GameSessionService.loadLastTable() : une
// cle SharedPreferences, une liste JSON, et un chargement qui ne leve
// jamais -- une cle absente, un JSON illisible ou un enregistrement ecrit
// par une version future du modele rendent une liste vide plutot que de
// faire planter le demarrage de l'application.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/counter_type.dart';

class CounterTypeService {
  static const _key = 'custom_counter_types';

  /// Charge les compteurs personnalises. Ne leve jamais : cle absente,
  /// JSON invalide ou enregistrement incomplet (champ requis manquant)
  /// rendent tous une liste vide.
  Future<List<CounterType>> loadCustomTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list
          .map((e) => CounterType.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cree ou remplace (par [CounterType.id]) un compteur personnalise.
  ///
  /// Refuse -- sans rien ecrire -- un [type] dont l'id usurpe celui d'un
  /// compteur integre (`CounterType.builtInCounters`) : l'accepter
  /// donnerait deux entrees pour le meme id dans le catalogue, et le
  /// tiroir du joueur en afficherait une au hasard, de facon non
  /// deterministe.
  ///
  /// Ce refus leve `ArgumentError` : c'est une garde interne, la derniere
  /// ligne de defense du modele de donnees -- **pas** le mode de refus
  /// destine aux appelants UI. Un dialogue de creation qui derive l'id du
  /// nom saisi (tache 4 : pas de champ id) peut atteindre ce cas des qu'un
  /// joueur nomme son compteur "Poison". L'UI doit passer par
  /// `CounterCatalogNotifier.saveCustomType`
  /// (`lib/providers/counter_catalog_provider.dart`), qui attrape cette
  /// exception et rend un `CounterCatalogActionResult` en echec au lieu de
  /// la laisser remonter jusqu'a un `onPressed`.
  /// Le nom dit ce qu'elle fait : un **upsert** brut, qui ecrase sans
  /// prevenir un type personnalise de meme id. Ce n'est pas un point
  /// d'entree sur pour l'interface, et le nom est la pour que personne ne
  /// s'y trompe en ajoutant un second appelant sans lire ce commentaire :
  /// la garde contre l'ecrasement d'un homonyme vit au notifier, pas ici.
  Future<void> upsertCustomType(CounterType type) async {
    final isBuiltInId =
        CounterType.builtInCounters.any((builtIn) => builtIn.id == type.id);
    if (isBuiltInId) {
      // Revue finale (I1) : ce message atteint bien l'écran (via la
      // SnackBar de `CounterCatalogNotifier.saveCustomType`), malgré le
      // statut de garde interne documenté ci-dessus -- "usurper l'id" ne
      // veut rien dire pour un joueur (aucun champ id dans le dialogue de
      // création) et ne lui dit pas quoi faire. Formulé pour lui, pas pour
      // le modèle.
      throw ArgumentError.value(
        type.id,
        'type.id',
        'Ce nom est déjà utilisé par un compteur intégré. Choisissez-en un autre.',
      );
    }

    final types = await loadCustomTypes();
    final index = types.indexWhere((t) => t.id == type.id);
    if (index != -1) {
      types[index] = type;
    } else {
      types.add(type);
    }
    await _saveList(types);
  }

  /// Retire le compteur personnalise [id]. Ne leve pas si [id] est absent.
  Future<void> deleteCustomType(String id) async {
    final types = await loadCustomTypes();
    types.removeWhere((t) => t.id == id);
    await _saveList(types);
  }

  Future<void> _saveList(List<CounterType> types) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(types.map((t) => t.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
