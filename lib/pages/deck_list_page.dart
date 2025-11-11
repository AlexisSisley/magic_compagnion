// Fichier : lib/pages/deck_list_page.dart
// NOUVEAU FICHIER

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/pages/deck_detail_page.dart';
import '../models/deck_model.dart';
import '../services/deck_service.dart';

const String _secondBreakfastDecklist = """
Commander
1 Frodon, hobbit audacieux

Deck (102)
1 Chauves-souris de la Forêt Noire
1 Gollum, pisteur rongé par l'obsession
1 Invitée insatiable
1 Lobelia, défenseuse de Cul-de-sac
1 Approvisionneuse infatigable
1 Aubergiste prospère
1 Cochon de compétition
1 Enjambeur du verger
1 Ent généreux
1 Garde d'essence
1 Hobbit festoyant
1 Oie d'or
1 Oiseaux de paradis
1 Poney motivé
1 Primus chutebois
1 Vigile grand chêne
1 Aigles du nord
1 Gwaihir, le plus grand des aigles
1 L'Ancien
1 Landroval, témoin de l'horizon
1 Mentor des humbles
1 Rosie Chaumine de l'allée du Sud
1 Shirriff de la Comté
1 Bilbo, célébrant de l'anniversaire
1 Chasseuse éclairée
1 Convives du banquet
1 Fermier Chaumine
1 Merry, garde d'Isengard
1 Pippin, garde d'Isengard
1 Poiredebeurré, aubergiste de Bree
1 Sam, serviteur loyal
1 Sylvebarbe, hôte affable
1 Chuchotements nocturnes
1 Chuchotements nocturnes
1 Déluge toxique
1 Cherchauloin
1 Culture
1 Harmonisation
1 Ravivement de la Comté
1 Anéantir les puissants
1 Crépuscule // Aube
1 Fumigation
1 Bosquet bruissant
1 Bosquet de Solpétal
1 Bosquets épars
1 Broussaille
1 Chapelle isolée
1 Cimetière des sylves
1 Citadelle de la steppe de sable
1 Étendues sauvages en évolution
8 Forêt
1 Lacis luminombre
1 Lacis nécrofleur
1 Landes cendreuses
1 Landes érodées
4 Marais
1 Passage des malandrins
1 Passage des malandrins
4 Plaine
1 Quartier fantôme
1 Refuge de Grisepeau
1 Terrasse de la Comté
1 Tour de commandement
1 Tunnel d'accès
1 Verger exotique
1 Village fortifié
1 Voie de l'Ascendance
1 Vue de la canopée
1 Anneau solaire
1 Cachet d'ésotérisme
1 Comptoir de commerce
1 Corde de hithlain
1 Lanterne chromatique
1 Puits des songes perdus
1 Sphère du commandant
1 Sphère du commandant
1 Talisman immaculé
1 Poêle à frire de terrain
1 Droit à la gorge
1 Incursion dans la crypte
1 Chemin vers l'exil
1 Retour au pays
1 Annulation angoissée
1 Mortification
1 Lien sanguin
1 Réunir le Conseil des Ents
1 Appel à l'unité
1 Aube de l'espoir
1 Herbes et ragoût de lapin
""";

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  final DeckService _deckService = DeckService();
  List<Deck> _decks = [];
  bool _isLoading = true;
  bool _isImporting = false;

  final RegExp _decklistRegex = RegExp(r'^(\d+)x?\s+(.+)$');

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  // Charger les decks depuis le service
  Future<void> _loadDecks() async {
    setState(() { _isLoading = true; });
    final decks = await _deckService.loadDecks();
    // Trie les decks par nom pour la cohérence
    decks.sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _decks = decks;
      _isLoading = false;
    });
  }

  // Supprimer un deck (avec confirmation)
  Future<void> _deleteDeck(String deckId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le deck ?', style: GoogleFonts.cinzel()),
        content: Text('Cette action est irréversible.', style: GoogleFonts.cinzel()),
        backgroundColor: const Color(0xFF1A1A1A),
        titleTextStyle: GoogleFonts.cinzel(color: Colors.white, fontSize: 20),
        contentTextStyle: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.cinzel(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: GoogleFonts.cinzel(color: Colors.red.shade300)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deckService.deleteDeck(deckId);
      _loadDecks(); // Rafraîchir la liste
    }
  }
  Future<void> _showImportDeckDialog() async {
    final nameController = TextEditingController();
    final listController = TextEditingController();
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withAlpha(240),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Importer un Deck', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: GoogleFonts.cinzel(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nom du nouveau deck',
                    labelStyle: GoogleFonts.cinzel(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withAlpha(120),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: listController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Collez votre decklist ici...\n4 Foudre\n2 Jace, le sculpteur de l\'esprit\n...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black.withAlpha(120),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 8,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Text(
                    'L\'importation est limitée à 75 cartes uniques par appel (les decks plus grands feront plusieurs appels).', // Texte mis à jour
                    style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String deckName = nameController.text.trim();
                    final String deckList = listController.text.trim();

                    // --- Logique de l'Easter Egg ---
                    if (deckName.toLowerCase() == 'second petit déjeuner' || deckName.toLowerCase() == 'second breakfast') {
                      Navigator.pop(context);
                      _importDeck("Nourriture et communauté", _secondBreakfastDecklist);
                    }
                    // --- Fin de l'Easter Egg ---
                    
                    else if (deckName.isNotEmpty && deckList.isNotEmpty) {
                      Navigator.pop(context);
                      _importDeck(deckName, deckList); // Importation normale
                    }
                  },
                  child: _isImporting 
                      ? const CircularProgressIndicator()
                      : Text('Importer', style: GoogleFonts.cinzel()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- NOUVELLE FONCTION : Logique d'importation ---
  Future<void> _importDeck(String deckName, String decklistText) async {
    setState(() { _isImporting = true; _isLoading = true; });

    // 1. Parser le texte (logique inchangée)
    List<Map<String, dynamic>> parsedMainboard = [];
    List<Map<String, dynamic>> parsedSideboard = [];
    String? parsedCommanderName;
    List<Map<String, String>> scryfallIdentifiers = [];
    String currentSection = 'mainboard';
    final lines = decklistText.split('\n');

    for (final line in lines) {
      final String trimmedLine = line.trim();
      if (trimmedLine.toLowerCase().startsWith('commander')) {
        currentSection = 'commander';
        continue;
      } else if (trimmedLine.toLowerCase().startsWith('deck')) {
        currentSection = 'mainboard';
        continue;
      } else if (trimmedLine.toLowerCase().startsWith('sideboard')) {
        currentSection = 'sideboard';
        continue;
      }
      final match = _decklistRegex.firstMatch(trimmedLine);
      if (match != null) {
        final int quantity = int.tryParse(match.group(1)!) ?? 0;
        final String cardName = match.group(2)!.trim();
        if (quantity > 0 && cardName.isNotEmpty) {
          if (!scryfallIdentifiers.any((id) => id['name'] == cardName)) {
             scryfallIdentifiers.add({'name': cardName});
          }
          if (currentSection == 'commander') {
            parsedCommanderName = cardName;
          } else if (currentSection == 'sideboard') {
            parsedSideboard.add({'name': cardName, 'quantity': quantity});
          } else {
            parsedMainboard.add({'name': cardName, 'quantity': quantity});
          }
        }
      }
    }
    
    if (scryfallIdentifiers.isEmpty) {
      log('Importation échouée: Aucune carte valide trouvée.');
      setState(() { _isImporting = false; _isLoading = false; });
      return;
    }

    // 2. Appel API (on garde la logique de "chunking")
    log('Début de l\'importation de ${scryfallIdentifiers.length} cartes uniques...');
    List<ScryfallCard> scryfallCardData = [];
    List<Map<String, String>> remainingIdentifiers = List.from(scryfallIdentifiers);
    const int chunkSize = 75;
    int callCount = 1;

    while (remainingIdentifiers.isNotEmpty) {
      final List<Map<String, String>> chunk = remainingIdentifiers.take(chunkSize).toList();
      remainingIdentifiers.removeRange(0, chunk.length);
      log('Appel API n°$callCount: ${chunk.length} cartes...');
      callCount++;
      try {
        final requestBody = json.encode({'identifiers': chunk});
        final response = await http.post(
          Uri.parse('https://api.scryfall.com/cards/collection'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          scryfallCardData.addAll((data['data'] as List)
              .map((cardJson) => ScryfallCard.fromJson(cardJson)));
        } else {
          throw Exception('Erreur API: ${response.statusCode}');
        }
        if (remainingIdentifiers.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
        log('Erreur d\'importation Scryfall: $e');
        setState(() { _isImporting = false; _isLoading = false; });
        return;
      }
    }

    // 3. Créer le nouveau deck (inchangé)
    await _deckService.createNewDeck(deckName);
    final decks = await _deckService.loadDecks();
    Deck newDeck = decks.firstWhere((d) => d.name == deckName);

    // 4. Remplir le deck (LOGIQUE DE MATCHING CORRIGÉE)
    List<DeckCard> mainboardCards = [];
    for (final parsedCard in parsedMainboard) {
      try {
        final parsedNameLower = parsedCard['name'].toLowerCase();
        final scryfallCard = scryfallCardData.firstWhere(
          (sc) => sc.name.toLowerCase() == parsedNameLower ||
                 (sc.printedName != null && sc.printedName!.toLowerCase() == parsedNameLower)
        );
        mainboardCards.add(DeckCard(
          scryfallId: scryfallCard.id,
          name: scryfallCard.name,
          quantity: parsedCard['quantity'],
        ));
      } catch (e) { log('Carte non trouvée (main) : ${parsedCard['name']}'); }
    }
    newDeck.mainboard = mainboardCards;
    
    List<DeckCard> sideboardCards = [];
    for (final parsedCard in parsedSideboard) {
      try {
        final parsedNameLower = parsedCard['name'].toLowerCase();
        final scryfallCard = scryfallCardData.firstWhere(
          (sc) => sc.name.toLowerCase() == parsedNameLower ||
                 (sc.printedName != null && sc.printedName!.toLowerCase() == parsedNameLower)
        );
        sideboardCards.add(DeckCard(
          scryfallId: scryfallCard.id,
          name: scryfallCard.name,
          quantity: parsedCard['quantity'],
        ));
      } catch (e) { log('Carte non trouvée (side) : ${parsedCard['name']}'); }
    }
    newDeck.sideboard = sideboardCards;

    if (parsedCommanderName != null) {
      try {
        final parsedNameLower = parsedCommanderName.toLowerCase();
        final scryfallCard = scryfallCardData.firstWhere(
          (sc) => sc.name.toLowerCase() == parsedNameLower ||
                 (sc.printedName != null && sc.printedName!.toLowerCase() == parsedNameLower)
        );
        newDeck.commanderScryfallId = scryfallCard.id;
        if (!newDeck.mainboard.any((c) => c.scryfallId == scryfallCard.id)) {
           newDeck.mainboard.add(DeckCard(
             scryfallId: scryfallCard.id,
             name: scryfallCard.name,
             quantity: 1
           ));
        }
      } catch (e) { log('Commandant non trouvé: $parsedCommanderName'); }
    }
    
    await _deckService.updateDeck(newDeck);
    log('Deck "${newDeck.name}" importé avec succès !');
    setState(() { _isImporting = false; _isLoading = false; });
    _loadDecks();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 4.0, 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mes Decks',
                style: GoogleFonts.cinzel(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // --- NOUVEAU BOUTON D'IMPORT ---
              IconButton(
                icon: const Icon(Icons.file_upload_outlined),
                tooltip: 'Importer un deck',
                color: Colors.black87,
                onPressed: _showImportDeckDialog,
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _decks.isEmpty
              ? _buildEmptyState()
              : _buildDeckList(),
        ),
      ],
    );
  }

  Widget _buildDeckList() {
    return ListView.builder(
      itemCount: _decks.length,
      itemBuilder: (context, index) {
        final deck = _decks[index];
        final int cardCount = deck.mainboard
            .fold(0, (sum, card) => sum + card.quantity);

        return Card(
          color: Colors.black.withAlpha((0.4 * 255).round()),
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: Colors.yellow.shade800.withAlpha((0.6 * 255).round()),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Icon(
              Icons.style_outlined,
              color: Colors.white.withAlpha((0.7 * 255).round()),
            ),
            title: Text(
              deck.name,
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '$cardCount cartes',
              style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade300.withAlpha(200)),
              onPressed: () => _deleteDeck(deck.id),
            ),
            onTap: () async {
              // Naviguer vers la page de détail
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeckDetailPage(deck: deck),
                ),
              );
              // Au retour de la page de détail, rafraîchir la liste
              _loadDecks();
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Aucun deck trouvé.\nAjoutez des cartes depuis la page de Recherche pour commencer.',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}