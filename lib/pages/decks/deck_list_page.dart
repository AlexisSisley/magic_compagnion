// Fichier : lib/pages/decks/deck_list_page.dart

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/data/secondary_breakfast.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/pages/decks/deck_detail_page.dart';
import '../../models/deck_model.dart';
import '../../services/deck_service.dart';
import '../../services/local_card_service.dart';

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  final DeckService _deckService = DeckService();
  final LocalCardService _localCardService = LocalCardService();

  List<Deck> _decks = [];
  List<Deck> _filteredDecks = [];
  Map<String, double> _deckPrices = {};

  bool _isLoading = true;
  bool _isImporting = false;
  final TextEditingController _searchController = TextEditingController();
  
  // Filtres
  String _selectedFormat = 'Tous';
  String _selectedSort = 'name';
  
  // Filtre Identité Couleur (Nom affiché + Liste des couleurs)
  String? _selectedIdentityName; 
  List<String>? _selectedIdentityColors; 

  final Map<String, Map<String, List<String>>> _colorFamilies = {
    'Mono': {
      'Blanc': ['W'], 'Bleu': ['U'], 'Noir': ['B'], 'Rouge': ['R'], 'Vert': ['G'], 'Incolore': [] 
    },
    'Guilde (2)': {
      'Azorius': ['W', 'U'], 'Dimir': ['U', 'B'], 'Rakdos': ['B', 'R'], 'Gruul': ['R', 'G'], 'Selesnya': ['G', 'W'],
      'Orzhov': ['W', 'B'], 'Izzet': ['U', 'R'], 'Golgari': ['B', 'G'], 'Boros': ['R', 'W'], 'Simic': ['G', 'U']
    },
    'Trio (3)': {
      'Esper': ['W', 'U', 'B'], 'Grixis': ['U', 'B', 'R'], 'Jund': ['B', 'R', 'G'], 'Naya': ['R', 'G', 'W'], 'Bant': ['G', 'W', 'U'],
      'Abzan': ['W', 'B', 'G'], 'Jeskai': ['U', 'R', 'W'], 'Sultai': ['B', 'G', 'U'], 'Mardu': ['R', 'W', 'B'], 'Temur': ['G', 'U', 'R']
    },
    'Nephilim (4)': {
      'Yore-Tiller': ['W', 'U', 'B', 'R'], 'Glint-Eye': ['U', 'B', 'R', 'G'], 'Dune-Brood': ['B', 'R', 'G', 'W'],
      'Ink-Treader': ['R', 'G', 'W', 'U'], 'Witch-Maw': ['G', 'W', 'U', 'B']
    },
    'WUBRG (5)': {
      '5 Couleurs': ['W', 'U', 'B', 'R', 'G']
    }
  };

  final RegExp _decklistRegex = RegExp(r'^(\d+)x?\s+(.+)$');

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    setState(() { _isLoading = true; });
    await _localCardService.loadLocalData();
    final decks = await _deckService.loadDecks();
    
    // Calcul des prix
    for (var deck in decks) {
      double total = 0.0;
      for (var card in deck.mainboard) {
        final localCard = _localCardService.getCardById(card.scryfallId);
        if (localCard != null) {
          double price = double.tryParse(localCard.prices['eur'] ?? '0') ?? 0.0;
          total += price * card.quantity;
        }
      }
      _deckPrices[deck.id] = total;
    }

    if(mounted) {
      setState(() {
        _decks = decks;
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    var tempDecks = _decks.where((deck) {
      if (!deck.name.toLowerCase().contains(query)) return false;
      
      final bool isCommander = deck.commanderScryfallId != null;
      if (_selectedFormat == 'Commander' && !isCommander) return false;
      if (_selectedFormat == 'Standard' && isCommander) return false;
      
      if (_selectedIdentityColors != null) {
        if (_selectedIdentityColors!.isEmpty) {
          if (deck.colors.isNotEmpty) return false;
        } else {
          final deckSet = deck.colors.toSet();
          final filterSet = _selectedIdentityColors!.toSet();
          if (deckSet.length != filterSet.length || !deckSet.containsAll(filterSet)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    tempDecks.sort((a, b) {
      if (_selectedSort == 'price_desc') {
        return (_deckPrices[b.id] ?? 0).compareTo(_deckPrices[a.id] ?? 0);
      } else if (_selectedSort == 'price_asc') {
        return (_deckPrices[a.id] ?? 0).compareTo(_deckPrices[b.id] ?? 0);
      }
      return a.name.compareTo(b.name);
    });

    setState(() {
      _filteredDecks = tempDecks;
    });
  }

  // --- ACTIONS ---

  Future<void> _deleteDeck(String deckId) async {
    // Note: La confirmation est gérée par le Dismissible, 
    // cette méthode est appelée après confirmation visuelle
    await _deckService.deleteDeck(deckId);
    
    // --- EASTER EGG FORCE ---
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
              const SizedBox(width: 12),
              Text("La Force a effacé ce deck.", style: GoogleFonts.cinzel(color:Colors.cyanAccent,fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 2),
        )
      );
    }
    _loadDecks();
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
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nom du deck...', filled: true, fillColor: Colors.black45),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
            child: const Text('Créer'),
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
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Importer un Deck', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 16),
                TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom du nouveau deck', filled: true, fillColor: Colors.black54)),
                const SizedBox(height: 12),
                TextField(controller: listController, style: const TextStyle(color: Colors.white), maxLines: 8, decoration: const InputDecoration(hintText: 'Collez votre decklist ici...', filled: true, fillColor: Colors.black54)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final String deckName = nameController.text.trim();
                    final String deckList = listController.text.trim();
                    // --- EASTER EGG CHECK ---
                    if (deckName.toLowerCase() == 'second petit déjeuner') {
                      Navigator.pop(context); 
                      // Utilisation de la variable importée
                      _importDeck("Nourriture et communauté", secondBreakfastDecklist);
                    } else if (deckName.isNotEmpty && deckList.isNotEmpty) {
                      Navigator.pop(context); 
                      _importDeck(deckName, deckList);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
                  child: _isImporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Importer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importDeck(String deckName, String decklistText) async {
    setState(() { _isImporting = true; _isLoading = true; });

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
      final query = ids.take(75).map((n) => '!${json.encode(n)}').join(' OR ');
      try {
        final resp = await http.get(Uri.parse('https://api.scryfall.com/cards/search?q=${Uri.encodeComponent(query)}&unique=cards'));
        if (resp.statusCode == 200) {
           final data = json.decode(utf8.decode(resp.bodyBytes));
           scryfallData = (data['data'] as List).map((j) => ScryfallCard.fromJson(j)).toList();
        }
      } catch (e) { log("Erreur import: $e"); }
    }

    Set<String> deckColors = {};
    for (var sc in scryfallData) { deckColors.addAll(sc.colorIdentity); }
    final order = {'W':0, 'U':1, 'B':2, 'R':3, 'G':4, 'C':5};
    final sortedColors = deckColors.toList()..sort((a,b) => (order[a]??9).compareTo(order[b]??9));

    await _deckService.createNewDeck(deckName);
    final decks = await _deckService.loadDecks();
    Deck newDeck = decks.firstWhere((d) => d.name == deckName);
    newDeck.colors = sortedColors; 
    newDeck.format = commanderName != null ? 'Commander' : 'Standard';
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
    try { return data.firstWhere((s) => s.name.toLowerCase() == name.toLowerCase()).id; } catch (e) { return "LOCAL:$name"; }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    // CORRECTION : Nous n'utilisons plus de Scaffold interne ici pour laisser le contexte
    // remonter jusqu'au Scaffold de AppShell (dans main.dart) qui contient le Drawer.
    return Stack(
      children: [
        // Utilisation directe de NestedScrollView
        NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: Text('Mes Decks', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                centerTitle: false,
                pinned: true,
                floating: true,
                snap: true,
                expandedHeight: 120.0,
                backgroundColor: Colors.black,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  // Le context ici trouvera le Scaffold parent (AppShell)
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                    tooltip: "Importer une liste",
                    onPressed: _showImportDeckDialog
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF1A1A1A),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Rechercher un deck...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.white54),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : CustomScrollView(
                slivers: [
                  // Filtres
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildIdentityFilterChip(),
                            const SizedBox(width: 8),
                            _buildChoiceChip(
                              label: _selectedFormat, 
                              items: ['Tous', 'Commander', 'Standard'],
                              onSelected: (v) { setState(() { _selectedFormat = v; _applyFilters(); }); }
                            ),
                            const SizedBox(width: 8),
                            _buildChoiceChip(
                              label: _getSortLabel(_selectedSort),
                              items: ['Nom (A-Z)', 'Prix (Décroissant)', 'Prix (Croissant)'],
                              onSelected: (label) {
                                String code = 'name';
                                if(label.contains('Décroissant')) code = 'price_desc';
                                else if(label.contains('Croissant')) code = 'price_asc';
                                setState(() { _selectedSort = code; _applyFilters(); });
                              }
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Liste
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDeckCard(_filteredDecks[index]),
                        childCount: _filteredDecks.length,
                      ),
                    ),
                  ),
                ],
              ),
        ),
        
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _showCreateDeckDialog,
            backgroundColor: Colors.yellow.shade800,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('Nouveau Deck', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildIdentityFilterChip() {
    final bool isActive = _selectedIdentityName != null;
    return GestureDetector(
      onTap: _openIdentityFilterModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow.shade900 : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.yellow.shade700 : Colors.white12),
        ),
        child: Row(
          children: [
            if (_selectedIdentityColors != null && _selectedIdentityColors!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: _selectedIdentityColors!.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: _getManaIcon(c, size: 14),
                  )).toList(),
                ),
              ),
            Text(
              _selectedIdentityName ?? "Couleurs",
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: isActive ? Colors.white : Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({required String label, required List<String> items, required Function(String) onSelected}) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => items.map((i) => PopupMenuItem(value: i, child: Text(i))).toList(),
      color: const Color(0xFF2A2A2A),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  void _openIdentityFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Identité Couleur", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (_selectedIdentityName != null)
                        TextButton(
                          onPressed: () {
                            setState(() { _selectedIdentityName = null; _selectedIdentityColors = null; _applyFilters(); });
                            Navigator.pop(context);
                          },
                          child: const Text("Effacer", style: TextStyle(color: Colors.redAccent))
                        )
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: _colorFamilies.entries.map((familyEntry) {
                      return ExpansionTile(
                        title: Text(familyEntry.key, style: GoogleFonts.cinzel(color: Colors.yellow.shade800, fontWeight: FontWeight.bold)),
                        iconColor: Colors.yellow.shade800,
                        collapsedIconColor: Colors.white54,
                        initiallyExpanded: true,
                        children: familyEntry.value.entries.map((colorEntry) {
                          final name = colorEntry.key;
                          final colors = colorEntry.value;
                          final isSelected = _selectedIdentityName == name;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.yellow.shade900.withOpacity(0.2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                            title: Row(
                              children: [
                                ...colors.map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 4.0),
                                  child: _getManaIcon(c, size: 20),
                                )),
                                if(colors.isEmpty) _getManaIcon('C', size: 20),
                                const SizedBox(width: 12),
                                Text(name, style: TextStyle(color: isSelected ? Colors.yellow : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                            trailing: isSelected ? const Icon(Icons.check, color: Colors.yellow) : null,
                            onTap: () {
                              setState(() {
                                _selectedIdentityName = name;
                                _selectedIdentityColors = colors;
                                _applyFilters();
                              });
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildDeckCard(Deck deck) {
    final bool isCommander = deck.commanderScryfallId != null;
    final int cardCount = deck.mainboard.fold(0, (s, c) => s + c.quantity);
    final double totalPrice = _deckPrices[deck.id] ?? 0.0;

    return Dismissible(
      key: Key(deck.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text("USE THE FORCE",style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold,fontSize: 16, letterSpacing: 1.5)), 
          const SizedBox(width: 12), 
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.back_hand, color: Colors.white, size: 30), // La main
              Icon(Icons.flash_on, color: Colors.blueAccent.shade100, size: 40), // L'éclair de force
            ],
          ),
        ]),
      ),
      confirmDismiss: (d) => showDialog(
        context: context, 
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A), 
          title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)), 
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(c,false),child: const Text("Non")), 
            TextButton(onPressed: ()=>Navigator.pop(c,true),child: const Text("Oui"))
          ]
        )
      ),
      onDismissed: (_) {
        _deleteDeck(deck.id);
        setState(() { _decks.removeWhere((d) => d.id == deck.id); _applyFilters(); });
      },
      child: Card(
        // DESIGN AJUSTÉ ICI : Noir opaque pour faire ressortir la row
        color: Colors.black.withOpacity(0.8),
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        elevation: 4,
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
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          "https://api.scryfall.com/cards/${deck.commanderScryfallId}?format=image&version=art_crop",
                          width: 50, height: 50, fit: BoxFit.cover,
                          errorBuilder: (c,e,s) => Icon(Icons.shield_outlined, color: Colors.yellow.shade700, size: 28),
                        ),
                      )
                    else
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25)),
                        child: Icon(Icons.style, color: Colors.white54, size: 24),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        deck.name,
                        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
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
                    Text('$cardCount cartes', style: GoogleFonts.cinzel(color: Colors.amberAccent, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                        " ≈ ${totalPrice.toStringAsFixed(0)} €",
                        style: GoogleFonts.roboto(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      )
    );
  }
  
  Widget _getManaIcon(String symbol, {double size = 20}) {
    final url = 'https://svgs.scryfall.io/card-symbols/$symbol.svg';
    return SvgPicture.network(
      url, height: size, width: size,
      placeholderBuilder: (_) => Text(symbol, style: TextStyle(color: Colors.white, fontSize: size)),
    );
  }
  
  String _getSortLabel(String code) {
    switch(code) {
      case 'price_desc': return 'Prix (Décroissant)';
      case 'price_asc': return 'Prix (Croissant)';
      default: return 'Nom (A-Z)';
    }
  }
}