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
  // Callback pour dire au parent de recharger l'état global (finance, stats...)
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
        // --- BARRE D'OUTILS ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${widget.cardList.fold(0, (s, c) => s + c.quantity)} cartes",
                style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
              ),
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
                    onPressed: () => setState(() => _isGridView = !_isGridView),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- LISTE ---
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 90.0, top: 0.0, left: 4.0, right: 4.0),
            itemCount: groupedList.length,
            itemBuilder: (context, index) {
              final group = groupedList[index];
              final int groupCardCount = group.cards.fold(0, (sum, c) => sum + c.quantity);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    child: Text(
                      '${group.title} ($groupCardCount)',
                      style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
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

  Widget _buildGroupList(List<DeckCard> cards) {
    return Column(
      children: cards.map((card) => _buildItem(card, isGrid: false)).toList(),
    );
  }

  Widget _buildGroupGrid(List<DeckCard> cards) {
    return GridView.builder(
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.68,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _buildItem(cards[index], isGrid: true);
      },
    );
  }

  Widget _buildItem(DeckCard card, {required bool isGrid}) {
    final bool isCommander = widget.commanderId == card.scryfallId;
    ScryfallCard? scryfallCard;
    try {
      if (!card.scryfallId.startsWith('LOCAL:')) {
        scryfallCard = widget.fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
      }
    } catch (e) { /* Fallback */ }
    final bool isInCollection = widget.collection.any((c) => c.scryfallId == card.scryfallId);

    void onPlus() => widget.onUpdateQuantity(card, 1);
    void onMinus() => widget.onUpdateQuantity(card, -1);
    
    // NOUVEAU : Appui long ouvre un menu d'options
    void onLongPress() => _showCardOptions(context, card, isCommander);
    
    void onTap() {
      if (scryfallCard != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RecognitionResultPage(cardName: scryfallCard!.name),
        ));
      }
    }

    if (isGrid) {
      return DeckCardGridTile(
        card: card, scryfallCard: scryfallCard, isCommander: isCommander,
        isInCollection: isInCollection, onPlus: onPlus, onMinus: onMinus,
        onTap: onTap, onLongPress: onLongPress,
      );
    } else {
      return DeckCardTile(
        card: card, scryfallCard: scryfallCard, isCommander: isCommander,
        isInCollection: isInCollection, onPlus: onPlus, onMinus: onMinus,
        onTap: onTap, onLongPress: onLongPress,
      );
    }
  }

  // --- MENU D'OPTIONS (PROXIES / COMMANDER) ---
  void _showCardOptions(BuildContext context, DeckCard card, bool isAlreadyCommander) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        // On récupère la hauteur du clavier ET la hauteur de la barre de navigation
        final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final double navBarHeight = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            // Padding interne : On ajoute la hauteur de la barre de nav au padding du bas (16 + navBarHeight)
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + navBarHeight),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24),
                
                // Option 1: Commander
                ListTile(
                  leading: Icon(Icons.star, color: isAlreadyCommander ? Colors.yellow : Colors.white70),
                  title: Text(isAlreadyCommander ? 'Déjà Commandant' : 'Définir comme Commandant', style: GoogleFonts.cinzel(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    if (!isAlreadyCommander) widget.onSetCommander(card);
                  },
                ),
                
                // Option 2: Proxies
                const Divider(color: Colors.white10),
                Text("Gestion des Proxies", style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Nombre de proxies :", style: GoogleFonts.cinzel(color: Colors.white)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                          onPressed: () {
                            if (card.proxyQuantity > 0) {
                              setState(() => card.proxyQuantity--);
                              // Hack pour forcer la mise à jour de l'interface parente si besoin
                              // (Dans une vraie architecture, on passerait par le service, mais ici l'objet est muté par référence)
                              // On déclenche un update quantity de 0 pour forcer le refresh du parent
                              widget.onUpdateQuantity(card, 0); 
                            }
                            // Force le rebuild du modal pour voir le chiffre changer
                            (context as Element).markNeedsBuild();
                          },
                        ),
                        Text('${card.proxyQuantity} / ${card.quantity}', style: GoogleFonts.cinzel(color: Colors.blueGrey.shade200, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                          onPressed: () {
                            if (card.proxyQuantity < card.quantity) {
                              setState(() => card.proxyQuantity++);
                              widget.onUpdateQuantity(card, 0);
                            }
                            (context as Element).markNeedsBuild();
                          },
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Les proxies sont exclus du calcul financier.",
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                )
              ],
            ),
          ),
        );        
      }
    );
  }

  // --- LOGIQUE DE GROUPEMENT (Inchangée) ---
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