// Fichier : lib/pages/collections/set_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/scryfall_set_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/scryfall_api_service.dart';
import '../../pages/cards/card_detail_page.dart';
import 'set_stats_page.dart';

// --- CLASSE UTILITAIRE POUR L'AFFICHAGE ---
class SetCardDisplayItem {
  final ScryfallCard card;
  final bool isFoil;

  SetCardDisplayItem(this.card, this.isFoil);
}

class SetDetailPage extends StatefulWidget {
  final ScryfallSet set;
  final CollectionService collectionService;
  final WishlistService wishlistService;
  final ScryfallApiService apiService;

  const SetDetailPage({
    super.key,
    required this.set,
    required this.collectionService,
    required this.wishlistService,
    required this.apiService,
  });

  @override
  State<SetDetailPage> createState() => _SetDetailPageState();
}

class _SetDetailPageState extends State<SetDetailPage> {
  // --- DONNÉES ---
  List<ScryfallCard> _allCards = [];
  List<SetCardDisplayItem> _gridItems = []; 
  bool _isLoading = true;
  
  // --- ÉTATS ---
  Set<String> _ownedKeys = {}; 
  Set<String> _wishlistKeys = {}; 
  Set<String> _selectedKeys = {}; 
  
  Map<String, int> _rarityCounts = {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0};

  // --- FILTRES ---
  final TextEditingController _searchController = TextEditingController();
  SearchFilters _activeFilters = SearchFilters();
  String _sortBy = 'number';
  bool _sortAsc = true;
  bool _hideOwned = false;

