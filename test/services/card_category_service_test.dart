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
    (
      'Lightning Bolt',
      'Instant',
      'Lightning Bolt deals 3 damage to any target.',
      CardCategory.removal,
    ),
    (
      'Chain Lightning',
      'Sorcery',
      'Chain Lightning deals 3 damage to any target. Then that player or that permanent\'s controller may pay {R}{R}. If the player does, they may copy this spell and may choose a new target for that copy.',
      CardCategory.removal,
    ),
    (
      'Cathars\' Crusade',
      'Enchantment',
      'Whenever a creature enters the battlefield under your control, put a +1/+1 counter on each creature you control.',
      CardCategory.other,
    ),
    (
      'Blasphemous Act',
      'Sorcery',
      'This spell costs {1} less to cast for each creature on the battlefield.\nBlasphemous Act deals 13 damage to each creature.',
      CardCategory.wipe,
    ),
    (
      'Ephemerate',
      'Instant',
      'Exile target creature you control, then return it to the battlefield under its owner\'s control.\nRebound',
      CardCategory.other,
    ),
    (
      'Restoration Angel',
      'Creature — Angel',
      'Flash\nFlying\nWhen Restoration Angel enters the battlefield, you may exile target non-Angel creature you control, then return that card to the battlefield under your control.',
      CardCategory.creatures,
    ),
    (
      'Lightning Greaves',
      'Artifact — Equipment',
      'Equipped creature has haste and shroud.\nEquip {0}',
      CardCategory.protection,
    ),
    // Carte fictive : le gain de vie est dans une autre phrase que le mot-clé.
    (
      'Créature indestructible qui gagne des PV',
      'Creature — Angel',
      'Indestructible\nWhen this creature enters the battlefield, you gain 2 life.',
      CardCategory.creatures,
    ),
    // Carte fictive : protection conditionnelle de soi, classée protection.
    (
      'Hexproof conditionnel',
      'Creature — Elf',
      'This creature has hexproof as long as you control another creature.',
      CardCategory.protection,
    ),
    (
      'Valakut Awakening',
      'Sorcery // Land',
      'Put any number of cards from your hand on the bottom of your library, then draw that many cards plus one.\nValakut Stoneforges\n({T}: Add {R}.)',
      CardCategory.draw,
    ),
    (
      'Exploration',
      'Enchantment',
      'You may play an additional land on each of your turns.',
      CardCategory.ramp,
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
