// Fichier : lib/widgets/decks/deck_card_list_tab.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../pages/cards/card_detail_page.dart';

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
  // État du Zoom : Double pour la fluidité du Slider
  double _gridColumns = 3.0; 
  double _lastScale = 1.0; // Pour mémoriser l'échelle du geste

  // --- LOGIQUE PINCH TO ZOOM ---
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale > 1.3 && _lastScale <= 1.0) {
      // Zoom In (Agrandir les cartes -> Moins de colonnes)
      setState(() {
        if (_gridColumns > 1) _gridColumns--;
        _lastScale = details.scale;
      });
    } else if (details.scale < 0.7 && _lastScale >= 1.0) {
      // Zoom Out (Rétrécir -> Plus de colonnes)
      setState(() {
        if (_gridColumns < 5) _gridColumns++;
        _lastScale = details.scale;
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastScale = 1.0; // Reset
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cardList.isEmpty) {
      return Center(
        child: Text('Aucune carte ici.', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16)),
      );
    }

    final groupedList = _buildGroupedList(widget.cardList);
    final int currentCols = _gridColumns.round(); // Conversion en entier pour le GridView

    return Column(
      children: [
        // --- BARRE D'OUTILS (Infos + Slider) ---
        Container(
          color: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            children: [
              Text(
                "${widget.cardList.fold(0, (s, c) => s + c.quantity)} cartes",
                style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              
              // Icône Liste (Zoom min)
              const Icon(Icons.view_agenda, size: 16, color: Colors.white54),
              
              // --- LE SLIDER DE CONTRÔLE ---
              SizedBox(
                width: 130, 
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 2,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _gridColumns,
                    min: 1,
                    max: 5,
                    divisions: 4, // 5 positions: 1, 2, 3, 4, 5
                    activeColor: Colors.yellow.shade800,
                    inactiveColor: Colors.white24,
                    label: currentCols == 1 ? "Liste" : "$currentCols Col",
                    onChanged: (val) {
                      setState(() => _gridColumns = val);
                    },
                  ),
                ),
              ),
              
              // Icône Grille (Zoom max)
              const Icon(Icons.grid_view, size: 16, color: Colors.white54),
            ],
          ),
        ),

        // --- LISTE PRINCIPALE ---
        Expanded(
          child: GestureDetector(
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 90.0, top: 0.0, left: 4.0, right: 4.0),
              itemCount: groupedList.length,
              itemBuilder: (context, index) {
                final group = groupedList[index];
                final int groupCardCount = group.cards.fold(0, (sum, c) => sum + c.quantity);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre de section (Créatures, Terrains...)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Text(
                        '${group.title} ($groupCardCount)',
                        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    // Choix de la vue : Liste ou Grille
                    currentCols == 1 
                        ? _buildGroupList(group.cards) 
                        : _buildGroupGrid(group.cards, currentCols),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Vue Liste (1 colonne)
  Widget _buildGroupList(List<DeckCard> cards) {
    return Column(
      children: cards.map((card) => _buildItem(card, isGrid: false)).toList(),
    );
  }

  // Vue Grille (2 à 5 colonnes)
  Widget _buildGroupGrid(List<DeckCard> cards, int cols) {
    return GridView.builder(
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(), // Scroll délégué au parent
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.68, // Ratio carte Magic standard
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _buildItem(cards[index], isGrid: true);
      },
    );
  }

  // Construction de la tuile (Liste ou Grille)
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

  // --- MENU CONTEXTUEL (Appui long) ---
  void _showCardOptions(BuildContext context, DeckCard card, bool isAlreadyCommander) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
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
                
                ListTile(
                  leading: Icon(Icons.star, color: isAlreadyCommander ? Colors.yellow : Colors.white70),
                  title: Text(isAlreadyCommander ? 'Déjà Commandant' : 'Définir comme Commandant', style: GoogleFonts.cinzel(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    if (!isAlreadyCommander) widget.onSetCommander(card);
                  },
                ),
                
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
                              widget.onUpdateQuantity(card, 0); 
                            }
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
              ],
            ),
          ),
        );        
      }
    );
  }

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