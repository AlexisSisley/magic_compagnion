import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';

void main() {
  group('ScryfallCard.fromJson', () {
    test('parses simple card correctly', () {
      final json = {
        'id': 'abc-123',
        'oracle_id': 'oracle-1',
        'name': 'Lightning Bolt',
        'printed_name': 'Eclair',
        'mana_cost': '{R}',
        'cmc': 1.0,
        'image_uris': {
          'normal': 'https://example.com/normal.jpg',
          'small': 'https://example.com/small.jpg',
          'art_crop': 'https://example.com/art.jpg',
        },
        'oracle_text': 'Lightning Bolt deals 3 damage to any target.',
        'type_line': 'Instant',
        'legalities': {'standard': 'not_legal', 'modern': 'legal'},
        'prices': {'eur': '1.50', 'usd': '2.00'},
        'lang': 'fr',
        'color_identity': ['R'],
        'set_name': 'Alpha',
        'set': 'lea',
        'collector_number': '161',
        'rarity': 'common',
        'purchase_uris': {
          'tcgplayer': 'https://tcg.com/bolt',
          'cardmarket': 'https://cardmarket.com/bolt',
        },
      };

      final card = ScryfallCard.fromJson(json);
      expect(card.id, 'abc-123');
      expect(card.oracleId, 'oracle-1');
      expect(card.name, 'Lightning Bolt');
      expect(card.printedName, 'Eclair');
      expect(card.manaCost, '{R}');
      expect(card.cmc, 1.0);
      expect(card.imageUrl, 'https://example.com/normal.jpg');
      expect(card.smallImageUrl, 'https://example.com/small.jpg');
      expect(card.artCropUrl, 'https://example.com/art.jpg');
      expect(card.rulesText, 'Lightning Bolt deals 3 damage to any target.');
      expect(card.typeLine, 'Instant');
      expect(card.legalities['modern'], 'legal');
      expect(card.prices['eur'], '1.50');
      expect(card.lang, 'fr');
      expect(card.colorIdentity, ['R']);
      expect(card.setName, 'Alpha');
      expect(card.setCode, 'lea');
      expect(card.collectorNumber, '161');
      expect(card.rarity, 'common');
      expect(card.purchaseUris['cardmarket'], 'https://cardmarket.com/bolt');
    });

    test('parses double-faced card (card_faces with image_uris)', () {
      final json = {
        'id': 'dfc-1',
        'oracle_id': 'oracle-dfc',
        'name': 'Delver of Secrets // Insectile Aberration',
        'cmc': 1.0,
        'card_faces': [
          {
            'name': 'Delver of Secrets',
            'mana_cost': '{U}',
            'oracle_text': 'At the beginning...',
            'printed_name': 'Scrutateur de secrets',
            'printed_text': 'Au debut...',
            'image_uris': {
              'normal': 'https://example.com/delver-front.jpg',
              'small': 'https://example.com/delver-small.jpg',
              'art_crop': 'https://example.com/delver-art.jpg',
            },
          },
          {
            'name': 'Insectile Aberration',
            'mana_cost': '',
            'oracle_text': 'Flying',
            'image_uris': {
              'normal': 'https://example.com/insectile.jpg',
              'small': 'https://example.com/insectile-small.jpg',
            },
          },
        ],
        'type_line': 'Creature — Human Wizard // Creature — Human Insect',
        'legalities': {'modern': 'legal'},
        'prices': {'eur': '0.50'},
        'lang': 'fr',
        'color_identity': ['U'],
        'set_name': 'Innistrad',
        'set': 'isd',
        'collector_number': '51',
        'rarity': 'common',
        'purchase_uris': {},
      };

      final card = ScryfallCard.fromJson(json);
      expect(card.name, 'Delver of Secrets // Insectile Aberration');
      expect(card.imageUrl, 'https://example.com/delver-front.jpg');
      expect(card.smallImageUrl, 'https://example.com/delver-small.jpg');
      expect(card.artCropUrl, 'https://example.com/delver-art.jpg');
      expect(card.manaCost, '{U}');
      expect(card.printedName, 'Scrutateur de secrets');
      // printed_text is used for rulesText on faces
      expect(card.rulesText, 'Au debut...');
      expect(card.cmc, 1.0);
    });

    test('parses card with missing optional fields', () {
      final json = {
        'id': 'minimal-1',
        'name': 'Unknown Card',
        'type_line': 'Artifact',
        'legalities': {},
        'prices': {},
        'lang': 'en',
        'color_identity': [],
        'set_name': 'Test Set',
        'set': 'tst',
        'collector_number': '1',
        'rarity': 'rare',
        'purchase_uris': {},
      };

      final card = ScryfallCard.fromJson(json);
      expect(card.oracleId, '');
      expect(card.printedName, isNull);
      expect(card.manaCost, isNull);
      expect(card.cmc, isNull);
      expect(card.imageUrl, '');
      expect(card.smallImageUrl, isNull);
      expect(card.rulesText, '');
    });

    test('defaults for completely missing fields', () {
      final json = {
        'id': 'default-test',
      };

      final card = ScryfallCard.fromJson(json);
      expect(card.name, 'Nom inconnu');
      expect(card.typeLine, 'Type inconnu');
      expect(card.oracleId, '');
      expect(card.lang, 'en');
      expect(card.setName, 'Unknown Set');
      expect(card.setCode, '');
      expect(card.collectorNumber, '');
      expect(card.rarity, 'common');
      expect(card.colorIdentity, isEmpty);
      expect(card.purchaseUris, isEmpty);
      expect(card.allParts, isEmpty);
    });

    test('parses allParts with tokens correctly', () {
      final json = {
        'id': 'avenger-1',
        'oracle_id': 'oracle-avenger',
        'name': 'Avenger of Zendikar',
        'type_line': 'Creature — Elemental',
        'oracle_text': 'When Avenger of Zendikar enters, create a 0/1 Plant token.',
        'legalities': {'commander': 'legal'},
        'prices': {'eur': '5.00'},
        'lang': 'en',
        'color_identity': ['G'],
        'set_name': 'Worldwake',
        'set': 'wwk',
        'collector_number': '96',
        'rarity': 'mythic',
        'purchase_uris': {},
        'all_parts': [
          {
            'id': 'avenger-1',
            'component': 'combo_piece',
            'name': 'Avenger of Zendikar',
            'type_line': 'Creature — Elemental',
            'uri': 'https://api.scryfall.com/cards/avenger-1',
          },
          {
            'id': 'plant-token-1',
            'component': 'token',
            'name': 'Plant Token',
            'type_line': 'Token Creature — Plant',
            'uri': 'https://api.scryfall.com/cards/plant-token-1',
          },
        ],
      };

      final card = ScryfallCard.fromJson(json);
      expect(card.allParts, hasLength(2));
      expect(card.allParts[0].component, 'combo_piece');
      expect(card.allParts[0].isToken, false);
      expect(card.allParts[1].id, 'plant-token-1');
      expect(card.allParts[1].name, 'Plant Token');
      expect(card.allParts[1].component, 'token');
      expect(card.allParts[1].isToken, true);
      expect(card.allParts[1].typeLine, 'Token Creature — Plant');
    });

    test('allParts defaults to empty list when absent', () {
      final json = {
        'id': 'no-parts',
        'name': 'Sol Ring',
        'type_line': 'Artifact',
        'legalities': {},
        'prices': {},
        'lang': 'en',
        'color_identity': [],
        'set_name': 'Commander',
        'set': 'cmd',
        'collector_number': '1',
        'rarity': 'uncommon',
        'purchase_uris': {},
      };

      final card = ScryfallCard.fromJson(json);
      expect(card.allParts, isEmpty);
    });
  });

  group('RelatedCard', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'token-123',
        'component': 'token',
        'name': 'Soldier Token',
        'type_line': 'Token Creature — Soldier',
        'uri': 'https://api.scryfall.com/cards/token-123',
      };

      final related = RelatedCard.fromJson(json);
      expect(related.id, 'token-123');
      expect(related.component, 'token');
      expect(related.name, 'Soldier Token');
      expect(related.typeLine, 'Token Creature — Soldier');
      expect(related.uri, 'https://api.scryfall.com/cards/token-123');
      expect(related.isToken, true);
    });

    test('isToken is false for non-token components', () {
      final json = {
        'id': 'meld-1',
        'component': 'meld_part',
        'name': 'Bruna, the Fading Light',
        'type_line': 'Legendary Creature — Angel Horror',
        'uri': 'https://api.scryfall.com/cards/meld-1',
      };

      final related = RelatedCard.fromJson(json);
      expect(related.isToken, false);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final related = RelatedCard.fromJson(json);
      expect(related.id, '');
      expect(related.component, '');
      expect(related.name, '');
      expect(related.typeLine, '');
      expect(related.uri, '');
      expect(related.isToken, false);
    });
  });
}
