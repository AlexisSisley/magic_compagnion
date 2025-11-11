// Fichier : lib/data/glossary_data_en.dart
// (VERSION ANGLAISE)

// Importer le modèle, il est réutilisable
import 'glossary_data.dart';

// La liste des mots-clés en anglais
// (Ceci est un EXEMPLE abrégé)
final List<Keyword> glossaryTermsEN = [
  Keyword(
    term: "Deathtouch",
    definition: "A keyword ability. Any nonzero amount of damage a source with deathtouch deals to a creature is considered to be lethal damage. Deathtouch has no effect on players or planeswalkers."
  ),
  Keyword(
    term: "Double Strike",
    definition: "A keyword ability. Creatures with double strike deal combat damage twice. When combat damage is dealt, check if any attacking or blocking creatures have first strike or double strike. If so, an extra combat damage step is created just for them. Creatures with first strike and double strike are the only ones to deal combat damage during this step. Then, the normal combat damage step occurs."
  ),
  Keyword(
    term: "First Strike",
    definition: "A keyword ability. Creatures with first strike deal all of their combat damage before creatures without first strike or double strike. See also Double Strike."
  ),
  Keyword(
    term: "Flying",
    definition: "A keyword ability. Creatures with flying can only be blocked by creatures with flying or reach."
  ),
  Keyword(
    term: "Haste",
    definition: "A keyword ability. A creature with haste is unaffected by summoning sickness. It can attack as soon as it comes under your control. You can also activate its activated abilities with the tap symbol in their cost immediately."
  ),
  Keyword(
    term: "Lifelink",
    definition: "A keyword ability. When a creature you control with lifelink deals damage, you simultaneously gain that much life."
  ),
  Keyword(
    term: "Reach",
    definition: "A keyword ability. A creature with reach can block a creature with flying."
  ),
  Keyword(
    term: "Trample",
    definition: "A keyword ability. Trample allows a creature to deal excess combat damage to the player it's attacking, even if it's blocked. If you attack with a creature that has trample and it's blocked, you must assign its combat damage to the creatures blocking it first. If it destroys all those creatures, you can assign the leftover damage to the player it's attacking."
  ),
Keyword(
    term: "Enchant",
    definition: "A keyword ability on Aura cards. It is always followed by what the Aura can be attached to (e.g., \"Enchant creature,\" \"Enchant land\"). When you cast an Aura, you must target that type of permanent. When an Aura's ability refers to \"enchanted creature,\" it means \"the creature this Aura is attached to.\""
  ),
  Keyword(
    term: "Equipment",
    definition: "Equipment is a subtype that appears on an artifact that can be attached to a creature. Most Equipment cards have the activated ability \"Equip\" followed by a cost. An Equip ability can only be activated when you could cast a sorcery. When you activate an Equip ability, you choose a creature you control as the target. When the ability resolves, the Equipment artifact becomes attached to that creature."
  ),
  Keyword(
    term: " (Tap)",
    definition: "This symbol means \"tap this permanent\" (turn the card sideways to show it has been used). It appears in activation costs. You cannot pay a tap cost if the card is already tapped, or if it is a creature still affected by summoning sickness."
  ),
  Keyword(
    term: "Opponent",
    definition: "The person you are playing against is your opponent. If a card says \"an opponent,\" it means one of its controller's opponents."
  ),
  Keyword(
    term: "Aura",
    definition: "Aura is a subtype that appears on an enchantment that can be attached to a permanent. Each Aura has the keyword \"Enchant\" followed by the description of what it can be attached to. When you cast an Aura spell, you choose its target. When the Aura resolves, it is put onto the battlefield attached to that permanent."
  ),
  Keyword(
    term: "Hexproof",
    definition: "A keyword ability that prevents a permanent or player from being the target of spells or abilities an opponent controls."
  ),
  Keyword(
    term: "Defender",
    definition: "A keyword ability found on creatures. Creatures with defender cannot attack."
  ),
  Keyword(
    term: "Destroy",
    definition: "When a permanent is destroyed, you move it from the battlefield to its owner's graveyard. Creatures are destroyed when they take damage equal to or greater than their toughness. Many spells and abilities can also destroy permanents without dealing damage."
  ),
  Keyword(
    term: "Exile",
    definition: "Some spells and abilities can exile permanents from the battlefield or cards from other zones. Exiled cards are put outside the rest of the game. You cannot interact with exiled cards unless an ability specifies otherwise."
  ),
  Keyword(
    term: "Flash",
    definition: "A keyword ability found on some cards. A spell with flash can be cast any time you could cast an instant."
  ),
  Keyword(
    term: "Indestructible",
    definition: "A keyword ability. An indestructible permanent cannot be destroyed by damage or effects that say \"destroy,\" but it can still be put into the graveyard for other reasons, such as an effect that reduces its toughness to 0."
  ),
  Keyword(
    term: "Token",
    definition: "Some spells and abilities can create tokens. Tokens are always permanents. However, if one of your tokens leaves the battlefield, it goes to the new zone (like your graveyard or hand) and then immediately ceases to exist."
  ),
  Keyword(
    term: "Legendary",
    definition: "Legendary is a supertype. If a player controls two or more legendary permanents with the same name at the same time, that player must choose one of them to keep on the battlefield and the others are immediately put into their owner's graveyard."
  ),
  Keyword(
    term: "Mana",
    definition: "Mana is the basic unit of magical energy used to pay for spells and some abilities. Mana is usually generated by tapping lands. There are five colors of mana: white, blue, black, red, and green. Unspent mana disappears at the end of turns and phases."
  ),
  Keyword(
    term: "Menace",
    definition: "A keyword ability found on creatures. A creature with menace can't be blocked except by two or more creatures."
  ),
  Keyword(
    term: "Mulligan",
    definition: "At the start of the game, if you don't like your starting hand, you can declare a mulligan. Shuffle your hand into your library, then draw a new hand of seven cards. If you like this hand, put one card from it on the bottom of your library. You can mulligan as many times as you like, but you put one card on the bottom for each mulligan you've taken this game."
  ),
  Keyword(
    term: "Permanent",
    definition: "A card or token on the battlefield. Permanents can be artifacts, creatures, enchantments, or lands. They remain on the battlefield until they are destroyed, exiled, sacrificed, or otherwise removed."
  ),
  Keyword(
    term: "Planeswalker",
    definition: "Planeswalkers are powerful allies you can summon. You can cast a planeswalker during your main phase. Once per turn (during your turn), you can activate one of their abilities by adding or removing \"loyalty\" counters. When a planeswalker's loyalty is reduced to zero, it is sent to the graveyard."
  ),
  Keyword(
    term: "Scry",
    definition: "A keyword action. \"Scry N\" allows you to look at N cards from the top of your library. You may put any number of those cards on the bottom of your library, then put the rest on top of your library in any order."
  ),
  Keyword(
    term: "Sacrifice",
    definition: "If a spell or ability asks you to sacrifice a type of permanent, choose one of your permanents of that type on the battlefield and put it into its owner's graveyard. You can only sacrifice permanents you control."
  ),
  Keyword(
    term: "Discard",
    definition: "To discard a card, take a card from your hand and place it in your graveyard. If you have more than seven cards in your hand at the end of your turn, you must discard cards until you have only seven."
  ),
  Keyword(
    term: "Spell",
    definition: "All card types, except for lands, are spells when you cast them. Spells can only be cast during your main phase, with the exception of instants, which can be cast at any time."
  ),
  Keyword(
    term: "Vigilance",
    definition: "A keyword ability found on creatures. A creature with vigilance does not tap to attack."
  ),
  Keyword(
    term: "X",
    definition: "When you see X in a mana cost or activation cost, you can choose the value of X. For example, a spell that costs X and R will deal X damage. If you choose X=3, the spell will cost 3 and R."
  ),
];