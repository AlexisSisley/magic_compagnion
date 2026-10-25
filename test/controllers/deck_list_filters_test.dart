import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_list_filters.dart';
import 'package:magic_companion/models/deck_model.dart';

Deck _deck(
  String id,
  String name, {
  String format = 'Standard',
  List<String> colors = const [],
  List<String> tags = const [],
  DateTime? updatedAt,
  int cards = 0,
}) {
  return Deck(
    id: id,
    name: name,
    format: format,
    colors: [...colors],
    tags: [...tags],
    updatedAt: updatedAt,
    mainboard: cards == 0
        ? []
        : [DeckCard(scryfallId: 's$id', name: 'c$id', quantity: cards)],
  );
}

List<String> _ids(List<Deck> d) => d.map((e) => e.id).toList();

void main() {
  group('applyDeckFilters', () {
    test('recherche : sous-chaine du nom, insensible a la casse', () {
      final decks = [_deck('1', 'Goblins'), _deck('2', 'Elfes')];
      final r = applyDeckFilters(
          decks, {}, const DeckFilterCriteria(query: 'GOB'));
      expect(_ids(r), ['1']);
    });

    test('format : egalite insensible a la casse avec deck.format', () {
      final decks = [
        _deck('1', 'A', format: 'Commander'),
        _deck('2', 'B', format: 'Standard'),
      ];
      final r = applyDeckFilters(
          decks, {}, const DeckFilterCriteria(format: 'commander'));
      expect(_ids(r), ['1']);
    });

    test('format : un commandant ne suffit pas a passer le filtre', () {
      final d = _deck('1', 'A', format: 'Standard')
        ..commanderScryfallId = 'x';
      final r = applyDeckFilters(
          [d], {}, const DeckFilterCriteria(format: 'Commander'));
      expect(r, isEmpty);
    });

    test('identite : egalite exacte d\'ensembles, vide = incolore', () {
      final decks = [
        _deck('1', 'A', colors: ['R', 'G']),
        _deck('2', 'B', colors: ['R']),
        _deck('3', 'C'),
      ];
      expect(
          _ids(applyDeckFilters(decks, {},
              const DeckFilterCriteria(identityColors: ['G', 'R']))),
          ['1']);
      expect(
          _ids(applyDeckFilters(
              decks, {}, const DeckFilterCriteria(identityColors: []))),
          ['3']);
    });

    test('tags : au moins un des tags selectionnes', () {
      final decks = [
        _deck('1', 'A', tags: ['X']),
        _deck('2', 'B', tags: ['Y']),
        _deck('3', 'C', tags: ['Z']),
        _deck('4', 'D'),
      ];
      final r = applyDeckFilters(
          decks, {}, const DeckFilterCriteria(tags: ['X', 'Y']));
      expect(_ids(r), ['1', '2']);
    });

    test('prix : bornes incluses, deck absent de prices vaut 0', () {
      final decks = [_deck('1', 'A'), _deck('2', 'B'), _deck('3', 'C'),
        _deck('4', 'D')];
      final prices = {'1': 10.0, '2': 20.0, '3': 30.0};
      expect(
          _ids(applyDeckFilters(decks, prices,
              const DeckFilterCriteria(priceRange: (10, 20)))),
          ['1', '2']);
      expect(
          _ids(applyDeckFilters(decks, prices,
              const DeckFilterCriteria(priceRange: (0, 15)))),
          ['1', '4']);
      expect(
          _ids(applyDeckFilters(decks, prices,
              const DeckFilterCriteria(priceRange: (5, 15)))),
          ['1']);
    });

    test('tri nom : insensible a la casse', () {
      final decks = [_deck('1', 'beta'), _deck('2', 'Alpha'), _deck('3', 'Gamma')];
      expect(_ids(applyDeckFilters(decks, {}, const DeckFilterCriteria())),
          ['2', '1', '3']);
    });

    test('tri prix decroissant et croissant', () {
      final decks = [_deck('1', 'A'), _deck('2', 'B'), _deck('3', 'C')];
      final prices = {'1': 20.0, '2': 10.0, '3': 30.0};
      expect(
          _ids(applyDeckFilters(decks, prices,
              const DeckFilterCriteria(sort: DeckSort.priceDesc))),
          ['3', '1', '2']);
      expect(
          _ids(applyDeckFilters(decks, prices,
              const DeckFilterCriteria(sort: DeckSort.priceAsc))),
          ['2', '1', '3']);
    });

    test('tri modifie : recent d\'abord, null en fin, ex aequo par nom', () {
      final t = DateTime(2026, 1, 1);
      final decks = [
        _deck('1', 'Zed'),
        _deck('2', 'Old', updatedAt: DateTime(2025, 1, 1)),
        _deck('3', 'Beta', updatedAt: t),
        _deck('4', 'Alpha', updatedAt: t),
        _deck('5', 'Abel'),
      ];
      expect(
          _ids(applyDeckFilters(
              decks, {}, const DeckFilterCriteria(sort: DeckSort.updated))),
          ['4', '3', '2', '5', '1']);
    });

    test('tri nombre de cartes : somme des quantites, ex aequo par nom', () {
      final decks = [
        _deck('1', 'B', cards: 60),
        _deck('2', 'A', cards: 60),
        _deck('3', 'C', cards: 100),
        _deck('4', 'D', cards: 10),
      ];
      expect(
          _ids(applyDeckFilters(decks, {},
              const DeckFilterCriteria(sort: DeckSort.cardCount))),
          ['3', '2', '1', '4']);
    });
  });

  group('deckSortLabel', () {
    test('libelles', () {
      expect(DeckSort.values.map(deckSortLabel).toList(), [
        'Nom (A-Z)',
        'Prix décroissant',
        'Prix croissant',
        'Modifié récemment',
        'Nombre de cartes',
      ]);
    });
  });

  group('activeFilterCount', () {
    test('0 au depart, recherche et tri ne comptent pas', () {
      expect(activeFilterCount(const DeckFilterCriteria()), 0);
      expect(
          activeFilterCount(const DeckFilterCriteria(
              query: 'x', sort: DeckSort.priceAsc)),
          0);
    });

    test('format + 2 tags + prix = 3', () {
      expect(
          activeFilterCount(const DeckFilterCriteria(
              format: 'Commander',
              tags: ['A', 'B'],
              priceRange: (0, 10))),
          3);
    });

    test('l\'identite compte, y compris incolore', () {
      expect(
          activeFilterCount(const DeckFilterCriteria(identityColors: [])), 1);
    });
  });

  group('pruneSelectedTags', () {
    test('retire les tags qu\'aucun deck ne porte', () {
      final decks = [_deck('1', 'A', tags: ['A'])];
      expect(pruneSelectedTags(['A', 'B'], decks), ['A']);
    });
  });
}
