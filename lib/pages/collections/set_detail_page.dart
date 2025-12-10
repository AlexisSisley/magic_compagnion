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
import 'set_stats_page.dart'; // Pour les stats globales du set

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
  List<ScryfallCard> _allCards = [];
  List<ScryfallCard> _displayedCards = [];
  
  bool _isLoading = true;
  
  // Sets pour savoir ce qu'on possède : Stocke "ID_NORMAL" ou "ID_FOIL"
  Set<String> _ownedKeys = {}; 
  Set<String> _wishlistKeys = {}; 
  Set<String> _selectedKeys = {}; // Clé composite : "scryfallId|foil" ou "scryfallId|normal"
  
  Map<String, int> _rarityCounts = {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0};
  final Set<String> _selectedRarities = {}; 
  final Set<String> _selectedColors = {};   

  @override
  void initState() {
    super.initState();
    _loadSetCards();
  }

  // --- LOGIQUE CLÉ UNIQUE ---
  String _makeKey(String id, bool isFoil) => "$id|${isFoil ? 'foil' : 'normal'}";

  Future<void> _loadSetCards() async {
    setState(() => _isLoading = true);

    // 1. Chargement Collection avec distinction Foil
    final col = await widget.collectionService.loadCollection();
    _ownedKeys.clear();
    for (var c in col) {
      _ownedKeys.add(_makeKey(c.scryfallId, c.isFoil));
    }

    // 2. Chargement Wishlists
    final wishlists = await widget.wishlistService.loadWishlists();
    _wishlistKeys.clear();
    for (var w in wishlists) {
      for (var c in w.cards) {
        _wishlistKeys.add(_makeKey(c.scryfallId, c.isFoil));
      }
    }

    // 3. Récupération Cartes API
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
  void _toggleSelection(String id, bool isFoil) {
    final key = _makeKey(id, isFoil);
    setState(() {
      if (_selectedKeys.contains(key)) _selectedKeys.remove(key); else _selectedKeys.add(key);
    });
  }

  void _selectAllMissingFiltered() {
    // final missingInView = _displayedCards.where((c) => !_ownedIds.contains(c.id)).map((c) => c.id).toSet();
    // setState(() => _selectedIds.addAll(missingInView));
    // Sélectionne toutes les versions Normales ET Foil qui manquent dans la vue actuelle
    for (var c in _displayedCards) {
      final keyNormal = _makeKey(c.id, false);
      // ignore: unused_local_variable
      final keyFoil = _makeKey(c.id, true);
      
      if (!_ownedKeys.contains(keyNormal)) _selectedKeys.add(keyNormal);
      if (!_ownedKeys.contains(keyFoil)) _selectedKeys.add(keyFoil);
    }
    setState(() {});
  }

  void _clearSelection() => setState(() => _selectedKeys.clear());

  // --- ACTIONS ---
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
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              onPressed: () async {
                await widget.wishlistService.createWishlist(setName);
                final updatedLists = await widget.wishlistService.loadWishlists();
                final newList = updatedLists.lastWhere((w) => w.name == setName, orElse: () => updatedLists.last);
                if (mounted) Navigator.pop(context, newList.id);
              },
              child: Row(children: [const Icon(Icons.add_circle, color: Colors.greenAccent), const SizedBox(width: 12), Expanded(child: Text("Nouvelle : $setName", style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))]),
            ),
            const Divider(color: Colors.white24),
            if (wishlists.isEmpty)
              const Padding(padding: EdgeInsets.all(16.0), child: Text("Aucune liste existante.", style: TextStyle(color: Colors.white54)))
            else
              ...wishlists.map((w) => SimpleDialogOption(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onPressed: () => Navigator.pop(context, w.id),
                child: Row(children: [const Icon(Icons.folder_open, color: Colors.blueAccent), const SizedBox(width: 12), Text(w.name, style: GoogleFonts.cinzel(color: Colors.white70))]),
              )),
          ],
        );
      },
    );
  }

  Future<void> _addSelectedTo(bool toCollection) async {
    if (_selectedKeys.isEmpty) return;
    String? targetWishlistId;
    if (!toCollection) {
      targetWishlistId = await _askWishlistDestination();
      if (targetWishlistId == null) return;
    }

    setState(() => _isLoading = true);
    int count = 0;

    // Traitement des clés sélectionnées
    for (String key in _selectedKeys) {
      final parts = key.split('|');
      final id = parts[0];
      final isFoil = parts[1] == 'foil';
      
      try {
        final card = _allCards.firstWhere((c) => c.id == id);
        
        if (toCollection) {
          // Ajout avec le bon flag Foil
          await widget.collectionService.addCard(card, 1, isFoil: isFoil);
        } else {
          await widget.wishlistService.upsertCard(
            wishlistId: targetWishlistId, 
            scryfallId: card.id, 
            cardName: card.name, 
            quantityToAdd: 1,
            isFoil: isFoil
          );
        }
        count++;
      } catch (e) {
        // Carte introuvable (rare)
      }
    }
    
    // Rafraichissement
    if (toCollection) {
      final col = await widget.collectionService.loadCollection();
      _ownedKeys.clear();
      for (var c in col) _ownedKeys.add(_makeKey(c.scryfallId, c.isFoil));
    } else {
      final w = await widget.wishlistService.loadWishlists();
      _wishlistKeys.clear();
      for (var l in w) {
        for (var c in l.cards) _wishlistKeys.add(_makeKey(c.scryfallId, c.isFoil));
      }
    }

    setState(() { _isLoading = false; _selectedKeys.clear(); });
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count cartes ajoutées !"), backgroundColor: Colors.green));
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
    // Calcul des totaux (uniques)
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
            Text("${widget.set.code.toUpperCase()} • ${_displayedCards.length} cartes", style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          if (!_isLoading) IconButton(icon: const Icon(Icons.pie_chart, color: Colors.blueAccent), tooltip: "Statistiques du Set", onPressed: _openStats),
          if (_selectedKeys.isNotEmpty)
             IconButton(icon: const Icon(Icons.deselect), tooltip: "Tout désélectionner", onPressed: _clearSelection)
          else if (!_isLoading)
            IconButton(icon: const Icon(Icons.select_all), tooltip: "Sélectionner les manquantes (Normales)", onPressed: _selectAllMissingFiltered),
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
                     // "Double" le nombre d'items pour afficher Normal ET Foil
                     itemCount: _displayedCards.length * 2,
                     itemBuilder: (context, index) {
                       final cardIndex = index ~/ 2;
                       final isFoilSlot = index % 2 == 1;
                       return _buildCardTile(_displayedCards[cardIndex], isFoilSlot);
                     },
                   ),
               ),
            ],
          ),
      bottomNavigationBar: _selectedKeys.isNotEmpty ? _buildBottomActionAmount() : null,
    );
  }

  // --- WIDGETS ---

  Widget _buildCardTile(ScryfallCard card, bool isFoilSlot) {
    final String key = _makeKey(card.id, isFoilSlot);
    final bool isOwned = _ownedKeys.contains(key);
    final bool isSelected = _selectedKeys.contains(key);
    final bool isWanted = _wishlistKeys.contains(key);

    // Vérifie si le prix foil existe pour griser le slot s'il n'existe pas
    // (Une carte sans version foil ne devrait pas être cliquable en mode foil)
    final bool foilAvailable = isFoilSlot ? (card.prices['eur_foil'] != null || card.prices['usd_foil'] != null) : true;

    if (isFoilSlot && !foilAvailable) {
      // Slot vide ou désactivé pour les cartes qui n'existent pas en foil
      // return Container(
      //   decoration: BoxDecoration(
      //     color: Colors.white.withOpacity(0.02),
      //     borderRadius: BorderRadius.circular(6),
      //     border: Border.all(color: Colors.white10)
      //   ),
      //   child: const Center(child: Icon(Icons.block, color: Colors.white10)),
      // );
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _toggleSelection(card.id, isFoilSlot),
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
                  // Effet visuel FOIL
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

          // Badge Foil / Normal
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

  // ... (Le reste des widgets : _buildBottomActionAmount, _buildQuickFilters, etc. reste inchangé)
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
            Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.style, color: Colors.yellow.shade800, size: 20), const SizedBox(width: 8), Flexible(child: Text("${_selectedKeys.length} carte(s)", style: GoogleFonts.cinzel(color: const Color(0xFFE0E0E0), fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis))])),
            const SizedBox(width: 8),
            Row(children: [
                ElevatedButton.icon(
                  onPressed: () => _addSelectedTo(false), 
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: const Color(0xFFBFDBFE), side: BorderSide(color: Colors.blue.shade300.withOpacity(0.3)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), elevation: 4),
                  icon: const Icon(Icons.star, size: 16),
                  label: Text("Wishlist", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _addSelectedTo(true), 
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF064E3B), foregroundColor: const Color(0xFFA7F3D0), side: BorderSide(color: Colors.green.shade300.withOpacity(0.3)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), elevation: 4),
                  icon: const Icon(Icons.inventory_2, size: 16),
                  label: Text("Collect.", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ])
          ],
        ),
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