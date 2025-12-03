// Fichier : lib/widgets/collection/collection_list_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../../pages/cards/card_detail_page.dart';

class CollectionListTab extends StatefulWidget {
  final List<DeckCard> cards;
  final List<ScryfallCard> fullCardData;
  final String filterQuery;
  final SearchFilters activeFilters;
  final String currentSort;
  final bool isWishlist;
  final double financialTotal;
  final double? evoVal;
  final double? evoPct;
  final bool hasCalculatedFinance;
  final Function() onRefresh;
  final Function(DeckCard, int) onUpdateQuantity;

  // --- Paramètres pour le mode sélection ---
  final bool isSelectionMode;
  final Set<String> selectedIds; // IDs sélectionnés
  final Function(String)? onToggleSelection;

  const CollectionListTab({
    super.key,
    required this.cards,
    required this.fullCardData,
    required this.filterQuery,
    required this.activeFilters,
    required this.currentSort,
    required this.isWishlist,
    required this.financialTotal,
    this.evoVal,
    this.evoPct,
    this.hasCalculatedFinance = false,
    required this.onRefresh,
    required this.onUpdateQuantity,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelection,
  });

  @override
  State<CollectionListTab> createState() => _CollectionListTabState();
}

class _CollectionListTabState extends State<CollectionListTab> {
  double _gridColumns = 1.0; 
  double _lastScale = 1.0;
  final RegExp _manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale > 1.3 && _lastScale <= 1.0) {
      // Zoom In
      setState(() {
        if (_gridColumns > 1) _gridColumns--;
        _lastScale = details.scale;
      });
    } else if (details.scale < 0.7 && _lastScale >= 1.0) {
      // Zoom Out
      setState(() {
        if (_gridColumns < 4) _gridColumns++; // Max 4 colonnes pour lisibilité
        _lastScale = details.scale;
      });
    }
  }

  void _showFinancialDetail() {
    final String title = widget.isWishlist ? "Coût Wishlist" : "Valeur Collection";
    
    List<Map<String, dynamic>> topCards = [];
    
    for (final deckCard in widget.cards) {
       if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
       try {
         final scryfallCard = widget.fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
         final double unitPrice = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
         if (unitPrice > 0) {
           topCards.add({
             'name': scryfallCard.name,
             'unitPrice': unitPrice,
             'quantity': deckCard.quantity,
             'totalPrice': unitPrice * deckCard.quantity,
             'image': scryfallCard.smallImageUrl
           });
         }
       } catch (e) { /* ... */ }
    }

    // Tri par prix total décroissant
    topCards.sort((a, b) => (b['totalPrice'] as double).compareTo(a['totalPrice'] as double));
    final top15 = topCards.take(15).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text(title, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    widget.isWishlist 
                      ? 'Les cartes les plus coûteuses de votre liste de souhaits'
                      : 'Les cartes les plus précieuses de votre collection',
                    style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14)
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: top15.length,
                      separatorBuilder: (ctx, i) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        final item = top15[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: item['image'] != null 
                                ? Image.network(item['image'], width: 40, height: 56, fit: BoxFit.cover)
                                : Container(width: 40, height: 56, color: Colors.grey.shade800),
                          ),
                          title: Text(item['name'], style: GoogleFonts.cinzel(color: Colors.white), overflow: TextOverflow.ellipsis),
                          subtitle: Text('${item['quantity']}x  @ ${item['unitPrice']} €', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Text(
                            '${(item['totalPrice'] as double).toStringAsFixed(2)} €',
                            style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  // --- FILTRAGE & TRI (Inchangé) ---
  List<DeckCard> _filterAndSortList() {
    List<DeckCard> filtered = widget.cards.where((card) {
      if (!card.name.toLowerCase().contains(widget.filterQuery.toLowerCase())) return false;

      if (widget.activeFilters.cardType != null || widget.activeFilters.colors.isNotEmpty) {
        try {
          final scryfallCard = widget.fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
          
          if (widget.activeFilters.cardType != null) {
            if (!scryfallCard.typeLine.toLowerCase().contains(widget.activeFilters.cardType!.toLowerCase())) return false;
          }
          if (widget.activeFilters.colors.isNotEmpty) {
             final cardColors = scryfallCard.colorIdentity.toSet();
             if (!widget.activeFilters.colors.every((c) => cardColors.contains(c))) return false;
          }
        } catch (e) { return false; }
      }
      return true;
    }).toList();

    switch (widget.currentSort) {
      case 'Nom': filtered.sort((a, b) => a.name.compareTo(b.name)); break;
      case 'Prix':
        filtered.sort((a, b) {
          final priceA = _getPrice(a);
          final priceB = _getPrice(b);
          return priceB.compareTo(priceA);
        });
        break;
      case 'Couleur':
        filtered.sort((a, b) {
          final cA = _getCardColorIndex(a.scryfallId);
          final cB = _getCardColorIndex(b.scryfallId);
          return cA.compareTo(cB);
        });
        break;
      case 'Type':
      default:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return filtered;
  }

  double _getPrice(DeckCard c) {
    try {
      final sc = widget.fullCardData.firstWhere((s) => s.id == c.scryfallId);
      return double.tryParse(sc.prices['eur'] ?? '0') ?? 0.0;
    } catch (e) { return 0.0; }
  }
  int _getCardColorIndex(String id) {
    try {
      final sc = widget.fullCardData.firstWhere((s) => s.id == id);
      if (sc.colorIdentity.isEmpty) return 10; 
      if (sc.colorIdentity.length > 1) return 6; 
      const map = {'W': 1, 'U': 2, 'B': 3, 'R': 4, 'G': 5};
      return map[sc.colorIdentity.first] ?? 10;
    } catch (e) { return 10; }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterAndSortList();
    final int currentCols = _gridColumns.round();
    final bool isGrouped = widget.currentSort == 'Type'; 

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: Column(
        children: [
          // Header Financier (Masqué en mode sélection pour gagner de la place)
          if (widget.hasCalculatedFinance && !widget.isSelectionMode)
            _buildFinancialHeader(
              title: widget.isWishlist ? "Coût Wishlist" : "Valeur Collection",
              value: widget.financialTotal,
              evoVal: widget.evoVal,
              evoPct: widget.evoPct,
              onDetailPressed: _showFinancialDetail,
            ),

          // Barre de Contrôle Zoom
          Container(
            color: Colors.black.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (widget.isSelectionMode)
                   Text("${widget.selectedIds.length} sélectionnés", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                else
                   Text("${filteredList.length} cartes", style: GoogleFonts.cinzel(color: Colors.white54)),
                const Spacer(),
                const Icon(Icons.view_agenda, size: 16, color: Colors.white54),
                SizedBox(
                  width: 120,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 2),
                    child: Slider(
                      value: _gridColumns,
                      min: 1, max: 4, divisions: 3, 
                      activeColor: Colors.yellow.shade800, inactiveColor: Colors.white24,
                      onChanged: (v) => setState(() => _gridColumns = v),
                    ),
                  ),
                ),
                const Icon(Icons.grid_view, size: 16, color: Colors.white54),
              ],
            ),
          ),

          Expanded(
            child: GestureDetector(
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: (_) => _lastScale = 1.0,
              child: isGrouped
                  ? _buildGroupedView(filteredList, currentCols)
                  : _buildFlatView(filteredList, currentCols),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatView(List<DeckCard> list, int cols) {
    if (cols == 1) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildCardTile(list[index]),
      );
    } else {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.60, 
          crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildGridTile(list[index]),
      );
    }
  }

  Widget _buildGroupedView(List<DeckCard> list, int cols) {
    Map<String, List<DeckCard>> groupedMap = {
      'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 
      'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [],
    };

    for (final deckCard in list) {
      ScryfallCard? scryfallCard;
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) throw Exception("Local");
        scryfallCard = widget.fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) { /* fallback */ }
      
      final typeLine = scryfallCard?.typeLine ?? deckCard.name;
      final type = _getPrimaryType(typeLine);
      groupedMap[type]?.add(deckCard);
    }

    List<_GroupedCardList> groups = [];
    groupedMap.forEach((title, cards) {
      if (cards.isNotEmpty) {
        cards.sort((a, b) => a.name.compareTo(b.name));
        groups.add(_GroupedCardList(title: title, cards: cards));
      }
    });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90.0, top: 8.0, left: 4.0, right: 4.0),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Text(
                '${group.title} (${group.cards.fold(0, (sum, c) => sum + c.quantity)})', 
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
            if (cols == 1)
              Column(children: group.cards.map((card) => _buildCardTile(card)).toList())
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), 
                padding: const EdgeInsets.symmetric(horizontal: 4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 0.60,
                  crossAxisSpacing: 8, mainAxisSpacing: 8,
                ),
                itemCount: group.cards.length,
                itemBuilder: (context, idx) => _buildGridTile(group.cards[idx]),
              ),
          ],
        );
      },
    );
  }

  // --- TUILE LISTE (CORRIGÉE AVEC BORDURE RARETÉ) ---
  Widget _buildCardTile(DeckCard card) {
    ScryfallCard? scryfallCard;
    try { scryfallCard = widget.fullCardData.firstWhere((s) => s.id == card.scryfallId); } catch(e){}
    
    final bool isSelected = widget.isSelectionMode && widget.selectedIds.contains(card.scryfallId);
    
    // Détermination de la couleur de bordure
    Color borderColor;
    if (isSelected) {
      borderColor = Colors.green;
    } else {
      // Si pas sélectionné, on affiche la rareté
      borderColor = _getRarityColor(scryfallCard?.rarity ?? 'common');
    }

    return Card(
      color: isSelected ? Colors.green.withOpacity(0.2) : Colors.black.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.0),
        // On applique la bordure ici
        side: BorderSide(color: borderColor, width: isSelected ? 2.0 : 1.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        onTap: () { 
          if (widget.isSelectionMode) {
            widget.onToggleSelection?.call(card.scryfallId);
          } else if(scryfallCard != null && !scryfallCard.id.startsWith('LOCAL:')) {
            Navigator.push(context, MaterialPageRoute(builder: (_)=>RecognitionResultPage(cardName: scryfallCard!.name))); 
          }
        },
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: scryfallCard?.smallImageUrl != null 
                ? Image.network(scryfallCard!.smallImageUrl!, width: 40, height: 56, fit: BoxFit.cover)
                : Container(width: 40, height: 56, color: Colors.grey.shade800),
            ),
            if (widget.isSelectionMode)
              Positioned(
                top: 0, left: 0, 
                child: Container(
                  color: Colors.black54, 
                  child: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? Colors.greenAccent : Colors.white, size: 20)
                ),
              )
          ],
        ),
        title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildManaCostRow(scryfallCard?.manaCost),
             if (scryfallCard?.prices['eur'] != null) Text('${scryfallCard!.prices['eur']} €', style: TextStyle(color: Colors.yellow.shade700, fontSize: 12)),
          ],
        ),
        trailing: widget.isSelectionMode 
          ? null 
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54), onPressed: () => widget.onUpdateQuantity(card, -1)),
                Text('${card.quantity}', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54), onPressed: () => widget.onUpdateQuantity(card, 1)),
              ],
            ),
      ),
    );
  }

  // --- TUILE GRILLE (CORRIGÉE AVEC BORDURE RARETÉ) ---
  Widget _buildGridTile(DeckCard card) {
    ScryfallCard? scryfallCard;
    try { scryfallCard = widget.fullCardData.firstWhere((s) => s.id == card.scryfallId); } catch(e){}
    
    final bool isSelected = widget.isSelectionMode && widget.selectedIds.contains(card.scryfallId);
    // ignore: unused_local_variable
    final rarity = scryfallCard?.rarity ?? 'common';
    final manaCost = scryfallCard?.manaCost;
    // Détermination de la couleur de bordure
    Color borderColor;
    double borderWidth = 1.0;

    if (isSelected) {
      borderColor = Colors.greenAccent;
      borderWidth = 3.0;
    } else {
      borderColor = _getRarityColor(scryfallCard?.rarity ?? 'common');
      // Pour les communes (transparente ou blanche faible), on garde 0 ou 1
      borderWidth = borderColor == Colors.transparent ? 0.0 : 1.5; 
    }

    return InkWell(
      onTap: () { 
        if (widget.isSelectionMode) {
          widget.onToggleSelection?.call(card.scryfallId);
        } else if (scryfallCard != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => RecognitionResultPage(cardName: scryfallCard!.name))); 
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10), 
          side: BorderSide(color: borderColor, width: borderWidth)
        ),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (scryfallCard?.smallImageUrl != null)
              Image.network(scryfallCard!.smallImageUrl!, fit: BoxFit.cover)
            else 
              Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.image, color: Colors.white24))),
            // FOND NOIR DÉGRADÉ EN BAS
            Positioned(
              bottom: 0, left: 0, right: 0, height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.95), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Checkbox Overlay
            if (widget.isSelectionMode)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.greenAccent : Colors.white, size: 28),
                ),
              ),
              if (manaCost != null)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                  child: _buildManaCostRow(manaCost, size: 10),
                ),
              ),
            // Controls (Masqués en sélection)
            if (!widget.isSelectionMode) ...[
              Positioned(bottom: 0, left: 0, right: 0, height: 50, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.95), Colors.transparent])))),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                      onTap: () => widget.onUpdateQuantity(card, -1),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.remove, color: Colors.redAccent, size: 16),
                      ),
                    ),
                    Text(
                      "${card.quantity}", 
                      style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                    ),
                    InkWell(
                      onTap: () => widget.onUpdateQuantity(card, 1),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.greenAccent, size: 16),
                      ),
                    ),
                    ],
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  // --- HELPERS VISUELS (RESTAURÉS) ---

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common': return Colors.white24; // Discret
      case 'uncommon': return const Color(0xFFC0C0C0); // Argent
      case 'rare': return const Color(0xFFFFD700); // Or
      case 'mythic': return const Color(0xFFFF4500); // Orange/Rouge
      default: return Colors.transparent;
    }
  }

  Widget _buildFinancialHeader({required String title, required double value, double? evoVal, double? evoPct, required VoidCallback onDetailPressed}) {
    final bool hasEvolution = evoVal != null;
    final isPositive = (evoVal ?? 0) >= 0;
    final color = isPositive ? Colors.green.shade400 : Colors.red.shade400;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final sign = isPositive ? '+' : '';
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.yellow.shade900.withOpacity(0.3), Colors.black.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade800.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${value.toStringAsFixed(2)} €', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          if (hasEvolution)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Sur 7 jours', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 4),
                    Text('$sign${evoVal.toStringAsFixed(2)} €', style: GoogleFonts.cinzel(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('($sign${evoPct!.toStringAsFixed(1)}%)', style: GoogleFonts.cinzel(color: color.withOpacity(0.8), fontSize: 12)),
              ],
            )
          else if (title.contains('Collection'))
             Text('Pas assez de données', style: GoogleFonts.cinzel(color: Colors.white38, fontSize: 10), textAlign: TextAlign.right),

          IconButton(icon: const Icon(Icons.analytics_outlined, color: Colors.white), onPressed: onDetailPressed),
        
        ],
      ),
    );
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

  Widget _buildManaCostRow(String? manaCost, {double size = 14}) {
    if (manaCost == null || manaCost.isEmpty) return const SizedBox.shrink();
    final List<String> symbols = _manaPipRegex.allMatches(manaCost).map((match) => match.group(0)!).toList();
    return Row(
      mainAxisSize: MainAxisSize.min, 
      children: symbols.map((symbol) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0), 
        child: _getManaIcon(symbol, size: size)
      )).toList()
    );
  }

  Widget _getManaIcon(String symbol, {double size = 14}) {
    final String cleanSymbol = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    return SvgPicture.network(
      'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg', 
      height: size, width: size, 
      placeholderBuilder: (context) => Text(symbol, style: GoogleFonts.cinzel(color: Colors.white, fontSize: size))
    );
  }
}

class _GroupedCardList {
  final String title;
  final List<DeckCard> cards;
  _GroupedCardList({required this.title, required this.cards});
}