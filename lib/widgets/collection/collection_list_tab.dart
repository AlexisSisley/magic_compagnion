// Fichier : lib/widgets/collection/collection_list_tab.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../../router/app_router.dart';

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
  final Function(DeckCard)? onToggleFoil;
  final Function(DeckCard, List<String>)? onUpdateTags;
  final List<String> availableTags;

  // Mode Sélection
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final Function(String)? onToggleSelection;
  final VoidCallback? onToggleSelectionMode;

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
    this.onToggleFoil,
    this.onUpdateTags,
    this.availableTags = const [],
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelection,
    this.onToggleSelectionMode,
  });

  @override
  State<CollectionListTab> createState() => _CollectionListTabState();
}

class _CollectionListTabState extends State<CollectionListTab> {
  double _gridColumns = 1.0; 
  double _lastScale = 1.0;
  final RegExp _manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');
  
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale > 1.3 && _lastScale <= 1.0) { setState(() { if (_gridColumns > 1) _gridColumns--; _lastScale = details.scale; }); } 
    else if (details.scale < 0.7 && _lastScale >= 1.0) { setState(() { if (_gridColumns < 4) _gridColumns++; _lastScale = details.scale; }); }
  }

  // --- LOGIQUE METIER ---

  Future<void> _launchURL(String? url) async {
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le lien.")));
    }
  }

  Future<void> _exportAndOpenCardmarket() async {
     StringBuffer sb = StringBuffer();
     for(var c in widget.cards) {
        sb.writeln('${c.quantity} ${c.name}');
     }
     await Clipboard.setData(ClipboardData(text: sb.toString()));
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text('Liste copiée ! Collez-la dans Cardmarket (Mass Entry).'),
         backgroundColor: AppColors.accent,
         duration: Duration(seconds: 3),
       ));
     }
     _launchURL('https://www.cardmarket.com/en/Magic/Wants/MassEntry');
  }

  void _showFinancialDetail() {
    final String title = widget.isWishlist ? 'Coût Wishlist' : 'Valeur Collection';
    
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
      backgroundColor: AppColors.scaffoldBackground,
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
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.synergyNeutral, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text(title, style: AppTextStyles.pageTitle(fontSize: 22)),
                  const SizedBox(height: 10),
                  Text(
                    widget.isWishlist 
                      ? 'Les cartes les plus coûteuses de votre liste de souhaits'
                      : 'Les cartes les plus précieuses de votre collection',
                    style: AppTextStyles.subtitle(color: AppColors.textMuted)
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: top15.length,
                      separatorBuilder: (ctx, i) => const Divider(color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final item = top15[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: item['image'] != null 
                                ? Image.network(item['image'], width: 40, height: 56, fit: BoxFit.cover)
                                : Container(width: 40, height: 56, color: AppColors.greyShade800),
                          ),
                          title: Text(item['name'], style: AppTextStyles.cinzel(), overflow: TextOverflow.ellipsis),
                          subtitle: Text('${item['quantity']}x  @ ${item['unitPrice']} €', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          trailing: Text(
                            '${(item['totalPrice'] as double).toStringAsFixed(2)} €',
                            style: AppTextStyles.bold(color: AppColors.primaryShade700, fontSize: 16),
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

  List<DeckCard> _filterAndSortList() {
    List<DeckCard> filtered = widget.cards.where((card) {
      if (widget.filterQuery.isNotEmpty && !card.name.toLowerCase().contains(widget.filterQuery.toLowerCase())) return false;
      if (widget.activeFilters.tags.isNotEmpty) {
        if (!widget.activeFilters.tags.every((tag) => card.tags.contains(tag))) return false;
      }
      if (widget.activeFilters.cardType != null || widget.activeFilters.colors.isNotEmpty || widget.activeFilters.minCmc != null || widget.activeFilters.keyword != null) {
        try {
          final sc = widget.fullCardData.firstWhere((s) => s.id == card.scryfallId);
          if (widget.activeFilters.cardType != null && !sc.typeLine.toLowerCase().contains(widget.activeFilters.cardType!.toLowerCase())) return false;
          if (widget.activeFilters.colors.isNotEmpty) {
             final colors = sc.colorIdentity.toSet();
             if (!widget.activeFilters.colors.every((c) => colors.contains(c))) return false;
          }
          if (widget.activeFilters.minCmc != null && (sc.cmc ?? 0) < widget.activeFilters.minCmc!) return false;
          if (widget.activeFilters.maxCmc != null && (sc.cmc ?? 0) > widget.activeFilters.maxCmc!) return false;
          if (widget.activeFilters.keyword != null && !sc.rulesText.toLowerCase().contains(widget.activeFilters.keyword!.toLowerCase())) return false;
        } catch (e) { return false; }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      int result = 0;
      switch (widget.activeFilters.sortType) {
        case 'price':
          final pA = _getPrice(a); final pB = _getPrice(b);
          result = pA.compareTo(pB); break;
        case 'cmc':
          final cA = _getCmc(a); final cB = _getCmc(b);
          result = cA.compareTo(cB); break;
        case 'type':
           result = a.name.compareTo(b.name); break; 
        case 'name':
        default:
          result = a.name.compareTo(b.name); break;
      }
      return widget.activeFilters.sortAscending ? result : -result;
    });
    return filtered;
  }

  double _getPrice(DeckCard c) {
    try {
      final sc = widget.fullCardData.firstWhere((s) => s.id == c.scryfallId);
      final key = c.isFoil ? 'eur_foil' : 'eur';
      return double.tryParse(sc.prices[key] ?? sc.prices['eur'] ?? '0') ?? 0.0;
    } catch (e) { return 0.0; }
  }
  
  double _getCmc(DeckCard c) {
    try {
      final sc = widget.fullCardData.firstWhere((s) => s.id == c.scryfallId);
      return sc.cmc ?? 0.0;
    } catch(e) { return 0.0; }
  }

  void _showTagEditor(DeckCard card) {
    final List<String> currentTags = List.from(card.tags);
    final TextEditingController newTagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.scaffoldBackground,
              title: Text('Tags : ${card.name}', style: AppTextStyles.cinzel()),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: currentTags.map((t) => Chip(
                        label: Text(t),
                        backgroundColor: AppColors.accent.withValues(alpha: 0.3),
                        onDeleted: () => setState(() => currentTags.remove(t)),
                      )).toList(),
                    ),
                    const Divider(color: AppColors.borderMedium),
                    const Text('Ajouter un tag :', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: newTagCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Nouveau...'))),
                        IconButton(icon: const Icon(Icons.add, color: AppColors.success), onPressed: () {
                          if (newTagCtrl.text.isNotEmpty) {
                            setState(() => currentTags.add(newTagCtrl.text.trim()));
                            newTagCtrl.clear();
                          }
                        })
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Existants :', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Wrap(
                      spacing: 6,
                      children: widget.availableTags.where((t) => !currentTags.contains(t)).map((t) => ActionChip(
                        label: Text(t),
                        onPressed: () => setState(() => currentTags.add(t)),
                      )).toList(),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () {
                    widget.onUpdateTags?.call(card, currentTags);
                    Navigator.pop(context);
                  }, 
                  child: const Text('Sauvegarder')
                )
              ],
            );
          }
        );
      }
    );
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterAndSortList();
    final int currentCols = _gridColumns.round();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: Column(
        children: [
          // Header Financier (RESTAURÉ)
          if (widget.hasCalculatedFinance && filteredList.isNotEmpty && !widget.isSelectionMode)
             _buildFinancialHeader(
               title: widget.isWishlist ? 'Coût Wishlist' : 'Valeur Collection', 
               value: widget.financialTotal,
               evoVal: widget.evoVal,
               evoPct: widget.evoPct,
               onDetailPressed: _showFinancialDetail
             ),

          // Barre de contrôle visuelle
          Container(
            color: AppColors.textOnPrimary.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (widget.onToggleSelectionMode != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: InkWell(
                      onTap: widget.onToggleSelectionMode,
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(
                        widget.isSelectionMode ? Icons.check_box : Icons.check_box_outline_blank, 
                        color: widget.isSelectionMode ? AppColors.accentGreen : AppColors.textMuted,
                        size: 22
                      ),
                    ),
                  ),
                if (widget.isSelectionMode)
                   Text('${widget.selectedIds.length} sélectionnés', style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold))
                else
                   Text('${filteredList.length} cartes', style: AppTextStyles.cinzel(color: AppColors.textMuted)),
                const Spacer(),
                const Icon(Icons.view_agenda, size: 16, color: AppColors.textMuted),
                SizedBox(
                  width: 120,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 2),
                    child: Slider(
                      value: _gridColumns,
                      min: 1, max: 4, divisions: 3, 
                      activeColor: AppColors.primaryShade800, inactiveColor: AppColors.borderMedium,
                      onChanged: (v) => setState(() => _gridColumns = v),
                    ),
                  ),
                ),
                const Icon(Icons.grid_view, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),

          Expanded(
            child: GestureDetector(
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: (_) => _lastScale = 1.0,
              child: currentCols == 1
                  ? ListView.builder(
                      itemCount: filteredList.length,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemBuilder: (ctx, i) => _buildCardTile(filteredList[i]),
                    )
                  : GridView.builder(
                      itemCount: filteredList.length,
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: currentCols, childAspectRatio: 0.60, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemBuilder: (ctx, i) => _buildGridTile(filteredList[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TUILE LISTE (CORRIGÉE AVEC BORDURE RARETÉ & ÉDITION) ---
  Widget _buildCardTile(DeckCard card) {
    ScryfallCard? scryfallCard;
    try { scryfallCard = widget.fullCardData.firstWhere((s) => s.id == card.scryfallId); } catch(e) { /* Card not found */ }

    final bool isSelected = widget.isSelectionMode && widget.selectedIds.contains(card.scryfallId);
    final String priceDisplay = _getPrice(card).toStringAsFixed(2);
    final String setCode = scryfallCard?.setCode.toUpperCase() ?? '';
    final String rarity = scryfallCard?.rarity ?? 'common';
    
    // Bordure
    Color borderColor;
    if (isSelected) {
      borderColor = AppColors.accentGreen;
    } else {
      borderColor = _getRarityColor(rarity);
    }

    return Card(
      color: isSelected ? Colors.green.withValues(alpha: 0.2) : AppColors.textOnPrimary.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      // Applique la bordure de rareté
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6), 
        side: BorderSide(color: borderColor, width: isSelected ? 2 : 1)
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onTap: () {
          if (widget.isSelectionMode) {
            widget.onToggleSelection?.call(card.scryfallId);
          } else if(scryfallCard != null && !scryfallCard.id.startsWith('LOCAL:')) {
            context.push(AppRoutes.cardDetail, extra: {'cardName': card.name});
          }
        },
        onLongPress: () {
          if (!widget.isSelectionMode) widget.onToggleSelectionMode?.call();
          widget.onToggleSelection?.call(card.scryfallId);
        },
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4), 
              child: scryfallCard?.smallImageUrl != null 
                ? Image.network(scryfallCard!.smallImageUrl!, width: 40, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _)=>Container(width: 40, height: 56, color: AppColors.synergyNeutral))
                : Container(width: 40, height: 56, color: AppColors.greyShade800, child: const Icon(Icons.image, size: 20))
            ),
            if (card.isFoil) 
              Positioned(bottom: 0, right: 0, child: Container(decoration: const BoxDecoration(color: AppColors.overlayVeryDark, shape: BoxShape.circle), child: const Icon(Icons.star, color: AppColors.amber, size: 12))),
            if (isSelected) 
              Positioned(top: 0, left: 0, child: Container(color: AppColors.overlayDark, child: const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 20))),
          ],
        ),
        title: Row(
          children: [
            Expanded(child: Text(card.name, style: AppTextStyles.cinzel(color: card.isFoil ? Colors.amber.shade100 : AppColors.textPrimary, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (card.quantity > 1) 
              Text(' (${card.quantity})', style: const TextStyle(color: AppColors.synergyNeutral, fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Set Code
                if (setCode.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.borderMedium), borderRadius: BorderRadius.circular(4)),
                    child: Text(setCode, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                // Mana Cost
                _buildManaCostRow(scryfallCard?.manaCost, size: 12),
                const Spacer(),
                Text('$priceDisplay €', style: TextStyle(color: AppColors.primaryShade700, fontSize: 12)),
              ],
            ),
            // Tags
            if (card.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Wrap(
                  spacing: 4,
                  children: card.tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.accent.withValues(alpha: 0.5))),
                    child: Text(t, style: const TextStyle(fontSize: 9, color: AppColors.accent)),
                  )).toList(),
                ),
              )
          ],
        ),
        trailing: widget.isSelectionMode 
          ? null 
          : IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              onPressed: () => _showCardOptions(card),
            ),
      ),
    );
  }

  // --- GRID TILE (COMPLETE) ---
  Widget _buildGridTile(DeckCard card) {
    ScryfallCard? scryfallCard;
    try { scryfallCard = widget.fullCardData.firstWhere((s) => s.id == card.scryfallId); } catch(e) { /* Card not found */ }
    final isSelected = widget.isSelectionMode && widget.selectedIds.contains(card.scryfallId);
    final imageUrl = scryfallCard?.smallImageUrl ?? scryfallCard?.imageUrl;
    
    // Bordure
    Color borderColor;
    if (isSelected) {
      borderColor = AppColors.accentGreen;
    } else {
      borderColor = _getRarityColor(scryfallCard?.rarity ?? 'common');
    }

    return InkWell(
      onTap: () {
        if (widget.isSelectionMode) {
          widget.onToggleSelection?.call(card.scryfallId);
        } else if(scryfallCard != null && !scryfallCard.id.startsWith('LOCAL:')) {
          context.push(AppRoutes.cardDetail, extra: {'cardName': card.name});
        }
      },
      onLongPress: () {
        if (!widget.isSelectionMode) widget.onToggleSelectionMode?.call();
        widget.onToggleSelection?.call(card.scryfallId);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor, width: isSelected ? 3 : 1.5), // Epaisseur 1.5 pour rareté
        ),
        color: AppColors.textOnPrimary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(imageUrl, fit: BoxFit.cover)
            else
              Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.image, color: AppColors.borderMedium))),
            
            // Foil Effect
            if (card.isFoil)
              Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.1), AppColors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight))),

            // Overlay selection
            if (isSelected)
              Container(color: Colors.green.withValues(alpha: 0.2)),

            // Gradient bas pour texte
            Positioned(
              bottom: 0, left: 0, right: 0, height: 40,
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.9), AppColors.transparent]))),
            ),

            // Quantité + Foil Badge
            Positioned(
              top: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.overlayVeryDark, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${card.quantity}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    if (card.isFoil) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 12, color: AppColors.amber)),
                  ],
                ),
              ),
            ),

            // Checkbox (si mode selection)
            if (widget.isSelectionMode)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  decoration: const BoxDecoration(color: AppColors.overlayDark, shape: BoxShape.circle),
                  child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? AppColors.accentGreen : AppColors.textPrimary, size: 24),
                ),
              )
            else
              // Menu contextuel (si pas mode selection)
              Positioned(
                top: 0, right: 0,
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.textPrimary, size: 20),
                  onPressed: () => _showCardOptions(card),
                ),
              ),
              
            // Prix en bas
            Positioned(
              bottom: 4, right: 4,
              child: Text('${_getPrice(card).toStringAsFixed(2)}€', style: TextStyle(color: AppColors.primaryShade700, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  void _showCardOptions(DeckCard card) {
    showModalBottomSheet(context: context, backgroundColor: AppColors.scaffoldBackground, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(card.name, style: AppTextStyles.bold())),
        const Divider(color: AppColors.borderMedium),
        ListTile(leading: const Icon(Icons.label, color: AppColors.accent), title: const Text('Gérer les Tags', style: TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(ctx); _showTagEditor(card); }),
        ListTile(leading: const Icon(Icons.add_circle, color: AppColors.success), title: const Text('Ajouter 1', style: TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(ctx); widget.onUpdateQuantity(card, 1); }),
        ListTile(leading: const Icon(Icons.remove_circle, color: AppColors.error), title: const Text('Retirer 1', style: TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(ctx); widget.onUpdateQuantity(card, -1); }),
        if (widget.onToggleFoil != null)
           ListTile(leading: Icon(Icons.star, color: card.isFoil ? AppColors.synergyNeutral : AppColors.amber), title: Text(card.isFoil ? 'Retirer Foil' : 'Passer Foil', style: const TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(ctx); widget.onToggleFoil!(card); }),
      ]),
    ));
  }

  // --- HEADER FINANCIER (LE VÔTRE, RESTAURÉ) ---
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
          colors: [AppColors.primaryShade900.withValues(alpha: 0.3), AppColors.textOnPrimary.withValues(alpha: 0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryShade800.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Partie GAUCHE : Titre + Valeur
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.label(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('${value.toStringAsFixed(2)} €', style: AppTextStyles.pageTitle()),
            ],
          ),
          
          // Partie MILIEU : Evolution (si dispo)
          if (hasEvolution)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Sur 7 jours', style: AppTextStyles.label(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 4),
                    Text('$sign${evoVal.toStringAsFixed(2)} €', style: AppTextStyles.bold(color: color, fontSize: 16)),
                  ],
                ),
                Text('($sign${evoPct!.toStringAsFixed(1)}%)', style: AppTextStyles.cinzel(color: color.withValues(alpha: 0.8), fontSize: 12)),
              ],
            )
          else if (title.contains('Collection'))
             Text('Pas assez de données', style: AppTextStyles.cinzel(color: AppColors.borderFaint, fontSize: 10), textAlign: TextAlign.right),

          // Partie DROITE : Boutons d'action
          Row(
            children: [
               // --- BOUTON PANIER (Seulement pour Wishlist) ---
               if (widget.isWishlist)
                 IconButton(
                   icon: const Icon(Icons.shopping_cart_checkout, color: AppColors.accent),
                   tooltip: 'Acheter sur Cardmarket (Copier liste)',
                   onPressed: _exportAndOpenCardmarket, 
                 ),
               
               // Bouton Analytics existant
               IconButton(
                 icon: const Icon(Icons.analytics_outlined, color: AppColors.textPrimary), 
                 onPressed: onDetailPressed
               ),
            ],
          )
        ],
      ),
    );
  }

  // --- HELPERS ---
  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common': return AppColors.borderMedium; 
      case 'uncommon': return const Color(0xFFC0C0C0); 
      case 'rare': return const Color(0xFFFFD700); 
      case 'mythic': return const Color(0xFFFF4500); 
      default: return AppColors.transparent;
    }
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
      placeholderBuilder: (context) => Text(symbol, style: AppTextStyles.cinzel(fontSize: size))
    );
  }
}
