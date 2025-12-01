// Fichier : lib/pages/deck_list_page.dart

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/pages/decks/deck_detail_page.dart';
import '../../models/deck_model.dart';
import '../../services/deck_service.dart';

const String _secondBreakfastDecklist = """
Commander
1 Frodo, hobbit audacieux

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
  List<Deck> _filteredDecks = [];
  bool _isLoading = true;
  bool _isImporting = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'Tous'; // 'Tous', 'Commander', 'Standard'
  final Set<String> _selectedColors = {}; // {'W', 'U', ...}

  final Map<String, Color> _manaColors = {
    'W': Colors.yellow.shade100,
    'U': Colors.blue.shade300,
    'B': Colors.grey.shade800,
    'R': Colors.red.shade400,
    'G': Colors.green.shade400,
    'C': Colors.grey.shade400,
  };
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
    _applyFilters();
  }
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredDecks = _decks.where((deck) {
        // 1. Filtre Nom
        if (!deck.name.toLowerCase().contains(query)) return false;

        // 2. Filtre Type
        final bool isCommander = deck.commanderScryfallId != null;
        if (_selectedType == 'Commander' && !isCommander) return false;
        if (_selectedType == 'Standard' && isCommander) return false;

        // 3. Filtre Couleurs (Si activé, le deck doit contenir AU MOINS une des couleurs)
        // Vous pouvez changer la logique pour "DOIT CONTENIR TOUTES" selon préférence
        if (_selectedColors.isNotEmpty) {
          // Si le deck n'a pas de couleurs définies, on ne l'affiche pas si on filtre
          if (deck.colors.isEmpty) return false;
          
          // Vérifie l'intersection
          final bool hasColor = deck.colors.any((c) => _selectedColors.contains(c));
          if (!hasColor) return false;
        }

        return true;
      }).toList();
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

  Future<void> _showCreateDeckDialog() async {
    final controller = TextEditingController();
    final String? name = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Nouveau Deck', style: GoogleFonts.cinzel(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.cinzel(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nom du deck...',
            hintStyle: TextStyle(color: Colors.white54),
            filled: true, fillColor: Colors.black45,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
            child: Text('Créer'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _deckService.createNewDeck(name);
      _loadDecks();
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
              color: const Color(0xFF1A1A1A).withOpacity(0.95),
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
                    fillColor: Colors.black.withOpacity(0.5),
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
                    fillColor: Colors.black.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 8,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Text(
                    'L\'importation est limitée à 75 cartes uniques par appel (les decks plus grands feront plusieurs appels).', 
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade800,
                    foregroundColor: Colors.white,
                  ),
                  child: _isImporting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Importer', style: GoogleFonts.cinzel()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Logique d'importation ---
  Future<void> _importDeck(String deckName, String decklistText) async {
    setState(() { _isImporting = true; _isLoading = true; });

    // 1. Parser le texte
    List<Map<String, dynamic>> parsedMain = [];
    List<Map<String, dynamic>> parsedSide = [];
    String? commanderName;
    List<String> ids = [];
    String section = 'main';

    for (var line in decklistText.split('\n')) {
      line = line.trim();
      if (line.toLowerCase().startsWith('commander')) { section = 'cmd'; continue; }
      if (line.toLowerCase().startsWith('deck')) { section = 'main'; continue; }
      if (line.toLowerCase().startsWith('sideboard')) { section = 'side'; continue; }
      
      final match = _decklistRegex.firstMatch(line);
      if (match != null) {
        int qty = int.parse(match.group(1)!);
        String name = match.group(2)!.trim().split('//')[0].trim();
        if (!ids.contains(name)) ids.add(name);
        
        if (section == 'cmd') commanderName = name;
        else if (section == 'side') parsedSide.add({'name': name, 'quantity': qty});
        else parsedMain.add({'name': name, 'quantity': qty});
      }
    }
    
    List<ScryfallCard> scryfallData = [];
    if (ids.isNotEmpty) {
      // Chunking simplifié pour l'exemple
      final query = ids.take(75).map((n) => '!${json.encode(n)}').join(' OR ');
      try {
        final uri = Uri.parse('https://api.scryfall.com/cards/search?q=${Uri.encodeComponent(query)}&unique=cards');
        final resp = await http.get(uri);
        if (resp.statusCode == 200) {
           final data = json.decode(utf8.decode(resp.bodyBytes));
           scryfallData = (data['data'] as List).map((j) => ScryfallCard.fromJson(j)).toList();
        }
      } catch (e) { log("Erreur import: $e"); }
    }

    Set<String> deckColors = {};
    for (var sc in scryfallData) {
      // Si c'est un commander, on prend ses couleurs, sinon on additionne tout
      // Logique : Union de toutes les couleurs des cartes du mainboard
      // (Note: pour un deck Commander précis, c'est l'identité du général, 
      // mais "couleurs utilisées" est souvent l'union de tout).
      deckColors.addAll(sc.colorIdentity);
    }
    // Ordonner WUBRG
    final order = {'W':0, 'U':1, 'B':2, 'R':3, 'G':4, 'C':5};
    final sortedColors = deckColors.toList()..sort((a,b) => (order[a]??9).compareTo(order[b]??9));

    // 4. Création Deck
    await _deckService.createNewDeck(deckName);
    final decks = await _deckService.loadDecks();
    Deck newDeck = decks.firstWhere((d) => d.name == deckName);
    
    newDeck.colors = sortedColors; // Sauvegarde des couleurs !
    newDeck.format = commanderName != null ? 'Commander' : 'Standard';
    
    // Remplissage (Simplifié pour l'exemple, reprends ta logique complète de matching)
    newDeck.mainboard = parsedMain.map((p) => DeckCard(scryfallId: _findId(scryfallData, p['name']), name: p['name'], quantity: p['quantity'])).toList();
    newDeck.sideboard = parsedSide.map((p) => DeckCard(scryfallId: _findId(scryfallData, p['name']), name: p['name'], quantity: p['quantity'])).toList();
    
    if (commanderName != null) {
      String cid = _findId(scryfallData, commanderName);
      newDeck.commanderScryfallId = cid;
      if (!newDeck.mainboard.any((c) => c.name == commanderName)) {
        newDeck.mainboard.add(DeckCard(scryfallId: cid, name: commanderName, quantity: 1));
      }
    }

    await _deckService.updateDeck(newDeck);
    setState(() { _isImporting = false; _isLoading = false; });
    _loadDecks();
  }

  String _findId(List<ScryfallCard> data, String name) {
    try {
      return data.firstWhere((s) => s.name.toLowerCase() == name.toLowerCase()).id;
    } catch (e) { return "LOCAL:$name"; }
  }

  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold( // Ajout d'un Scaffold interne pour le FAB
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDeckDialog,
        backgroundColor: Colors.yellow.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Nouveau Deck', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // En-tête + Filtres
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.black.withOpacity(0.3),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mes Decks', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                      tooltip: 'Importer (Texte)',
                      onPressed: _showImportDeckDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Barre de recherche
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.cinzel(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    filled: true, fillColor: Colors.black54,
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                // Filtres (Format & Couleurs)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Dropdown Type
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: DropdownButton<String>(
                          value: _selectedType,
                          dropdownColor: const Color(0xFF1A1A1A),
                          underline: SizedBox(),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white70),
                          style: GoogleFonts.cinzel(color: Colors.white),
                          items: ['Tous', 'Commander', 'Standard'].map((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _selectedType = val; _applyFilters(); });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Toggles Couleurs
                      ..._manaColors.keys.map((color) {
                        final isSelected = _selectedColors.contains(color);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) _selectedColors.remove(color); else _selectedColors.add(color);
                                _applyFilters();
                              });
                            },
                            child: Opacity(
                              opacity: isSelected ? 1.0 : 0.3,
                              child: _getManaIcon(color, size: 28),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des decks
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredDecks.isEmpty
                  ? Center(child: Text('Aucun deck trouvé.', style: GoogleFonts.cinzel(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _filteredDecks.length,
                      padding: const EdgeInsets.only(bottom: 80), // Espace pour le FAB
                      itemBuilder: (context, index) {
                        return _buildDeckCard(_filteredDecks[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
  Widget _buildDeckCard(Deck deck) {
    final bool isCommander = deck.commanderScryfallId != null;
    final int cardCount = deck.mainboard.fold(0, (s, c) => s + c.quantity);

    return Card(
      color: Colors.black.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isCommander ? Colors.yellow.shade800.withOpacity(0.6) : Colors.white12,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => DeckDetailPage(deck: deck)));
          _loadDecks();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isCommander)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20), // Rond pour le style Commander
                          child: Image.network(
                            // URL Magique de Scryfall pour avoir l'image crop par ID
                            "https://api.scryfall.com/cards/${deck.commanderScryfallId}?format=image&version=art_crop",
                            width: 50, height: 50, fit: BoxFit.cover,
                            errorBuilder: (c,e,s) => Icon(Icons.shield_outlined, color: Colors.yellow.shade700, size: 28),
                          ),
                        )
                      else
                        Icon(Icons.style_outlined, color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  // Nom
                  Expanded(
                    child: Text(
                      deck.name,
                      style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Couleurs (Affichage des icônes)
                  if (deck.colors.isNotEmpty)
                    Row(
                      children: deck.colors.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _getManaIcon(c, size: 16),
                      )).toList(),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Badge Format
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCommander ? Colors.yellow.shade900.withOpacity(0.3) : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCommander ? 'COMMANDER' : 'STANDARD',
                      style: GoogleFonts.cinzel(
                        color: isCommander ? Colors.yellow.shade200 : Colors.white70,
                        fontSize: 10, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('$cardCount cartes', style: GoogleFonts.cinzel(color: Colors.white38, fontSize: 12)),
                  const SizedBox(width: 16),
                  // Bouton Supprimer
                  InkWell(
                    onTap: () => _deleteDeck(deck.id),
                    child: Icon(Icons.delete_outline, color: Colors.red.shade300.withOpacity(0.7), size: 20),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _getManaIcon(String symbol, {double size = 20}) {
    final url = 'https://svgs.scryfall.io/card-symbols/$symbol.svg';
    return SvgPicture.network(
      url, height: size, width: size,
      placeholderBuilder: (_) => Text(symbol, style: TextStyle(color: Colors.white, fontSize: size)),
    );
  }
}
  