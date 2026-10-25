import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';

Map<String, dynamic> _base(Map<String, dynamic> extra) => {
  'id': 'x',
  'name': 'Test',
  'type_line': 'Instant',
  ...extra,
};

void main() {
  test('carte simple : oracle_text de la racine', () {
    final c = ScryfallCard.fromJson(
      _base({'oracle_text': 'Draw three cards.'}),
    );
    expect(c.oracleText, 'Draw three cards.');
  });

  test('double face : faces avant et verso séparées par un saut de ligne', () {
    final c = ScryfallCard.fromJson(
      _base({
        'card_faces': [
          {
            'oracle_text': 'Front text.',
            'image_uris': {'normal': 'a', 'small': 'b'},
          },
          {
            'oracle_text': 'Back text.',
            'image_uris': {'normal': 'c', 'small': 'd'},
          },
        ],
      }),
    );
    expect(c.oracleText, 'Front text.\nBack text.');
  });

  test('split sans image_uris ni oracle_text racine : textes des faces', () {
    final c = ScryfallCard.fromJson(
      _base({
        'card_faces': [
          {'oracle_text': 'Destroy target creature.'},
          {'oracle_text': 'Draw a card.'},
        ],
      }),
    );
    expect(c.oracleText, 'Destroy target creature.\nDraw a card.');
  });

  test('printed_text français : oracleText reste anglais', () {
    final c = ScryfallCard.fromJson(
      _base({
        'printed_text': 'Piochez trois cartes.',
        'oracle_text': 'Draw three cards.',
      }),
    );
    expect(c.rulesText, 'Piochez trois cartes.');
    expect(c.oracleText, 'Draw three cards.');
  });

  test('aucun texte : chaîne vide', () {
    expect(ScryfallCard.fromJson(_base({})).oracleText, '');
  });
}
