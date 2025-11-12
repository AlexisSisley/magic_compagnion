// Fichier : lib/pages/deck_detail_page.dart
// VERSION MISE À JOUR (Filtre LOCAL + Navigation onTap)

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/pages/card_detail_page.dart'; // <-- AJOUTÉ POUR LA NAVIGATION
import 'package:magic_companion/widgets/decks/draw_test_simulator.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../models/deck_model.dart';
import '../services/deck_service.dart';

// ... (const kBasicLands est inchangée) ...
const Map<String, Map<String, String>> kBasicLands = {
  'W': {'id': 'f5f80d82-d64c-466f-8874-9cfb00469f02', 'name': 'Plains'},
  'U': {'id': '560384fe-7be0-4b93-a515-2fe687ab2492', 'name': 'Island'},
  'B': {'id': 'e713819e-74f3-421c-a3db-e9e000e0e0e7', 'name': 'Swamp'},
  'R': {'id': '354110de-1e3d-4a94-a550-4d87dae7cd6a', 'name': 'Mountain'},
  'G': {'id': '1850d588-436e-4886-bd76-1f3a2f3a55d4', 'name': 'Forest'},
};


class DeckDetailPage extends StatefulWidget {
  final Deck deck;
  
  const DeckDetailPage({super.key, required this.deck});

