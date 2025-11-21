// Fichier : lib/widgets/decks/deck_card_list_tab.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../pages/card_detail_page.dart';

class DeckCardListTab extends StatefulWidget {
  final List<DeckCard> cardList;
  final List<ScryfallCard> fullCardData;
  final List<DeckCard> collection;
  final String? commanderId;
  final Function(DeckCard, int) onUpdateQuantity;
  final Function(DeckCard) onSetCommander;

  const DeckCardListTab({
    super.key,
    required this.cardList,
    required this.fullCardData,
    required this.collection,
    this.commanderId,
    required this.onUpdateQuantity,
    required this.onSetCommander,
  });

  @override
  State<DeckCardListTab> createState() => _DeckCardListTabState();
}

class _DeckCardListTabState extends State<DeckCardListTab> {
  // Par défaut, on reste sur la vue "Liste Classique"
  bool _isGridView = false; 

  @override
  Widget build(BuildContext context) {
    if (widget.cardList.isEmpty) {
      return Center(
        child: Text('Aucune carte ici.', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16)),
      );
    }

    final groupedList = _buildGroupedList(widget.cardList);

    return Column(
      children: [
        // --- BARRE D'OUTILS (Bouton de bascule) ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Info sur le nombre de cartes (optionnel)
              Text(
                "${widget.cardList.fold(0, (s, c) => s + c.quantity)} cartes",
                style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
              ),
              
              // Le bouton de bascule
              Row(
                children: [
                  Text(
                    _isGridView ? "Mode Grille" : "Mode Liste", 
                    style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isGridView ? Icons.grid_view : Icons.view_list, 
                      color: Colors.yellow.shade700
                    ),
                    tooltip: "Changer de vue",
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- LISTE OU GRILLE ---
        Expanded(
          child: ListView.builder(
            // Padding en bas pour ne pas être caché par le FAB ou la TabBar
            padding: const EdgeInsets.only(bottom: 90.0, top: 0.0, left: 4.0, right: 4.0),
            itemCount: groupedList.length,
            itemBuilder: (context, index) {
              final group = groupedList[index];
              final int groupCardCount = group.cards.fold(0, (sum, c) => sum + c.quantity);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre de la section (ex: Créatures)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    child: Text(
                      '${group.title} ($groupCardCount)',
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Affichage conditionnel : Grille ou Liste
                  _isGridView 
                      ? _buildGroupGrid(group.cards) 
                      : _buildGroupList(group.cards),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- VUE LISTE (Classique) ---
  Widget _buildGroupList(List<DeckCard> cards) {
    return Column(
      children: cards.map((card) => _buildItem(card, isGrid: false)).toList(),
    );
  }

  // --- VUE GRILLE (Nouvelle) ---
  Widget _buildGroupGrid(List<DeckCard> cards) {
    return GridView.builder(
      shrinkWrap: true, // Important car on est dans une ListView
      physics: const NeverScrollableScrollPhysics(), // Le scroll est géré par la ListView parente
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 cartes par ligne
        childAspectRatio: 0.68, // Ratio d'une carte Magic (~63x88mm)
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _buildItem(cards[index], isGrid: true);
      },
    );
  }

  // --- Constructeur d'item (Gère les données communes) ---
  Widget _buildItem(DeckCard card, {required bool isGrid}) {
    final bool isCommander = widget.commanderId == card.scryfallId;
    
    ScryfallCard? scryfallCard;
    try {
      if (!card.scryfallId.startsWith('LOCAL:')) {
        scryfallCard = widget.fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
      }
    } catch (e) { /* Fallback */ }

    final bool isInCollection = widget.collection.any((c) => c.scryfallId == card.scryfallId);

    // Fonctions de callback
    void onPlus() => widget.onUpdateQuantity(card, 1);
    void onMinus() => widget.onUpdateQuantity(card, -1);
    void onLongPress() => widget.onSetCommander(card);
    void onTap() {
      if (scryfallCard != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RecognitionResultPage(cardName: scryfallCard!.name),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Données non disponibles pour "${card.name}"', style: GoogleFonts.cinzel()),
        ));
      }
    }

    // Retourne le bon widget selon le mode
    if (isGrid) {
      return DeckCardGridTile(
        card: card,
        scryfallCard: scryfallCard,
        isCommander: isCommander,
        isInCollection: isInCollection,
        onPlus: onPlus,
        onMinus: onMinus,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    } else {
      return DeckCardTile(
        card: card,
        scryfallCard: scryfallCard,
        isCommander: isCommander,
        isInCollection: isInCollection,
        onPlus: onPlus,
        onMinus: onMinus,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }
  }

  // --- Logique de groupement (Inchangée) ---
  List<_GroupedCardList> _buildGroupedList(List<DeckCard> cardList) {
    Map<String, List<DeckCard>> groupedMap = {
      'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 
      'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [],
    };

    for (final deckCard in cardList) {
      String type = 'Autres';
      if (deckCard.scryfallId.startsWith('LOCAL:')) {
        type = _getPrimaryType(deckCard.name);
      } else {
        try {
          final sc = widget.fullCardData.firstWhere((s) => s.id == deckCard.scryfallId);
          type = _getPrimaryType(sc.typeLine);
        } catch (e) {
           type = _getPrimaryType(deckCard.name);
        }
      }
      groupedMap[type]?.add(deckCard);
    }
    
    List<_GroupedCardList> groupedList = [];
    groupedMap.forEach((title, cards) {
      if (cards.isNotEmpty) {
        cards.sort((a, b) => a.name.compareTo(b.name));
        groupedList.add(_GroupedCardList(title: title, cards: cards));
      }
    });
    return groupedList;
  }

  String _getPrimaryType(String typeLine) {
    String lowerType = typeLine.toLowerCase();
    if (!lowerType.contains(' — ') && (lowerType.contains('swamp') || lowerType.contains('plains') || lowerType.contains('island') || lowerType.contains('mountain') || lowerType.contains('forest'))) return 'Terrains';
    if (lowerType.contains('creature')) return 'Créatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('land')) return 'Terrains';
    if (lowerType.contains('artifact')) return 'Artefacts';
    if (lowerType.contains('enchantment')) return 'Enchantements';
    if (lowerType.contains('instant')) return 'Sorts';
    if (lowerType.contains('sorcery')) return 'Sorts';
    return 'Autres';
  }
}

class _GroupedCardList {
  final String title;
  final List<DeckCard> cards;
  _GroupedCardList({required this.title, required this.cards});
}