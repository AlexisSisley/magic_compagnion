// Fichier : lib/pages/collections/set_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/scryfall_set_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../pages/cards/card_detail_page.dart';

class SetDetailPage extends StatefulWidget {
  final ScryfallSet set;
  final CollectionService collectionService;
  final WishlistService wishlistService;

  const SetDetailPage({
    super.key, 
    required this.set, 
    required this.collectionService,
    required this.wishlistService,
  });

  @override
  State<SetDetailPage> createState() => _SetDetailPageState();
}

class _SetDetailPageState extends State<SetDetailPage> {
  // Données brutes
  List<ScryfallCard> _allCards = [];
  // Données affichées
  List<ScryfallCard> _displayedCards = [];
  
  bool _isLoading = true;
  Set<String> _ownedIds = {}; 
  Set<String> _wishlistIds = {}; 
  Set<String> _selectedIds = {}; 
  
  Map<String, int> _rarityCounts = {
    'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0
  };

  final Set<String> _selectedRarities = {}; 
  final Set<String> _selectedColors = {};   

  @override
  void initState() {
    super.initState();
    _loadSetCards();
  }

  // --- CHARGEMENT ---
  Future<void> _loadSetCards() async {
    setState(() => _isLoading = true);

    final col = await widget.collectionService.loadCollection();
    _ownedIds = col.map((c) => c.scryfallId).toSet();

    final wishlists = await widget.wishlistService.loadWishlists();
    _wishlistIds = wishlists.expand((w) => w.cards).map((c) => c.scryfallId).toSet();

    List<ScryfallCard> accumulator = [];
    String? nextPageUrl = 'https://api.scryfall.com/cards/search?q=e:${widget.set.code}&unique=prints&order=set';

    try {
      while (nextPageUrl != null) {
        final response = await http.get(Uri.parse(nextPageUrl));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          nextPageUrl = data['has_more'] == true ? data['next_page'] : null;
          final List<dynamic> raw = data['data'] ?? [];
          accumulator.addAll(raw.map((j) => ScryfallCard.fromJson(j)).toList());
          if (nextPageUrl != null) await Future.delayed(const Duration(milliseconds: 50));
        } else {
          nextPageUrl = null;
        }
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
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FILTRES ---
  void _applyFilters() {
    setState(() {
      _displayedCards = _allCards.where((card) {
        if (_selectedRarities.isNotEmpty && !_selectedRarities.contains(card.rarity.toLowerCase())) return false;
        
        if (_selectedColors.isNotEmpty) {
          bool matchColor = false;
          if (_selectedColors.contains('C') && card.colorIdentity.isEmpty) matchColor = true;
          else if (_selectedColors.contains('M') && card.colorIdentity.length > 1) matchColor = true;
          else {
            for (var color in _selectedColors) {
              if (['W','U','B','R','G'].contains(color) && card.colorIdentity.contains(color)) {
                matchColor = true;
                break;
              }
            }
          }
          if (!matchColor) return false;
        }
        return true;
      }).toList();
    });
  }

  void _toggleRarityFilter(String rarity) {
    if (_selectedRarities.contains(rarity)) _selectedRarities.remove(rarity); else _selectedRarities.add(rarity);
    _applyFilters();
  }

  void _toggleColorFilter(String colorSymbol) {
    if (_selectedColors.contains(colorSymbol)) _selectedColors.remove(colorSymbol); else _selectedColors.add(colorSymbol);
    _applyFilters();
  }

  // --- SÉLECTION ---
  void _toggleSelection(String cardId) {
    setState(() {
      if (_selectedIds.contains(cardId)) _selectedIds.remove(cardId); else _selectedIds.add(cardId);
    });
  }

  void _selectAllMissingFiltered() {
    final missingInView = _displayedCards.where((c) => !_ownedIds.contains(c.id)).map((c) => c.id).toSet();
    setState(() => _selectedIds.addAll(missingInView));
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  // --- ACTIONS ---

  /// Affiche une modale pour choisir la wishlist de destination
  /// Retourne l'ID de la wishlist choisie, ou null si annulé.
  Future<String?> _askWishlistDestination() async {
    final wishlists = await widget.wishlistService.loadWishlists();
    final String setName = widget.set.name;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("Ajouter à...", style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
          children: [
            // Option 1 : Créer une nouvelle liste pour ce set
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              onPressed: () async {
                // On crée la liste
                await widget.wishlistService.createWishlist(setName);
                // On recharge pour récupérer son ID (c'est la dernière créée)
                final updatedLists = await widget.wishlistService.loadWishlists();
                final newList = updatedLists.lastWhere((w) => w.name == setName, orElse: () => updatedLists.last);
                
                if (mounted) Navigator.pop(context, newList.id);
              },
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Nouvelle : $setName",
                      style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            // Option 2 : Listes existantes
            if (wishlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Aucune liste existante.", style: TextStyle(color: Colors.white54)),
              )
            else
              ...wishlists.map((w) => SimpleDialogOption(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onPressed: () => Navigator.pop(context, w.id),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Text(w.name, style: GoogleFonts.cinzel(color: Colors.white70)),
                  ],
                ),
              )),
          ],
        );
      },
    );
  }

  Future<void> _addSelectedTo(bool toCollection) async {
    if (_selectedIds.isEmpty) return;

    String? targetWishlistId;

    // Si c'est pour la Wishlist, on demande où mettre les cartes
    if (!toCollection) {
      targetWishlistId = await _askWishlistDestination();
      if (targetWishlistId == null) return; // Annulé par l'utilisateur
    }

    setState(() => _isLoading = true);
    
    int count = 0;
    final cardsToAdd = _allCards.where((c) => _selectedIds.contains(c.id)).toList();

    for (var card in cardsToAdd) {
      if (toCollection) {
        await widget.collectionService.addCard(card, 1);
      } else {
        // Ajout à la wishlist spécifique
        await widget.wishlistService.upsertCard(
          wishlistId: targetWishlistId,
          scryfallId: card.id,
          cardName: card.name,
          quantityToAdd: 1
        );
      }
      count++;
    }
    
    // Rafraichissement des indicateurs
    if (toCollection) {
      final col = await widget.collectionService.loadCollection();
      _ownedIds = col.map((c) => c.scryfallId).toSet();
    } else {
      final w = await widget.wishlistService.loadWishlists();
      _wishlistIds = w.expand((l) => l.cards).map((c) => c.scryfallId).toSet();
    }

    setState(() { _isLoading = false; _selectedIds.clear(); });
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count cartes ajoutées !"), backgroundColor: Colors.green));
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final int totalSetCount = _allCards.length;
    final int totalOwned = _allCards.where((c) => _ownedIds.contains(c.id)).length;
    final int totalMissing = totalSetCount - totalOwned;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.set.name, style: GoogleFonts.cinzel(fontSize: 16)),
            Text("${widget.set.code.toUpperCase()} • ${_displayedCards.length} affichées", style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          if (_selectedIds.isNotEmpty)
             IconButton(icon: const Icon(Icons.deselect), tooltip: "Tout désélectionner", onPressed: _clearSelection)
          else if (!_isLoading)
            IconButton(icon: const Icon(Icons.select_all), tooltip: "Sélectionner les manquantes (visibles)", onPressed: _selectAllMissingFiltered),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Column(
            children: [
               _buildStatsHeader(totalMissing, totalSetCount),
               _buildQuickFilters(),
               Expanded(
                 child: _displayedCards.isEmpty 
                  ? Center(child: Text("Aucune carte trouvée", style: GoogleFonts.cinzel(color: Colors.white30)))
                  : GridView.builder(
                     padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100), 
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8
                     ),
                     itemCount: _displayedCards.length,
                     itemBuilder: (context, index) => _buildCardTile(_displayedCards[index]),
                   ),
               ),
            ],
          ),
      bottomNavigationBar: _selectedIds.isNotEmpty ? _buildBottomActionAmount() : null,
    );
  }

  // --- WIDGETS ---

  Widget _buildBottomActionAmount() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), 
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2C2C2C), Color(0xFF111111)]),
        border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2.0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.style, color: Colors.yellow.shade800, size: 20),
                   const SizedBox(width: 8),
                   Flexible(
                     child: Text("${_selectedIds.length} carte(s)", style: GoogleFonts.cinzel(color: const Color(0xFFE0E0E0), fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                   ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _addSelectedTo(false), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A), foregroundColor: const Color(0xFFBFDBFE), 
                    side: BorderSide(color: Colors.blue.shade300.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.star, size: 16),
                  label: Text("Wishlist", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _addSelectedTo(true), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B), foregroundColor: const Color(0xFFA7F3D0),
                    side: BorderSide(color: Colors.green.shade300.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.inventory_2, size: 16),
                  label: Text("Collect.", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCardTile(ScryfallCard card) {
    final bool isOwned = _ownedIds.contains(card.id);
    final bool isSelected = _selectedIds.contains(card.id);
    final bool isWanted = _wishlistIds.contains(card.id);

    return GestureDetector(
      onTap: () => _toggleSelection(card.id),
      onLongPress: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: card.name)));
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: isSelected ? 1.0 : (isOwned ? 1.0 : 0.4),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: isSelected ? BorderSide(color: Colors.yellow.shade700, width: 3) : (isOwned ? BorderSide(color: Colors.green.shade800, width: 2) : BorderSide.none)),
              child: Image.network(card.smallImageUrl ?? '', fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[800], child: const Icon(Icons.image_not_supported))),
            ),
          ),
          if (isSelected)
            Positioned(top: 4, right: 4, child: Container(decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.yellow, size: 24))),
           if (isOwned && !isSelected)
             Positioned(top: 4, left: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.inventory_2, color: Colors.green, size: 16))),
           
           if (isWanted && !isSelected && !isOwned)
             Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(Icons.star, color: Colors.blue.shade400, size: 16))),

            Positioned(bottom: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text("#${card.collectorNumber}", style: const TextStyle(color: Colors.white, fontSize: 10)))),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      color: Colors.black26,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildColorFilterBtn('W'), _buildColorFilterBtn('U'), _buildColorFilterBtn('B'),
                _buildColorFilterBtn('R'), _buildColorFilterBtn('G'),
                _buildColorFilterBtn('C', label: 'C'), _buildColorFilterBtn('M', label: 'Multi'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRarityFilterBtn('common', 'C', Colors.white), _buildRarityFilterBtn('uncommon', 'U', Colors.blueGrey.shade300),
              _buildRarityFilterBtn('rare', 'R', Colors.amber), _buildRarityFilterBtn('mythic', 'M', Colors.orange.shade800),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorFilterBtn(String symbol, {String? label}) {
    final isSelected = _selectedColors.contains(symbol);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: () => _toggleColorFilter(symbol),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(2), 
          decoration: BoxDecoration(shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.yellow, width: 2) : null),
          child: Opacity(
            opacity: (_selectedColors.isEmpty || isSelected) ? 1.0 : 0.3,
            child: label != null 
              ? CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade800, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)))
              : SvgPicture.network('https://svgs.scryfall.io/card-symbols/$symbol.svg', width: 28, height: 28, placeholderBuilder: (_) => CircleAvatar(radius: 14, backgroundColor: Colors.grey, child: Text(symbol))),
          ),
        ),
      ),
    );
  }

  Widget _buildRarityFilterBtn(String rarityKey, String label, Color color) {
    final isSelected = _selectedRarities.contains(rarityKey);
    return InkWell(
      onTap: () => _toggleRarityFilter(rarityKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.2) : Colors.transparent, border: Border.all(color: isSelected ? color : Colors.white12), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white38, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatsHeader(int missingCount, int totalCount) {
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [const Icon(Icons.pie_chart_outline, color: Colors.white54, size: 14), const SizedBox(width: 8), Text("$missingCount manquantes / $totalCount", style: const TextStyle(color: Colors.white70, fontSize: 12))]),
          Row(children: [
              _buildRarityCountDot(Colors.orange.shade800, _rarityCounts['mythic'] ?? 0), const SizedBox(width: 4),
              _buildRarityCountDot(Colors.amber, _rarityCounts['rare'] ?? 0), const SizedBox(width: 4),
              _buildRarityCountDot(Colors.blueGrey.shade300, _rarityCounts['uncommon'] ?? 0),
          ])
        ],
      ),
    );
  }

  Widget _buildRarityCountDot(Color color, int count) {
    return Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 2), Text("$count", style: TextStyle(color: color, fontSize: 10))]);
  }
}