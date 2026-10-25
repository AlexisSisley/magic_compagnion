import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/card_tag.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/utils/card_tag_edit.dart';

DeckCard _card(String id, List<String> tags) =>
    DeckCard(scryfallId: id, name: id, quantity: 1, tags: tags);

void main() {
  group('addTag', () {
    test('ajoute en fin avec l\'orthographe du catalogue', () {
      expect(addTag(['Ramp'], 'pioche', kDefaultCardTags), ['Ramp', 'Pioche']);
    });

    test('ne fait rien sur un doublon à la casse près', () {
      expect(addTag(['Ramp'], 'RAMP', kDefaultCardTags), ['Ramp']);
    });

    test('un tag de deck garde la graphie saisie, espaces réduits', () {
      expect(addTag(['Ramp'], '  Mon   tag ', kDefaultCardTags), [
        'Ramp',
        'Mon tag',
      ]);
    });

    test('un nom invalide ne change rien', () {
      expect(addTag(['Ramp'], '   ', kDefaultCardTags), ['Ramp']);
    });
  });

  test('removeTag retire sans tenir compte de la casse', () {
    expect(removeTag(['Ramp', 'Blink'], 'blink'), ['Ramp']);
  });

  test('makePrimary déplace en tête', () {
    expect(makePrimary(['Ramp', 'Blink'], 'Blink'), ['Blink', 'Ramp']);
  });

  test('deckOnlyTags : union triée des quatre boards absents du catalogue', () {
    final deck = Deck(
      id: 'd',
      name: 'D',
      mainboard: [
        _card('a', ['Ramp', 'Combo']),
      ],
      sideboard: [
        _card('b', ['Hate']),
      ],
      considering: [
        _card('c', ['combo', 'Zeta']),
      ],
      wishlist: [
        _card('e', ['Alpha']),
      ],
    );
    expect(deckOnlyTags(deck, kDefaultCardTags), [
      'Alpha',
      'Combo',
      'Hate',
      'Zeta',
    ]);
  });
}
