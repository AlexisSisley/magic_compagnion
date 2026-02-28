// Fichier : lib/pages/wishlists/wishlist_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/models/wishlist_model.dart';
import 'package:magic_companion/services/wishlist_service.dart';
import 'package:magic_companion/widgets/collection/collection_list_tab.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/scryfall_api_service.dart';
import '../../providers/service_providers.dart';

class WishlistDetailPage extends ConsumerStatefulWidget {
  final Wishlist wishlist;
  const WishlistDetailPage({super.key, required this.wishlist});

  @override
  ConsumerState<WishlistDetailPage> createState() => _WishlistDetailPageState();
}

class _WishlistDetailPageState extends ConsumerState<WishlistDetailPage> {
  WishlistService get _wishlistService => ref.read(wishlistServiceProvider);
  ScryfallApiService get _apiService => ref.read(scryfallApiServiceProvider);

  late Wishlist _currentWishlist;
  List<ScryfallCard> _fullCardData = [];
  bool _isLoading = true;
  double _totalValue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentWishlist = widget.wishlist;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Charger les données Scryfall pour avoir les prix et images
    await _loadFullCardData();
    _calculateValue();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFullCardData() async {
    final uniqueIds = _currentWishlist.cards.map((c) => c.scryfallId).toSet().toList();
    if (uniqueIds.isEmpty) {
      _fullCardData = [];
      return;
    }

    List<ScryfallCard> loaded = [];
    const int chunkSize = 75;
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final end = (i + chunkSize < uniqueIds.length) ? i + chunkSize : uniqueIds.length;
      final batch = uniqueIds.sublist(i, end);
      try {
        final data = await _apiService.fetchCollection(
          batch.map((id) => {'id': id}).toList(),
        );
        loaded.addAll((data['data'] as List).map((j) => ScryfallCard.fromJson(j)));
      } catch (e) {
        // Erreur silencieuse
      }
    }
    _fullCardData = loaded;
  }

  void _calculateValue() {
    double total = 0.0;
    for (var c in _currentWishlist.cards) {
      try {
        final sc = _fullCardData.firstWhere((s) => s.id == c.scryfallId);
        
        // Si la carte est Foil, on cherche le prix foil, sinon normal
        // Si le prix foil n'existe pas, on fallback sur le normal
        String priceKey = c.isFoil ? 'eur_foil' : 'eur';
        final priceStr = sc.prices[priceKey] ?? sc.prices['eur'] ?? '0';
        
        final price = double.tryParse(priceStr) ?? 0.0;
        total += price * c.quantity;
      } catch (e) { /* */ }
    }
    setState(() => _totalValue = total);
  }

  // --- ACTIONS ---

  Future<void> _clearList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Vider la liste ?", style: GoogleFonts.cinzel(color: Colors.white)),
        content: const Text("Toutes les cartes seront supprimées de cette wishlist.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Vider", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      await _wishlistService.clearWishlistCards(_currentWishlist.id);
      setState(() {
        _currentWishlist.cards.clear();
        _totalValue = 0.0;
      });
    }
  }

  void _exportCardMarket() {
    final StringBuffer sb = StringBuffer();
    for (var c in _currentWishlist.cards) {
      String name = c.name; 
      try {
        final sc = _fullCardData.firstWhere((s) => s.id == c.scryfallId);
        name = "$name (${sc.setCode})"; 
      } catch(e) {}
      
      sb.writeln("${c.quantity} $name");
    }
    
    Share.share(sb.toString(), subject: "Export CardMarket - ${_currentWishlist.name}");
  }

  void _showCoverPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("Choisir une couverture", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8
                  ),
                  itemCount: _currentWishlist.cards.length,
                  itemBuilder: (context, index) {
                    final card = _currentWishlist.cards[index];
                    ScryfallCard? scryfallCard;
                    try {
                      scryfallCard = _fullCardData.firstWhere((s) => s.id == card.scryfallId);
                    } catch(e) {}

                    return GestureDetector(
                      onTap: () async {
                        await _wishlistService.setWishlistIcon(_currentWishlist.id, card.scryfallId);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image de couverture mise à jour !"), backgroundColor: Colors.green));
                        setState(() { _currentWishlist.iconScryfallId = card.scryfallId; });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: scryfallCard?.smallImageUrl != null
                          ? Image.network(scryfallCard!.smallImageUrl!, fit: BoxFit.cover)
                          : Container(color: Colors.grey[800], child: const Icon(Icons.image)),
                      ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () async {
                   await _wishlistService.setWishlistIcon(_currentWishlist.id, null);
                   Navigator.pop(context);
                   setState(() { _currentWishlist.iconScryfallId = null; });
                },
                child: const Text("Réinitialiser (Automatique)", style: TextStyle(color: Colors.redAccent)),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(_currentWishlist.name, style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'clear') _clearList();
              if (val == 'export') _exportCardMarket();
              if (val == 'cover') _showCoverPicker();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.upload_file, color: Colors.blue), SizedBox(width: 8), Text("Export CardMarket")])),
              const PopupMenuItem(value: 'cover', child: Row(children: [Icon(Icons.image, color: Colors.amber), SizedBox(width: 8), Text("Changer Couverture")])),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_sweep, color: Colors.red), SizedBox(width: 8), Text("Vider la liste")])),
            ],
          )
        ],
      ),
      // --- MODIFICATION ICI : CHARGEMENT ---
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Column(
            children: [
              _buildSpecificFinanceHeader(),
              Expanded(
                child: CollectionListTab(
                  cards: _currentWishlist.cards,
                  fullCardData: _fullCardData,
                  filterQuery: '',
                  activeFilters: SearchFilters(),
                  currentSort: 'Type',
                  isWishlist: true,
                  financialTotal: _totalValue,
                  hasCalculatedFinance: false,
                  onRefresh: _loadData,
                  onToggleFoil: (card) async {
                    // Inverse l'état
                    bool newFoilState = !card.isFoil;
                    
                    // Sauvegarde
                    await _wishlistService.upsertCard(
                      wishlistId: _currentWishlist.id,
                      scryfallId: card.scryfallId,
                      cardName: card.name,
                      // On ne change pas la quantité, juste le booléen
                      isFoil: newFoilState
                    );
                    
                    // Rafraichissement local
                    final updatedLists = await _wishlistService.loadWishlists();
                    final updatedList = updatedLists.firstWhere((w) => w.id == _currentWishlist.id);
                    setState(() => _currentWishlist = updatedList);
                    _calculateValue(); // Recalcule le prix total (Foil vs Normal)
                  },
                  onUpdateQuantity: (card, qty) async {
                    await _wishlistService.upsertCard(
                      wishlistId: _currentWishlist.id,
                      scryfallId: card.scryfallId,
                      cardName: card.name,
                      quantityToAdd: qty
                    );
                    final updatedLists = await _wishlistService.loadWishlists();
                    final updatedList = updatedLists.firstWhere((w) => w.id == _currentWishlist.id);
                    setState(() => _currentWishlist = updatedList);
                    _calculateValue();
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSpecificFinanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.black.withOpacity(0.5),
      child: Column(
        children: [
          Text("Coût estimé de cette liste", style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            "${_totalValue.toStringAsFixed(2)} €",
            style: GoogleFonts.cinzel(color: Colors.blue.shade200, fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}