// Fichier : lib/pages/card_search_page.dart
// VERSION MISE À JOUR (avec bouton Collection ET Wishlist)

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/widgets/search/search_filter_modal.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'card_detail_page.dart';
import '../services/collection_service.dart'; // Service Collection
import '../services/wishlist_service.dart'; // <-- 1. AJOUT DE L'IMPORT

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({super.key});

  @override
  State<CardSearchPage> createState() => _CardSearchPageState();
}

class _CardSearchPageState extends State<CardSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  SearchFilters _activeFilters = SearchFilters();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String _statusMessage = 'Entrez un nom de carte pour commencer.';

  final CollectionService _collectionService = CollectionService();
  final WishlistService _wishlistService = WishlistService();
  List<DeckCard> _collection = [];
  List<DeckCard> _wishlist = [];
  
  @override
  void initState() {
    super.initState();
    // Charge l'état actuel de la collection et wishlist
    _loadLocalData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _loadLocalData() async {
    final collection = await _collectionService.loadCollection();
    final wishlist = await _wishlistService.loadWishlist();
    if (mounted) {
      setState(() {
        _collection = collection;
        _wishlist = wishlist;
      });
    }
  }
  
  Future<void> _searchCards() async {
    final String query = _searchController.text.trim();
    List<String> queryParts = [];
    if (query.isNotEmpty) { queryParts.add(query); }
    if (_activeFilters.setCode != null) { queryParts.add('e:${_activeFilters.setCode}'); }
    if (_activeFilters.colors.isNotEmpty) { queryParts.add('c:${_activeFilters.colors.join()}'); }
    if (_activeFilters.cardType != null) { queryParts.add('t:${_activeFilters.cardType}'); }
    if (queryParts.isEmpty) {
      setState(() { _statusMessage = "Veuillez entrer au moins un critère de recherche."; });
      return;
    }
    final String finalQuery = queryParts.join(' ');
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) { 
      setState(() { _isLoading = false; _searchResults = []; _statusMessage = "Erreur : Pas de connexion internet."; });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final String lang = prefs.getString('glossaryLang') ?? 'fr';
    setState(() { _isLoading = true; _searchResults = []; _statusMessage = 'Recherche de "$finalQuery"...'; });
    try {
      final encodedQuery = Uri.encodeComponent(finalQuery);
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/search?q=$encodedQuery&lang=$lang'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _isLoading = false;
          _searchResults = data['data'] ?? [];
          if (_searchResults.isEmpty) { _statusMessage = 'Aucune carte trouvée pour "$finalQuery".'; }
        });
      } else {
        setState(() { _isLoading = false; _statusMessage = 'Erreur: ${response.statusCode}. Veuillez réessayer.'; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _statusMessage = 'Erreur réseau: $e'; });
    }
  }
  Future<void> _openFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) { return SearchFilterModal(initialFilters: _activeFilters); },
    );
    if (newFilters != null) { setState(() { _activeFilters = newFilters; }); }
  }
  // --- (Fin des fonctions inchangées) ---
  
  @override
  Widget build(BuildContext context) {
    // ... (Build du TextField inchangé) ...
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Nom de la carte...',
              hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 16),
              prefixIcon: IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: _activeFilters.colors.isNotEmpty || _activeFilters.cardType != null || _activeFilters.setCode != null
                      ? Colors.yellow.shade700 : Colors.white70,
                ),
                onPressed: _openFilterModal,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.white70),
                onPressed: _searchCards,
              ),
              filled: true,
              fillColor: Colors.black.withAlpha(140),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onSubmitted: (value) => _searchCards(),
          ),
        ),
        Expanded(
          child: _buildResultsList(),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final card = _searchResults[index];
        final String cardName = card['name'] ?? 'Nom inconnu';
        final String cardType = card['type_line'] ?? '';
        final String scryfallId = card['id'] ?? '';

        String? imageUrl;
        if (card['image_uris'] != null) {
          imageUrl = card['image_uris']['small'];
        } else if (card['card_faces'] != null) {
          imageUrl = card['card_faces'][0]['image_uris']['small'];
        }

        final bool inWishlist = _wishlist.any((c) => c.scryfallId == scryfallId);
        final bool inCollection = _collection.any((c) => c.scryfallId == scryfallId);
        
        return Card(
          color: Colors.black.withAlpha(102),
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(color: Colors.yellow.shade800.withAlpha(153), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: imageUrl != null
                  ? Image.network(imageUrl, width: 50, height: 70, fit: BoxFit.cover)
                  : Container(width: 50, height: 70, color: Colors.grey.shade800, child: const Icon(Icons.image, color: Colors.white30)),
            ),
            title: Text(cardName, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text(cardType, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14)),
            
            trailing: SizedBox(
              width: 100, // Augmenté pour éviter l'overflow
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Bouton Wishlist (Toggle)
                  IconButton(
                    icon: Icon(
                      inWishlist ? Icons.star : Icons.star_border_outlined, // Icône dynamique
                      color: inWishlist ? Colors.blue.shade400 : Colors.white54,
                    ),
                    tooltip: inWishlist ? 'Retirer de la Wishlist' : 'Ajouter à la Wishlist',
                    onPressed: () {
                      if (scryfallId.isEmpty) return;
                      if (inWishlist) {
                        _wishlistService.upsertCardInWishlist(scryfallId: scryfallId, cardName: cardName, absoluteQuantity: 0);
                        _showFeedback(context, '"$cardName" retiré de la Wishlist', Colors.red.shade700);
                      } else {
                        _wishlistService.upsertCardInWishlist(scryfallId: scryfallId, cardName: cardName, quantityToAdd: 1);
                        _showFeedback(context, '"$cardName" ajouté à la Wishlist', Colors.blue.shade700);
                      }
                      _loadLocalData(); // Rafraîchit l'état des icônes
                    },
                  ),
                  // Bouton Collection (Toggle)
                  IconButton(
                    icon: Icon(
                      inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, // Icône dynamique
                      color: inCollection ? Colors.green.shade400 : Colors.white54,
                    ),
                    tooltip: inCollection ? 'Retirer de la collection' : 'Ajouter à la collection',
                    onPressed: () {
                      if (scryfallId.isEmpty) return;
                      if (inCollection) {
                        _collectionService.upsertCardInCollection(scryfallId: scryfallId, cardName: cardName, absoluteQuantity: 0);
                         _showFeedback(context, '"$cardName" retiré de la collection', Colors.red.shade700);
                      } else {
                        _collectionService.upsertCardInCollection(scryfallId: scryfallId, cardName: cardName, quantityToAdd: 1);
                        _showFeedback(context, '"$cardName" ajouté à la collection', Colors.green.shade700);
                      }
                      _loadLocalData(); // Rafraîchit l'état des icônes
                    },
                  ),
                ],
              ),
            ),
            
            splashColor: Colors.yellow.withAlpha(26),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: cardName)),
              );
            },
          ),
        );
      },
    );
  }

  // Helper pour afficher les notifications
  void _showFeedback(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Cache l'ancienne
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      duration: const Duration(seconds: 1),
    ));
  }
}