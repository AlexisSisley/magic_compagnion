// Fichier : lib/services/deck_view_prefs.dart
// Préférences d'affichage de la liste d'un deck, mémorisées par deck : chaque
// deck se rouvre comme on l'a laissé.

import 'dart:convert';

import '../data/database/app_database.dart';

/// Regroupement des sections de la liste. Par type par défaut : c'est la
/// lecture la plus familière d'une liste de deck. Par tag, une section par tag
/// principal. Un deck qui avait mémorisé « Catégorie » (`category`) se rouvre
/// par tag.
enum DeckGrouping { tag, type }

/// Présentation des cartes : grille d'artworks (défaut) ou liste compacte.
enum DeckLayout { grid, list }

class DeckViewPrefs {
  final DeckGrouping grouping;
  final DeckLayout layout;

  const DeckViewPrefs({
    this.grouping = DeckGrouping.type,
    this.layout = DeckLayout.grid,
  });

  DeckViewPrefs copyWith({DeckGrouping? grouping, DeckLayout? layout}) =>
      DeckViewPrefs(
        grouping: grouping ?? this.grouping,
        layout: layout ?? this.layout,
      );

  Map<String, dynamic> toJson() => {
    'grouping': grouping.name,
    'layout': layout.name,
  };

  @override
  bool operator ==(Object other) =>
      other is DeckViewPrefs &&
      other.grouping == grouping &&
      other.layout == layout;

  @override
  int get hashCode => Object.hash(grouping, layout);
}

const String _keyPrefix = 'deck_view:';

String _key(String deckId) => '$_keyPrefix$deckId';

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Lit les préférences d'un deck. Une valeur absente ou illisible (JSON
/// corrompu, valeur d'une version future) rend les défauts plutôt qu'une
/// erreur : ouvrir le deck prime sur la mémoire de son affichage.
Future<DeckViewPrefs> loadDeckViewPrefs(AppDatabase db, String deckId) async {
  const defaults = DeckViewPrefs();
  final raw = await db.getSetting(_key(deckId));
  if (raw == null) return defaults;
  try {
    final decoded = json.decode(raw);
    if (decoded is! Map) return defaults;
    return DeckViewPrefs(
      grouping: decoded['grouping'] == 'category'
          ? DeckGrouping.tag
          : _byName(DeckGrouping.values, decoded['grouping'], defaults.grouping),
      layout: _byName(DeckLayout.values, decoded['layout'], defaults.layout),
    );
  } on FormatException {
    return defaults;
  }
}

Future<void> saveDeckViewPrefs(
  AppDatabase db,
  String deckId,
  DeckViewPrefs prefs,
) {
  return db.setSetting(_key(deckId), json.encode(prefs.toJson()));
}

/// Efface les préférences de tous les decks, par exemple quand une restauration
/// remplace la bibliothèque : les identifiants de l'ancienne ne reviennent pas.
Future<void> deleteAllDeckViewPrefs(AppDatabase db) {
  return db.deleteSettingsWithPrefix(_keyPrefix);
}

/// Efface les préférences d'un deck supprimé, pour ne pas laisser de clé
/// orpheline dans les réglages.
Future<void> deleteDeckViewPrefs(AppDatabase db, String deckId) {
  return db.deleteSetting(_key(deckId));
}
