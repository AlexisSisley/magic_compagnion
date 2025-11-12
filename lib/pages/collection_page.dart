// Fichier : lib/pages/collection_page.dart
// NOUVEAU FICHIER

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/pages/card_detail_page.dart';

import '../models/deck_model.dart'; // On réutilise DeckCard
import '../services/collection_service.dart'; // Notre nouveau service

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final CollectionService _collectionService = CollectionService();
  
  List<DeckCard> _collection = [];
  List<ScryfallCard> _fullCardData = [];
  bool _isLoading = true;

  // Regex pour le coût de mana
  final RegExp _manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');

  @override
  void initState() {
    super.initState();
    _loadData(); // Charge la collection et les données Scryfall
  }

  /// Charge la collection locale, PUIS les données Scryfall
  Future<void> _loadData() async {
    setState(() { _isLoading = true; });

    // 1. Charger la collection locale
    _collection = await _collectionService.loadCollection();
    if (!mounted) return;

    // 2. Charger les données Scryfall (similaire à deck_detail_page)
    await _loadFullCardData();
    if (!mounted) return;

    setState(() { _isLoading = false; });
  }

  /// Récupère les données Scryfall pour les cartes de la collection
  Future<void> _loadFullCardData() async {
    final uniqueCardIdentifiers = _collection
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:'))
        .map((card) => {"id": card.scryfallId})
        .toSet()
        .toList();

    if (uniqueCardIdentifiers.isEmpty) {
      log("CollectionPage: Aucune donnée Scryfall à charger.");
      _fullCardData = []; // Vide la liste si la collection est vide
      return;
    }

    final requestBody = json.encode({'identifiers': uniqueCardIdentifiers});

    try {
      final response = await http.post(
        Uri.parse('https://api.scryfall.com/cards/collection'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        _fullCardData = (data['data'] as List)
            .map((cardJson) => ScryfallCard.fromJson(cardJson))
            .toList();
      } else {
        throw Exception('Erreur API Scryfall: ${response.statusCode}');
      }
    } catch (e) {
      log('Erreur chargement données Scryfall (Collection): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur chargement données Scryfall: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  /// Met à jour la quantité via le service et recharge l'UI
  Future<void> _updateQuantity(DeckCard card, int change) async {
    // Appelle le service pour modifier la sauvegarde
    await _collectionService.upsertCardInCollection(
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: change,
    );
    
    // Recharge les données pour rafraîchir l'écran
    // (C'est la méthode la plus simple pour garantir la synchro)
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Titre de la page ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 4.0, 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ma Collection',
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Ici, on pourrait ajouter un filtre ou un bouton de tri plus tard
            ],
          ),
        ),

        // --- Contenu de la page ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _collection.isEmpty
                  ? _buildEmptyState()
                  : _buildGroupedCardListView(_collection), // Affiche la liste groupée
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Votre collection est vide.\nAjoutez des cartes depuis la Recherche ou le Scanner.',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // --- LOGIQUE DE GROUPEMENT (Identique à DeckDetailPage) ---

  List<_GroupedCardList> _buildGroupedList(List<DeckCard> cardList) {
    Map<String, List<DeckCard>> groupedMap = {
      'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 
      'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [],
    };

    for (final deckCard in cardList) {
      ScryfallCard? scryfallCard;
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) throw Exception("Carte locale");
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) {
        // Crée un objet factice pour les cartes non trouvées
        scryfallCard = ScryfallCard.fromJson({
            'id': deckCard.scryfallId, 'name': deckCard.name, 
            'legalities': {}, 'prices': {}, 'lang': 'fr', 
            'type_line': deckCard.name, 'color_identity': [], 'mana_cost': ''
        });
      }

      final type = _getPrimaryType(scryfallCard.typeLine);
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
    if (!lowerType.contains(' — ') && (lowerType.contains('swamp') || lowerType.contains('plains') || lowerType.contains('island') || lowerType.contains('mountain') || lowerType.contains('forest'))) {
      return 'Terrains';
    }
    if (lowerType.contains('creature')) return 'Créatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('land')) return 'Terrains';
    if (lowerType.contains('artifact')) return 'Artefacts';
    if (lowerType.contains('enchantment')) return 'Enchantements';
    if (lowerType.contains('instant')) return 'Sorts';
    if (lowerType.contains('sorcery')) return 'Sorts';
    if (typeLine.startsWith('LOCAL:')) return 'Autres';
    return 'Autres';
  }

  int _getCardCount(List<DeckCard> list) {
    return list.fold(0, (sum, card) => sum + card.quantity);
  }

  // --- WIDGETS D'AFFICHAGE (Identiques à DeckDetailPage) ---

  Widget _buildGroupedCardListView(List<DeckCard> cardList) {
    final groupedList = _buildGroupedList(cardList);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24.0, top: 8.0, left: 4.0, right: 4.0),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final group = groupedList[index];
        final int groupCardCount = _getCardCount(group.cards);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            
            Column(
              children: [
                ...group.cards.map((card) {
                  final scryfallCard = _fullCardData.firstWhere(
                    (sc) => sc.id == card.scryfallId,
                    orElse: () => ScryfallCard.fromJson({
                      'id': card.scryfallId, 'name': card.name, 'legalities': {}, 
                      'prices': {}, 'lang': 'fr', 'type_line': '', 'color_identity': [],
                      'mana_cost': ''
                    }),
                  );
                  return Card(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                    child: ListTile(
                      onTap: () {
                        // Navigation vers la page de détail
                        if (!scryfallCard.id.startsWith('LOCAL:')) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecognitionResultPage(cardName: scryfallCard.name),
                            ),
                          ).then((_) => _loadData()); // Recharge au retour
                        }
                      },
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                          ),
                          _buildManaCostRow(scryfallCard.manaCost),
                        ],
                      ),
                      leading: SizedBox(
                        width: 40,
                        child: Text(
                          '${card.quantity}x',
                          style: GoogleFonts.cinzel(
                            color: Colors.yellow.shade700,
                            fontSize: 18,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      trailing: SizedBox(
                        width: 100,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white70),
                              onPressed: () => _updateQuantity(card, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white70),
                              onPressed: () => _updateQuantity(card, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) {
      return const SizedBox.shrink(); 
    }
    final List<String> symbols = _manaPipRegex
        .allMatches(manaCost)
        .map((match) => match.group(0)!)
        .toList();

    return Container(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: symbols
            .map((symbol) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.0),
                  child: _getManaIcon(symbol),
                ))
            .toList(),
      ),
    );
  }

  Widget _getManaIcon(String symbol) {
    final String cleanSymbol =
        symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    final String svgUrl =
        'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg';

    return SvgPicture.network(
      svgUrl,
      height: 16,
      width: 16,
      placeholderBuilder: (context) => Text(
        symbol,
        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

// Classe helper pour le groupement
class _GroupedCardList {
  final String title;
  final List<DeckCard> cards;
  _GroupedCardList({required this.title, required this.cards});
}