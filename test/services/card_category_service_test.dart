import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/card_category.dart';
import 'package:magic_companion/services/card_category_service.dart';

void main() {
  final cases = <(String, String, String, CardCategory)>[
    ('Sol Ring', 'Artifact', '{T}: Add {C}{C}.', CardCategory.ramp),
    (
      'Cultivate',
      'Sorcery',
      'Search your library for up to two basic land cards, reveal those cards, put one onto the battlefield tapped and the other into your hand, then shuffle.',
      CardCategory.ramp,
    ),
    (
      'Command Tower',
      'Land',
      '{T}: Add one mana of any color in your commander\'s color identity.',
      CardCategory.lands,
    ),
    (
      'Dryad Arbor',
      'Land Creature — Forest Dryad',
      '(Dryad Arbor isn\'t a spell, it\'s affected by summoning sickness, and it has "{T}: Add {G}.")',
      CardCategory.creatures,
    ),
    (
      'Swords to Plowshares',
      'Instant',
      'Exile target creature. Its controller gains life equal to its power.',
      CardCategory.removal,
    ),
    ('Counterspell', 'Instant', 'Counter target spell.', CardCategory.removal),
    (
      'Wrath of God',
      'Sorcery',
      'Destroy all creatures. They can\'t be regenerated.',
      CardCategory.wipe,
    ),
    (
      'Toxic Deluge',
      'Sorcery',
      'As an additional cost to cast this spell, pay X life.\nAll creatures get -X/-X until end of turn.',
      CardCategory.wipe,
    ),
    (
      'Demonic Tutor',
      'Sorcery',
      'Search your library for a card, put that card into your hand, then shuffle.',
      CardCategory.tutor,
    ),
    ('Harmonize', 'Sorcery', 'Draw three cards.', CardCategory.draw),
    (
      'Heroic Intervention',
      'Instant',
      'Permanents you control gain hexproof and indestructible until end of turn.',
      CardCategory.protection,
    ),
    (
      'Thassa\'s Oracle',
      'Creature — Merfolk Wizard',
      'When Thassa\'s Oracle enters the battlefield, look at the top X cards of your library, where X is your devotion to blue. Put up to one of them on top of your library and the rest on the bottom of your library in a random order. If X is greater than or equal to the number of cards in your library, you win the game.',
      CardCategory.wincon,
    ),
    (
      'Llanowar Elves',
      'Creature — Elf Druid',
      '{T}: Add {G}.',
      CardCategory.ramp,
    ),
    ('Grizzly Bears', 'Creature — Bear', '', CardCategory.creatures),
    (
      'Swiftfoot Boots',
      'Artifact — Equipment',
      'Equipped creature has hexproof and haste.\nEquip {1}',
      CardCategory.protection,
    ),
    (
      'Darksteel Colossus',
      'Artifact Creature — Golem',
      'Trample\nIndestructible\nIf Darksteel Colossus would be put into a graveyard from anywhere, reveal Darksteel Colossus and shuffle it into its owner\'s library instead.',
      CardCategory.creatures,
    ),
    ('Dark Ritual', 'Instant', 'Add {B}{B}{B}.', CardCategory.ramp),
    (
      'Brainstorm',
      'Instant',
      'Draw three cards, then put two cards from your hand on top of your library in any order.',
      CardCategory.draw,
    ),
    (
      'Enchantement sans motif',
      'Enchantment',
      'Players can\'t cast spells with odd mana value.',
      CardCategory.other,
    ),
  ];

  for (final (name, type, text, expected) in cases) {
    test('$name -> ${expected.name}', () {
      expect(classifyCard(typeLine: type, oracleText: text), expected);
    });
  }

  test('insensible à la casse', () {
    expect(
      classifyCard(typeLine: 'INSTANT', oracleText: 'COUNTER TARGET SPELL.'),
      CardCategory.removal,
    );
  });
}