  @override
  void initState() {
    super.initState();
    _loadSetCards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _makeKey(String id, bool isFoil) => "$id|${isFoil ? 'foil' : 'normal'}";

  Future<void> _loadSetCards() async {
    setState(() => _isLoading = true);

    // 1. Collection
    final col = await widget.collectionService.loadCollection();
    _ownedKeys.clear();
    for (var c in col) _ownedKeys.add(_makeKey(c.scryfallId, c.isFoil));

    // 2. Wishlists
    final wishlists = await widget.wishlistService.loadWishlists();
    _wishlistKeys.clear();
    for (var w in wishlists) {
      for (var c in w.cards) _wishlistKeys.add(_makeKey(c.scryfallId, c.isFoil));
    }

    // 3. API
    List<ScryfallCard> accumulator = [];

    try {
      // Premier appel via searchCards
      Map<String, dynamic> data = await widget.apiService.searchCards(
        'e:${widget.set.code}',
        unique: 'prints',
        order: 'set',
      );
      final List<dynamic> firstRaw = data['data'] ?? [];
      accumulator.addAll(firstRaw.map((j) => ScryfallCard.fromJson(j)).toList());

      // Pagination via fetchNextPage
      String? nextPageUrl = data['has_more'] == true ? data['next_page'] : null;
      while (nextPageUrl != null) {
        data = await widget.apiService.fetchNextPage(nextPageUrl);
        nextPageUrl = data['has_more'] == true ? data['next_page'] : null;
        final List<dynamic> raw = data['data'] ?? [];
        accumulator.addAll(raw.map((j) => ScryfallCard.fromJson(j)).toList());
      }

      Map<String, int> counts = {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0};
      for (var c in accumulator) {
        final r = c.rarity.toLowerCase();
        if (counts.containsKey(r)) counts[r] = (counts[r] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _allCards = accumulator;
          _rarityCounts = counts;
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    final query = _searchController.text.toLowerCase().trim();
    
    List<ScryfallCard> filtered = _allCards.where((card) {
      // 1. Recherche Texte
      if (query.isNotEmpty) {
        bool matchName = card.name.toLowerCase().contains(query);
        bool matchNum = card.collectorNumber.toLowerCase() == query;
        if (!matchName && !matchNum) return false;
      }

      // 2. Masquer les possédées
      if (_hideOwned) {
         final keyNormal = _makeKey(card.id, false);
         final keyFoil = _makeKey(card.id, true);
         bool isOwned = _ownedKeys.contains(keyNormal) || _ownedKeys.contains(keyFoil);
         if (isOwned) return false;
      }

      // 3. Type
      if (_activeFilters.cardType != null && !card.typeLine.toLowerCase().contains(_activeFilters.cardType!.toLowerCase())) return false;
      
      // 4. Rareté
      if (_activeFilters.rarity != null && card.rarity.toLowerCase() != _activeFilters.rarity!.toLowerCase()) return false;
      
      // 5. Couleurs (W, U, B, R, G, C, M)
      if (_activeFilters.colors.isNotEmpty) {
        final cardColors = card.colorIdentity.toSet();
        
        bool wantsColorless = _activeFilters.colors.contains('C');
        bool wantsMulti = _activeFilters.colors.contains('M');
        Set<String> standardColors = _activeFilters.colors.where((c) => !['C', 'M'].contains(c)).toSet();

        bool match = false;
        
        // Logique "OU"
        if (wantsColorless && cardColors.isEmpty) match = true;
        if (wantsMulti && cardColors.length > 1) match = true;
        if (standardColors.isNotEmpty && cardColors.any((c) => standardColors.contains(c))) match = true;

        if (!match) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      int result = 0;
      switch (_sortBy) {
        case 'name': result = a.name.compareTo(b.name); break;
        case 'rarity':
          final rarities = {'mythic': 3, 'rare': 2, 'uncommon': 1, 'common': 0};
          result = (rarities[a.rarity] ?? 0).compareTo(rarities[b.rarity] ?? 0);
          break;
        case 'price':
          double pA = double.tryParse(a.prices['eur'] ?? '0') ?? 0;
          double pB = double.tryParse(b.prices['eur'] ?? '0') ?? 0;
          result = pA.compareTo(pB);
          break;
        case 'number':
        default:
          int nA = int.tryParse(a.collectorNumber) ?? 9999;
          int nB = int.tryParse(b.collectorNumber) ?? 9999;
          result = (nA == nB) ? a.collectorNumber.compareTo(b.collectorNumber) : nA.compareTo(nB);
          break;
      }
      return _sortAsc ? result : -result;
    });

    List<SetCardDisplayItem> newGridItems = [];
    for (var card in filtered) {
      bool hasNormal = card.prices['eur'] != null || card.prices['usd'] != null;
      bool hasFoil = card.prices['eur_foil'] != null || card.prices['usd_foil'] != null;
      if (!hasNormal && !hasFoil) hasNormal = true;

      if (hasNormal) newGridItems.add(SetCardDisplayItem(card, false));
      if (hasFoil) newGridItems.add(SetCardDisplayItem(card, true));
    }

    setState(() {
      _gridItems = newGridItems;
    });
  }
  
  // --- ACTIONS DE SÉLECTION ---
  void _toggleSelection(String id, bool isFoil) {
    final key = _makeKey(id, isFoil);
    setState(() {
      if (_selectedKeys.contains(key)) _selectedKeys.remove(key); else _selectedKeys.add(key);
    });
  }

  void _selectAllMissingFiltered() {
    for (var item in _gridItems) {
      final key = _makeKey(item.card.id, item.isFoil);
      if (!_ownedKeys.contains(key)) _selectedKeys.add(key);
    }
    setState(() {});
  }

  void _clearSelection() => setState(() => _selectedKeys.clear());

  // --- ACTIONS PRINCIPALES (Ajout/Retrait) ---

  Future<void> _addSelectedTo(bool toCollection) async {
    if (_selectedKeys.isEmpty) return;
    
    String? targetWishlistId;
    if (!toCollection) {
      targetWishlistId = await _askWishlistDestination();
      if (targetWishlistId == null) return; 
    }

    setState(() => _isLoading = true);
    int count = 0;

    for (String key in _selectedKeys) {
      final parts = key.split('|');
      final id = parts[0];
      final isFoil = parts[1] == 'foil';
      try {
        final card = _allCards.firstWhere((c) => c.id == id);
        if (toCollection) {
          await widget.collectionService.addCard(card, 1, isFoil: isFoil);
        } else {
          await widget.wishlistService.upsertCard(
            wishlistId: targetWishlistId, 
            scryfallId: card.id, cardName: card.name, 
            quantityToAdd: 1, isFoil: isFoil
          );
        }
        count++;
      } catch (e) { /* */ }
    }
    
    await _refreshKeys();
    setState(() { _isLoading = false; _selectedKeys.clear(); });
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count cartes ajoutées !", style: GoogleFonts.cinzel()), backgroundColor: Colors.green));
  }

  Future<void> _removeSelectedFrom(bool fromCollection) async {
    if (_selectedKeys.isEmpty) return;

    final String targetName = fromCollection ? "votre Collection" : "toutes vos Wishlists";
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => _buildThemedDialog(
        context: c,
        title: "Retirer des cartes ?",
        content: "Vous êtes sur le point de retirer ${_selectedKeys.length} cartes de $targetName.\nCette action est irréversible.",
        icon: Icons.delete_forever,
        iconColor: Colors.redAccent,
        confirmText: "RETIRER",
        confirmColor: Colors.red.shade900,
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    int count = 0;

    for (String key in _selectedKeys) {
      final parts = key.split('|');
      final id = parts[0];
      final isFoil = parts[1] == 'foil';
      
      try {
        final card = _allCards.firstWhere((c) => c.id == id);
        
        if (fromCollection) {
          await widget.collectionService.upsertCardInCollection(
            scryfallId: id, cardName: card.name, 
            absoluteQuantity: 0, isFoil: isFoil
          );
        } else {
          final lists = await widget.wishlistService.loadWishlists();
          for(var list in lists) {
             await widget.wishlistService.upsertCard(
               wishlistId: list.id, scryfallId: id, cardName: card.name, 
               absoluteQuantity: 0, isFoil: isFoil
             );
          }
        }
        count++;
      } catch(e) { /* */ }
    }

    await _refreshKeys();
    setState(() { _isLoading = false; _selectedKeys.clear(); });
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count cartes retirées !", style: GoogleFonts.cinzel()), backgroundColor: Colors.redAccent));
  }

  Future<void> _refreshKeys() async {
    final col = await widget.collectionService.loadCollection();
    _ownedKeys.clear();
    for (var c in col) _ownedKeys.add(_makeKey(c.scryfallId, c.isFoil));

    final w = await widget.wishlistService.loadWishlists();
    _wishlistKeys.clear();
    for (var l in w) for (var c in l.cards) _wishlistKeys.add(_makeKey(c.scryfallId, c.isFoil));
  }

  Future<String?> _askWishlistDestination() async {
    final wishlists = await widget.wishlistService.loadWishlists();
    final String setName = widget.set.name;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Choisir une Wishlist", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white10, height: 1),
              
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.greenAccent),
                ),
                title: Text("Nouvelle liste : $setName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await widget.wishlistService.createWishlist(setName);
                  final updatedLists = await widget.wishlistService.loadWishlists();
                  final newList = updatedLists.lastWhere((w) => w.name == setName);
                  if (mounted) Navigator.pop(context, newList.id);
                },
              ),
              const Divider(color: Colors.white10),
              
              Expanded(
                child: ListView.separated(
                  itemCount: wishlists.length,
                  separatorBuilder: (_,__) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final w = wishlists[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: const Icon(Icons.bookmark_border, color: Colors.blueAccent),
                      title: Text(w.name, style: GoogleFonts.cinzel(color: Colors.white70)),
                      subtitle: Text("${w.totalCards} cartes", style: const TextStyle(color: Colors.white30, fontSize: 12)),
                      onTap: () => Navigator.pop(context, w.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MODALE DE FILTRES ---
  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea( // <--- CORRECTION : Ajout du SafeArea ici
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
                  color: const Color(0xFF1A1A1A),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Filtres du Set", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    
                    // --- 1. COULEURS (ICONES MANA) ---
                    Text("Couleurs", style: GoogleFonts.cinzel(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12, runSpacing: 10, alignment: WrapAlignment.center,
                      children: [
                        _buildManaIconBtn('W', setModalState),
                        _buildManaIconBtn('U', setModalState),
                        _buildManaIconBtn('B', setModalState),
                        _buildManaIconBtn('R', setModalState),
                        _buildManaIconBtn('G', setModalState),
                        _buildManaIconBtn('C', setModalState),
                        _buildManaIconBtn('M', setModalState, isMulti: true), // Gold for Multi
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- 2. TYPES ---
                    Text("Type de carte", style: GoogleFonts.cinzel(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: ['Creature', 'Instant', 'Sorcery', 'Artifact', 'Enchantment', 'Land', 'Planeswalker'].map((type) {
                        final isSelected = _activeFilters.cardType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (val) {
                            setModalState(() {
                              _activeFilters = _activeFilters.copyWith(cardType: val ? type : null);
                            });
                          },
                          selectedColor: Colors.yellow.shade900,
                          backgroundColor: Colors.black45,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // --- 3. OPTIONS ---
                    Text("Options d'affichage", style: GoogleFonts.cinzel(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _activeFilters.rarity,
                            decoration: const InputDecoration(labelText: "Rareté", filled: true, fillColor: Colors.black45),
                            dropdownColor: const Color(0xFF2A2A2A),
                            items: [
                              const DropdownMenuItem(value: null, child: Text("Toutes")),
                              const DropdownMenuItem(value: 'common', child: Text("Commune")),
                              const DropdownMenuItem(value: 'uncommon', child: Text("Unco")),
                              const DropdownMenuItem(value: 'rare', child: Text("Rare")),
                              const DropdownMenuItem(value: 'mythic', child: Text("Mythique")),
                            ],
                            onChanged: (val) => setModalState(() => _activeFilters = _activeFilters.copyWith(rarity: val)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilterChip(
                            label: const Text("Masquer possédées"),
                            selected: _hideOwned,
                            onSelected: (val) => setModalState(() => _hideOwned = val),
                            selectedColor: Colors.green.withOpacity(0.3),
                            checkmarkColor: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        _applyFiltersAndSort();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text("APPLIQUER", style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- BOUTON MANA ICON ---
  Widget _buildManaIconBtn(String code, StateSetter setModalState, {bool isMulti = false}) {
    final isSelected = _activeFilters.colors.contains(code);
    
    // Pour M (Multi), on utilise un cercle doré car pas de symbole svg standard
    // Pour les autres, on utilise le SVG Scryfall
    Widget content;
    if (isMulti) {
      content = Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFE6D68F), Color(0xFFC7A94E)], // Or
            begin: Alignment.topLeft, end: Alignment.bottomRight
          )
        ),
        child: Center(child: Text("M", style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16))),
      );
    } else {
      content = SvgPicture.network(
        'https://svgs.scryfall.io/card-symbols/$code.svg',
        placeholderBuilder: (_) => CircleAvatar(backgroundColor: Colors.grey, child: Text(code)),
      );
    }

    return GestureDetector(
      onTap: () {
        setModalState(() {
          final newColors = Set<String>.from(_activeFilters.colors);
          if (isSelected) newColors.remove(code); else newColors.add(code);
          _activeFilters = _activeFilters.copyWith(colors: newColors);
        });
      },
      child: Opacity(
        opacity: isSelected ? 1.0 : 0.4, // Grisé si non sélectionné
        child: Container(
          width: 40, height: 40,
          decoration: isSelected 
            ? BoxDecoration(
                shape: BoxShape.circle, 
                boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 10)]
              ) 
            : null,
          child: content,
        ),
      ),
    );
  }

  // --- HELPER DIALOGUE STYLISÉ ---
  Widget _buildThemedDialog({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required String confirmText,
    required Color confirmColor,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: iconColor.withOpacity(0.5), width: 1.5)),
      title: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
      content: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Annuler", style: GoogleFonts.cinzel(color: Colors.white54))),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white, elevation: 4),
          child: Text(confirmText, style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openStats() async {
    final fullCollection = await widget.collectionService.loadCollection();
    final setCollection = fullCollection.where((dc) => _allCards.any((sc) => sc.id == dc.scryfallId)).toList();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => SetStatsPage(targetSet: widget.set, myCollection: setCollection, fullSetData: _allCards)
    ));
  }

  @override
  Widget build(BuildContext context) {
    final int totalSetCount = _allCards.length;
    final int totalOwnedUnique = _allCards.where((c) => _ownedKeys.contains(_makeKey(c.id, false)) || _ownedKeys.contains(_makeKey(c.id, true))).length;
    final int totalMissing = totalSetCount - totalOwnedUnique;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.set.name, style: GoogleFonts.cinzel(fontSize: 16)),
            Text("${widget.set.code.toUpperCase()} • ${_gridItems.length} items", style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          if (!_isLoading) IconButton(icon: const Icon(Icons.pie_chart, color: Colors.amber), tooltip: "Stats", onPressed: _openStats),
          if (_selectedKeys.isNotEmpty)
             IconButton(icon: const Icon(Icons.deselect), onPressed: _clearSelection)
          else if (!_isLoading)
            IconButton(icon: const Icon(Icons.select_all), onPressed: _selectAllMissingFiltered),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Column(
            children: [
               _buildStatsHeader(totalMissing, totalSetCount),
               
               // --- BARRE DE CONTRÔLE ---
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 color: Colors.black.withOpacity(0.3),
                 child: Row(
                   children: [
                     Expanded(
                       child: Container(
                         height: 40,
                         decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                         child: TextField(
                           controller: _searchController,
                           style: const TextStyle(color: Colors.white),
                           decoration: const InputDecoration(
                             hintText: "Rechercher...",
                             hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                             border: InputBorder.none,
                             prefixIcon: Icon(Icons.search, color: Colors.white54, size: 20),
                             contentPadding: EdgeInsets.symmetric(vertical: 10),
                           ),
                           onChanged: (_) => _applyFiltersAndSort(),
                         ),
                       ),
                     ),
                     const SizedBox(width: 8),
                     
                     // BOUTON FILTRE (Mis à jour avec indicateur actif)
                     Container(
                       decoration: BoxDecoration(
                         color: (_activeFilters.colors.isNotEmpty || _activeFilters.cardType != null || _hideOwned) ? Colors.yellow.shade900 : Colors.white.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(8)
                       ),
                       child: IconButton(
                         icon: const Icon(Icons.filter_list, color: Colors.white70),
                         onPressed: _openFilterModal,
                       ),
                     ),
                     const SizedBox(width: 4),
                     
                     // BOUTON TRI
                     Container(
                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                       child: _buildSortMenu(),
                     ),
                   ],
                 ),
               ),

               Expanded(
                 child: _gridItems.isEmpty 
                  ? Center(
                      // --- EASTER EGG STAR WARS ---
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.filter_none, size: 48, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text(
                            "Ce ne sont pas les cartes que vous recherchez...", 
                            style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text("👋🤖", style: TextStyle(fontSize: 24)),
                        ],
                      ),
                    )
                  : GridView.builder(
                     padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100), 
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8
                     ),
                     itemCount: _gridItems.length,
                     itemBuilder: (context, index) {
                       return _buildCardTile(_gridItems[index]);
                     },
                   ),
               ),
            ],
          ),
      bottomNavigationBar: _selectedKeys.isNotEmpty ? _buildBottomActionAmount() : null,
    );
  }

  // --- WIDGETS ---

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, color: Colors.white70, size: 20),
      color: const Color(0xFF1A1A1A),
      onSelected: (val) {
        setState(() {
          if (_sortBy == val) _sortAsc = !_sortAsc;
          else { _sortBy = val; _sortAsc = true; }
          _applyFiltersAndSort();
        });
      },
      itemBuilder: (ctx) => [
        _buildPopupItem('number', 'Numéro', Icons.format_list_numbered),
        _buildPopupItem('name', 'Nom', Icons.sort_by_alpha),
        _buildPopupItem('rarity', 'Rareté', Icons.diamond),
        _buildPopupItem('price', 'Prix', Icons.euro),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String text, IconData icon) {
    final bool isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Colors.yellow : Colors.white54, size: 18),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: isSelected ? Colors.yellow : Colors.white)),
          if (isSelected) ...[
            const Spacer(),
            Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.yellow, size: 14)
          ]
        ],
      ),
    );
  }

  Widget _buildCardTile(SetCardDisplayItem item) {
    final ScryfallCard card = item.card;
    final bool isFoilSlot = item.isFoil;
    
    final String key = _makeKey(card.id, isFoilSlot);
    final bool isOwned = _ownedKeys.contains(key);
    final bool isSelected = _selectedKeys.contains(key);
    final bool isWanted = _wishlistKeys.contains(key);

    return GestureDetector(
      onTap: () => _toggleSelection(card.id, isFoilSlot),
      onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: card.name))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: isSelected ? 1.0 : (isOwned ? 1.0 : 0.4),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6), 
                side: isSelected 
                  ? BorderSide(color: Colors.yellow.shade700, width: 3) 
                  : (isOwned ? BorderSide(color: Colors.green.shade800, width: 2) : BorderSide.none)
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(card.smallImageUrl ?? '', fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[800], child: const Icon(Icons.image_not_supported))),
                  if (isFoilSlot)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Colors.transparent, Colors.purple.withOpacity(0.3), Colors.transparent, Colors.amber.withOpacity(0.3)],
                          stops: const [0.0, 0.4, 0.6, 1.0]
                        )
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          if (isSelected)
            Positioned(top: 4, right: 4, child: Container(decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.yellow, size: 24))),
          if (isOwned && !isSelected)
             Positioned(top: 4, left: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.inventory_2, color: Colors.green, size: 16))),
          if (isWanted && !isSelected && !isOwned)
             Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(Icons.star, color: Colors.blue.shade400, size: 16))),

          Positioned(
            bottom: 4, right: 4, 
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), 
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)), 
              child: Text(isFoilSlot ? "FOIL" : "NORM", style: TextStyle(color: isFoilSlot ? Colors.amberAccent : Colors.white, fontSize: 9, fontWeight: FontWeight.bold))
            )
          ),
          
          Positioned(bottom: 4, left: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text("#${card.collectorNumber}", style: const TextStyle(color: Colors.white, fontSize: 10)))),
        ],
      ),
    );
  }

  Widget _buildBottomActionAmount() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), 
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2C2C2C), Color(0xFF111111)]),
        border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2.0)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style, color: Colors.yellow.shade800, size: 16),
                const SizedBox(width: 8),
                Text("${_selectedKeys.length} sélectionné(s)", style: GoogleFonts.cinzel(color: const Color(0xFFE0E0E0), fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildActionButton(icon: Icons.star_border, color: Colors.red.shade300, label: "Suppr.", isNegative: true, onTap: () => _removeSelectedFrom(false))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildActionButton(icon: Icons.star, color: Colors.blueAccent, label: "Wishlist", onTap: () => _addSelectedTo(false))),
                    ],
                  ),
                ),
                Container(height: 32, width: 1, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 8)),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildActionButton(icon: Icons.inventory_2_outlined, color: Colors.red.shade300, label: "Suppr.", isNegative: true, onTap: () => _removeSelectedFrom(true))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildActionButton(icon: Icons.inventory_2, color: Colors.green, label: "Collect.", onTap: () => _addSelectedTo(true))),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap, bool isNegative = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isNegative ? color.withOpacity(0.1) : color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int missingCount, int totalCount) {
    final int ownedCount = totalCount - missingCount;
    final double progress = totalCount > 0 ? ownedCount / totalCount : 0.0;
    final String percentage = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("PROGRESSION", style: GoogleFonts.cinzel(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("$ownedCount", style: GoogleFonts.cinzel(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(" / $totalCount", style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14)),
                      const SizedBox(width: 8),
                      Text("$percentage%", style: GoogleFonts.roboto(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildRarityBadge("M", Colors.orange.shade900, _rarityCounts['mythic'] ?? 0),
                  const SizedBox(width: 6),
                  _buildRarityBadge("R", Colors.amber, _rarityCounts['rare'] ?? 0),
                  const SizedBox(width: 6),
                  _buildRarityBadge("U", Colors.blueGrey, _rarityCounts['uncommon'] ?? 0),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth * progress,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF10B981)],
                        stops: [0.0, 0.6, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 6, spreadRadius: 0, offset: const Offset(0, 0))
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRarityBadge(String letter, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          Text(letter, style: GoogleFonts.cinzel(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text("$count", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}