  @override
  State<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends State<DeckDetailPage> with TickerProviderStateMixin {
  
  late Deck _currentDeck;
  final DeckService _deckService = DeckService();
  late TabController _tabController;
  
  bool _isValidating = false;
  bool _isLoading = true;
  List<ScryfallCard> _fullCardData = [];

  final RegExp _manaPipRegex = RegExp(r'\{([WUBRG])\}');
  
  @override
  void initState() {
    super.initState();
    _currentDeck = widget.deck;
    _tabController = TabController(length: 2, vsync: this);
    _loadFullCardData();
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- FONCTION : Charge les données Scryfall ---
  Future<void> _loadFullCardData() async {
    setState(() { _isLoading = true; });

    final allCards = [..._currentDeck.mainboard, ..._currentDeck.sideboard];
    
    // --- MODIFICATION ---
    // On filtre les cartes "LOCAL:" pour ne pas les envoyer à Scryfall
    final uniqueCardIdentifiers = allCards
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:')) 
        .map((card) => {"id": card.scryfallId}) 
        .toSet()
        .toList();
    // --- FIN MODIFICATION ---

    if (uniqueCardIdentifiers.isEmpty) {
      log("Aucun ID Scryfall à charger.");
      setState(() { _isLoading = false; });
      return;
    }

    final requestBody = json.encode({'identifiers': uniqueCardIdentifiers});
    log('--- NOUVELLE REQUÊTE SCRYFALL ---');
    log(requestBody);

    try {
      final response = await http.post(
        Uri.parse('https://api.scryfall.com/cards/collection'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _fullCardData = (data['data'] as List)
              .map((cardJson) => ScryfallCard.fromJson(cardJson))
              .toList();
          _isLoading = false;
        });
      } else {
        log('Réponse d\'erreur de Scryfall (Code: ${response.statusCode}): ${response.body}');
        throw Exception('Erreur API Scryfall: ${response.statusCode}');
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      log('Erreur chargement données Scryfall: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur chargement données Scryfall: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _updateQuantity(DeckCard card, int change) async {
    // Appelle le service
    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: _currentDeck.id,
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: change,
    );
    
    // --- CORRECTION : Met à jour l'état local ---
    setState(() {
      _currentDeck = updatedDeck;
    });
  }

  Future<void> _setCommander(DeckCard deckCard) async {
    // --- MODIFICATION : Gère les cartes locales ---
    if (deckCard.scryfallId.startsWith('LOCAL:')) {
       if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Données Scryfall non trouvées. Impossible de définir comme Cdt.',
            style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }
    // --- Fin Modification ---

    final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);

    if (!scryfallCard.typeLine.toLowerCase().contains('legendary') ||
        !scryfallCard.typeLine.toLowerCase().contains('creature')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Un commandant doit être une créature légendaire.',
            style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    // Appelle le service
    final updatedDeck = await _deckService.setCommander(_currentDeck.id, scryfallCard.id);
    
    // --- CORRECTION : Met à jour l'état local ---
    setState(() {
      _currentDeck = updatedDeck;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${scryfallCard.name}" est maintenant votre commandant.',
          style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.yellow.shade700,
    ));
  }
  
  Future<void> _checkLegality() async {
    setState(() { _isValidating = true; });

    if (_fullCardData.isEmpty && _getCardCount(_currentDeck.mainboard) > 0) {
      // S'il n'y a QUE des cartes locales, on ne peut pas valider
      final bool hasOnlyLocalCards = _currentDeck.mainboard
            .every((card) => card.scryfallId.startsWith('LOCAL:'));
            
      if(hasOnlyLocalCards) {
         setState(() { _isValidating = false; });
        _showValidationResults({'Erreur': 'Aucune donnée Scryfall trouvée pour ce deck.'});
        return;
      }
    }

    final validationResults = _validateDeckRules(_fullCardData);
    setState(() { _isValidating = false; });
    _showValidationResults(validationResults);
  }

  // Moteur de validation
  Map<String, String> _validateDeckRules(List<ScryfallCard> cardData) {
    Map<String, String> results = {};
    const List<String> formats = ['standard', 'pioneer', 'modern', 'commander'];

    // --- Helpers pour la validation
    ScryfallCard? getCard(String scryfallId) {
      // --- MODIFICATION : Ignore les cartes locales ---
      if (scryfallId.startsWith('LOCAL:')) return null; 
      try {
        return cardData.firstWhere((sc) => sc.id == scryfallId);
      } catch (e) {
        return null; // Carte non trouvée
      }
    }
    
    // Carte "vide" pour la sécurité
    final ScryfallCard emptyCard = ScryfallCard.fromJson({
        'id': '', 'name': '', 'legalities': {}, 'prices': {}, 'lang': 'fr', 'type_line': '', 'color_identity': []
    });

    // --- Règle 1: Taille du deck ---
    int mainboardCount = _getCardCount(_currentDeck.mainboard);
    int sideboardCount = _getCardCount(_currentDeck.sideboard);

    results['Deck (formats 60 cartes)'] = (mainboardCount < 60)
        ? '❌ Illégal (Mainboard < 60 cartes)'
        : '✅ Légal (Taille Mainboard OK)';
    
    results['Sideboard (formats 60 cartes)'] = (sideboardCount > 15)
        ? '❌ Illégal (Sideboard > 15 cartes)'
        : '✅ Légal (Taille Sideboard OK)';

    // --- Règle 2: Légalité par format ---
    for (final format in formats) {
      String status = '✅ Légal';
      
      // --- VALIDATION COMMANDER ---
      if (format == 'commander') {
        // 2a. Taille du deck
        if (mainboardCount != 100) {
          results[format] = '❌ Illégal (100 cartes requises)';
          continue; // Passe au format suivant
        }
        
        // 2b. Existence du Commandant
        if (_currentDeck.commanderScryfallId == null || _currentDeck.commanderScryfallId!.startsWith('LOCAL:')) {
          results[format] = '❌ Illégal (Cdt non valide ou non trouvé)';
          continue;
        }
        
        final commanderCard = getCard(_currentDeck.commanderScryfallId!) ?? emptyCard;
        if (!commanderCard.typeLine.toLowerCase().contains('legendary') ||
            !commanderCard.typeLine.toLowerCase().contains('creature')) {
           results[format] = '❌ Illégal (Cmdt non légendaire)';
           continue;
        }
        
        // 2c. Identité de couleur
        final Set<String> commanderColors = commanderCard.colorIdentity.toSet();
        bool colorsOk = true;
        String illegalCardName = '';

        for (final deckCard in _currentDeck.mainboard) {
          final scryfallCard = getCard(deckCard.scryfallId); // Peut être null
          if (scryfallCard == null) continue; // Ignore les cartes locales

          final Set<String> cardColors = scryfallCard.colorIdentity.toSet();

          // Vérifie si chaque couleur de la carte est DANS l'identité du cmdt
          if (!cardColors.every((color) => commanderColors.contains(color))) {
            colorsOk = false;
            illegalCardName = scryfallCard.name;
            break;
          }
        }

        if (!colorsOk) {
          results[format] = '❌ Illégal (Couleur: "$illegalCardName")';
          continue;
        }
        
        // Si tout va bien pour le Commander
        status = '✅ Légal (Couleurs OK)';
      }
      
      // --- VALIDATION AUTRES FORMATS ---
      for (final deckCard in _currentDeck.mainboard) {
        final scryfallCard = getCard(deckCard.scryfallId); // Peut être null
        if (scryfallCard == null) {
          // Si une carte locale est dans un deck non-commander, on ne peut pas valider
           if (format != 'commander') {
             status = '❔ Inconnu (Contient "${deckCard.name}")';
           }
           continue; // Ignore les cartes locales
        }
        
        final legality = scryfallCard.legalities[format];

        if (legality == 'not_legal' || legality == 'banned') {
          status = '❌ Illégal (contient "${scryfallCard.name}")';
          break;
        }
        
        // Règle des 4 exemplaires (sauf en Commander)
        if (format != 'commander') {
           if (!scryfallCard.typeLine.toLowerCase().contains('basic land')) {
            if (deckCard.quantity > 4) {
              status = '❌ Illégal (> 4x "${scryfallCard.name}")';
              break;
            }
          }
        }
      }
      
      results[format] = status;
    }
    return results;
  }

  Map<String, int> _calculatePipCount() {
    Map<String, int> pipCount = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0};
    log('--- DÉBUT DU CALCUL DES PIPS ---');
    
    for (final deckCard in _currentDeck.mainboard) {
      
      // --- CORRECTION : Gère le cas où la carte n'est pas dans _fullCardData ---
      ScryfallCard? scryfallCard;
      try {
        // Tente de trouver la carte
        if (deckCard.scryfallId.startsWith('LOCAL:')) continue; // Ignore cartes locales
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) {
        // Si 'firstWhere' échoue (Bad state), on logue et on ignore
        log('Alerte: Carte "${deckCard.name}" (ID: ${deckCard.scryfallId}) n\'a pas de données Scryfall. Elle est ignorée.');
        continue; // Passe à la carte suivante
      }

      if (scryfallCard.typeLine.toLowerCase().contains('land')) {
        continue;
      }

      final manaCost = scryfallCard.manaCost ?? '';
      log('Analyse de: "${scryfallCard.name}", Coût: "$manaCost" (x${deckCard.quantity})'); 

      final matches = _manaPipRegex.allMatches(manaCost);
      for (final match in matches) {
        final pip = match.group(1);
        if (pip != null) {
          pipCount[pip] = (pipCount[pip] ?? 0) + (1 * deckCard.quantity);
        }
      }
    }
    
    log('--- RÉSULTAT PIP COUNT: ${pipCount.toString()}'); 
    return pipCount;
  }

  // 2. Ouvre la modale de confirmation
  Future<void> _showAutoFillLandsModal() async {
    // Cela garantit que _fullCardData est synchronisé avec _currentDeck
    setState(() { _isLoading = true; });
    await _loadFullCardData();
    setState(() { _isLoading = false; });

    final pipCount = _calculatePipCount();
    final totalPips = pipCount.values.fold(0, (a, b) => a + b);
    final currentCount = _getCardCount(_currentDeck.mainboard);
    
    // Crée une description textuelle de la répartition
    String recommendationText = "Aucun pip de couleur trouvé.";
    if (totalPips > 0) {
      recommendationText = pipCount.entries
          .where((entry) => entry.value > 0) // Garde que les couleurs présentes
          .map((entry) => "${entry.key}: ${((entry.value / totalPips) * 100).toStringAsFixed(0)}%")
          .join(', ');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Ajout auto. des terrains', style: GoogleFonts.cinzel(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deck actuel : $currentCount cartes.',
              style: GoogleFonts.cinzel(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Text(
              'Ratio de pips : $recommendationText',
              style: GoogleFonts.cinzel(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Remplir le deck jusqu\'à :',
              style: GoogleFonts.cinzel(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.cinzel(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addLandsToDeck(60, pipCount, totalPips); // Cible 60 cartes
            },
            child: Text('60 Cartes', style: GoogleFonts.cinzel()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addLandsToDeck(100, pipCount, totalPips); // Cible 100 cartes
            },
            child: Text('100 Cartes', style: GoogleFonts.cinzel()),
          ),
        ],
      ),
    );
  }

  // 3. Effectue l'ajout
  Future<void> _addLandsToDeck(int targetCount, Map<String, int> pipCount, int totalPips) async {
    setState(() { _isLoading = true; });
    log('--- AJOUT DE TERRAINS ---');
    log('Total Pips Reçu: $totalPips');

    Deck deckCopy = _currentDeck; // Commence avec la copie locale

    // Supprime d'abord tous les terrains de base actuels
    for (final land in kBasicLands.values) {
      deckCopy = await _deckService.upsertCardInDeck(
        deckId: deckCopy.id,
        scryfallId: land['id']!,
        cardName: land['name']!,
        absoluteQuantity: 0, // Force la suppression
      );
    }
    
    // --- CORRECTION : Met à jour l'état local ---
    setState(() { _currentDeck = deckCopy; });

    // Calcule les terrains nécessaires
    // --- MODIFICATION : Exclut les cartes locales du comptage non-terrain ---
    final int currentNonLandCount = _currentDeck.mainboard
        .where((card) => !card.scryfallId.startsWith('LOCAL:')) // Exclut les cartes locales
        .fold(0, (sum, card) => sum + card.quantity);

    final int landsNeeded = targetCount - currentNonLandCount;
    
    if (landsNeeded <= 0) {
      log('Aucun terrain nécessaire.');
      await _loadFullCardData(); // Rafraîchit juste les données Scryfall
      return;
    }
    
    if (totalPips == 0) {
      log('Aucun pip de couleur, ajout de terrains impossible.');
      await _loadFullCardData();
      return;
    }

    // Calcule le nombre de chaque terrain
    Map<String, int> landsToAdd = {};
    int landsAddedSoFar = 0;
    
    for (final pip in pipCount.keys) {
      int count = ((pipCount[pip]! / totalPips) * landsNeeded).round();
      landsToAdd[pip] = count;
      landsAddedSoFar += count;
    }

    // Ajuste l'arrondi
    int diff = landsNeeded - landsAddedSoFar;
    if (diff != 0) {
      String mostRepresentedPip = pipCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      landsToAdd[mostRepresentedPip] = (landsToAdd[mostRepresentedPip] ?? 0) + diff;
    }

    // Ajoute les terrains au deck
    for (final entry in landsToAdd.entries) {
      final String pip = entry.key;
      final int count = entry.value;
      if (count > 0) {
        deckCopy = await _deckService.upsertCardInDeck(
          deckId: deckCopy.id,
          scryfallId: kBasicLands[pip]!['id']!,
          cardName: kBasicLands[pip]!['name']!,
          absoluteQuantity: count, // Définit la quantité exacte
        );
      }
    }
    
    // --- CORRECTION : Met à jour l'état final ---
    setState(() { _currentDeck = deckCopy; });
    
    // Recharge toutes les données (y compris les nouveaux terrains)
    await _loadFullCardData();
  }

  // Fonction de test de pioche (inchangée)
  Future<void> _showDrawTestModal() async {
    final List<DeckCard> mainboardList = [];
    for (final card in _currentDeck.mainboard) {
      for (int i = 0; i < card.quantity; i++) {
        mainboardList.add(card);
      }
    }

    if (mainboardList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Le mainboard est vide.',
            style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return DrawTestSimulator(mainboard: mainboardList);
      },
    );
  }

  Widget _getManaIcon(String symbol) {
    final String cleanSymbol =
        symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    final String svgUrl =
        'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg';

    return SvgPicture.network(
      svgUrl,
      height: 16, // Hauteur standard pour les pips en ligne
      width: 16,
      placeholderBuilder: (context) => Text(
        symbol,
        style: GoogleFonts.cinzel(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) {
      // Retourne un conteneur vide pour ne pas prendre de place
      return const SizedBox.shrink(); 
    }
    final List<String> symbols = _manaPipRegex
        .allMatches(manaCost)
        .map((match) => match.group(0)!)
        .toList();

    return Container(
      padding: const EdgeInsets.only(top: 4.0), // Espace entre le nom et le coût
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Aligner à gauche
        children: symbols
            .map((symbol) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.0), // Léger écart
                  child: _getManaIcon(symbol),
                ))
            .toList(),
      ),
    );
  }
  Future<void> _showClearDeckDialog() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Vider le deck ?', style: GoogleFonts.cinzel(color: Colors.white)),
        content: Text(
          'Toutes les cartes du mainboard et du sideboard seront supprimées. Cette action est irréversible.',
          style: GoogleFonts.cinzel(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.cinzel(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Vider', style: GoogleFonts.cinzel(color: Colors.red.shade300)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final clearedDeck = await _deckService.clearDeck(_currentDeck.id);
      setState(() {
        _currentDeck = clearedDeck; // Met à jour l'UI avec le deck vide
      });
      // Recharge les données (qui seront vides)
      await _loadFullCardData();
    }
  }

  // --- NOUVELLE FONCTION : Partager le deck ---
  void _shareDeck() {
    // 1. Crée la liste de texte
    final StringBuffer decklistText = StringBuffer();
    
    decklistText.writeln('--- Deck: ${_currentDeck.name} ---');
    
    // 2. Ajoute le commandant
    if (_currentDeck.commanderScryfallId != null) {
      try {
        final commanderCard = _fullCardData.firstWhere((c) => c.id == _currentDeck.commanderScryfallId);
        decklistText.writeln('\nCommander');
        decklistText.writeln('1 ${commanderCard.name}');
      } catch (e) { 
        // Fallback pour Cdt local
        if (_currentDeck.commanderScryfallId!.startsWith('LOCAL:')) {
           final cmdName = _currentDeck.commanderScryfallId!.replaceFirst('LOCAL:', '');
           decklistText.writeln('\nCommander');
           decklistText.writeln('1 $cmdName');
        }
      }
    }

    // 3. Ajoute le Mainboard
    decklistText.writeln('\nDeck (${_getCardCount(_currentDeck.mainboard)})');
    final groupedMain = _buildGroupedList(_currentDeck.mainboard);
    for (final group in groupedMain) {
      for (final card in group.cards) {
        decklistText.writeln('${card.quantity} ${card.name}');
      }
    }
    
    // 4. Ajoute le Sideboard
    final groupedSide = _buildGroupedList(_currentDeck.sideboard);
    if (groupedSide.isNotEmpty) {
      decklistText.writeln('\nSideboard (${_getCardCount(_currentDeck.sideboard)})');
      for (final group in groupedSide) {
        for (final card in group.cards) {
          decklistText.writeln('${card.quantity} ${card.name}');
        }
      }
    }
    
    // 5. Ouvre la feuille de partage
    Share.share(decklistText.toString());
  }
  
  // --- INTERFACE UTILISATEUR (MISE À JOUR) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(
          _currentDeck.name,
          style: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(),
          tabs: [
            Tab(text: 'Mainboard (${_getCardCount(_currentDeck.mainboard)})'),
            Tab(text: 'Sideboard (${_getCardCount(_currentDeck.sideboard)})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager le deck',
            onPressed: _isLoading ? null : _shareDeck,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Remplissage auto. terrains',
            onPressed: _isLoading ? null : _showAutoFillLandsModal,
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Test de pioche',
            onPressed: _isLoading ? null : _showDrawTestModal,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Vider le deck',
            onPressed: _isLoading ? null : _showClearDeckDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGroupedCardListView(_currentDeck.mainboard),
                _buildGroupedCardListView(_currentDeck.sideboard),
              ],
            ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isValidating ? null : _checkLegality,
        backgroundColor: Colors.yellow.shade800,
        foregroundColor: Colors.white,
        icon: _isValidating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check_circle_outline),
        label: Text(
          _isValidating ? 'Vérification...' : 'Vérifier Légalité',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  
  // --- FONCTION : Regroupement (la logique) ---
  List<_GroupedCardList> _buildGroupedList(List<DeckCard> cardList) {
    Map<String, List<DeckCard>> groupedMap = {
      'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 
      'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [],
    };

    for (final deckCard in cardList) {
      ScryfallCard? scryfallCard;
      try {
        // --- MODIFICATION ---
        // Ne cherche que si ce n'est pas une carte locale
        if (deckCard.scryfallId.startsWith('LOCAL:')) {
          throw Exception("Carte locale"); // Saute au catch
        }
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) {
        // --- CORRECTION (Inchangée, elle gère déjà notre cas) ---
        log('Données locales pour "${deckCard.name}"');
        scryfallCard = ScryfallCard.fromJson({
            'id': deckCard.scryfallId, // Garde l'ID "LOCAL:..."
            'name': deckCard.name, 
            'legalities': {}, 
            'prices': {}, 
            'lang': 'fr', 
            'type_line': deckCard.name, // Utilise le nom comme type (ex: "Swamp")
            'color_identity': [],
            'mana_cost': ''
        });
        // ---
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

  // --- FONCTION : Classifie une carte ---
  String _getPrimaryType(String typeLine) {
    String lowerType = typeLine.toLowerCase();
    
    // Si le type est juste le nom (pour les cartes locales), on devine
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
    
    // Fallback pour les cartes locales qu'on ne peut pas deviner
    if (typeLine.startsWith('LOCAL:')) return 'Autres';
    
    return 'Autres';
  }

  // --- WIDGET : La liste groupée (l'UI) ---
  Widget _buildGroupedCardListView(List<DeckCard> cardList) {
    if (cardList.isEmpty) {
      return Center(
        child: Text(
          'Aucune carte ici.',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
        ),
      );
    }
    final groupedList = _buildGroupedList(cardList);
    if (groupedList.isEmpty && cardList.isNotEmpty) {
      return Center(
        child: Text(
          'Chargement des données de type...',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90.0, top: 8.0, left: 4.0, right: 4.0),
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
            
            // --- Liste des cartes du groupe ---
            Column(
              children: [
                ...group.cards.map((card) {
                  // --- LOGIQUE : Vérifie si c'est le commandant ---
                  final bool isCommander = _currentDeck.commanderScryfallId == card.scryfallId;
                  
                  // --- MODIFICATION : Gère le fallback ici ---
                  final scryfallCard = _fullCardData.firstWhere(
                    (sc) => sc.id == card.scryfallId,
                    // Fallback (gère les cartes 'LOCAL:')
                    orElse: () => ScryfallCard.fromJson({
                      'id': card.scryfallId, 'name': card.name, 'legalities': {}, 
                      'prices': {}, 'lang': 'fr', 'type_line': '', 'color_identity': [],
                      'mana_cost': '' // Important d'avoir un mana_cost vide
                    }),
                  );
                  return Card(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                    child: ListTile(
                      // --- AJOUT : onTap pour la navigation ---
                      onTap: () {
                        // On ne peut naviguer que si on a un vrai ID Scryfall
                        if (!scryfallCard.id.startsWith('LOCAL:')) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              // RecognitionResultPage est notre "Card Detail Page"
                              builder: (context) => RecognitionResultPage(cardName: scryfallCard.name),
                            ),
                          );
                        } else {
                          // Optionnel : SnackBar pour informer l'utilisateur
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Données Scryfall non trouvées pour "${scryfallCard.name}"',
                                style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.yellow.shade700,
                          ));
                        }
                      },
                      // --- Fin de l'ajout ---
                      
                      onLongPress: () {
                        // On ne peut définir un commandant que depuis le mainboard
                        if (cardList == _currentDeck.mainboard) {
                          _setCommander(card);
                        }
                      },
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                          ),
                          // Ajoute la rangée de pips de mana
                          _buildManaCostRow(scryfallCard.manaCost),
                        ],
                      ),
                      leading: SizedBox(
                        width: 50, // Espace pour "99x ⭐️"
                        child: Row(
                          children: [
                            Text(
                              '${card.quantity}x',
                              style: GoogleFonts.cinzel(
                                color: Colors.yellow.shade700,
                                fontSize: 18,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            // --- NOUVEL AJOUT : Icône Commandant ---
                            if (isCommander)
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.star, color: Colors.yellow, size: 16),
                              ),
                          ],
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

  
  // Fonction d'affichage des résultats (inchangée)
  Future<void> _showValidationResults(Map<String, String> results) async {
    // ... (Inchangée)
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Résultats de Légalité',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white24, height: 32),
              ...results.entries.map((entry) {
                final bool isLegal = entry.value.startsWith('✅');
                final bool isUnknown = entry.value.startsWith('❔');
                return ListTile(
                  title: Text(
                    entry.key[0].toUpperCase() + entry.key.substring(1),
                    style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                  ),
                  trailing: Flexible( // <-- 1. Enveloppez avec Flexible
                    child: Text(
                      entry.value,
                      style: GoogleFonts.cinzel(
                        color: isLegal ? Colors.green.shade300 : (isUnknown ? Colors.grey : Colors.red.shade300),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right, // <-- 2. (Optionnel) Pour un meilleur alignement
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Helper pour compter les cartes (inchangé)
  int _getCardCount(List<DeckCard> list) {
    return list.fold(0, (sum, card) => sum + card.quantity);
  }
}

// --- NOUVEAU MODÈLE : Pour la liste groupée ---
class _GroupedCardList {
  final String title;
  final List<DeckCard> cards;

  _GroupedCardList({required this.title, required this.cards});
}