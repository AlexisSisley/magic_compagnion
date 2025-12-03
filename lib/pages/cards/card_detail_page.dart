// Fichier : lib/pages/cards/card_detail_page.dart
// VERSION CORRIGÉE : Support Multi-Wishlists avec Sélecteur

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:magic_companion/pages/glossary/glossary_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// IMPORTS LOCAUX
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/widgets/decks/deck_picker_modal.dart';
import '../../services/deck_service.dart';
import '../../data/glossary_data.dart';
import '../../services/collection_service.dart';
import '../../services/scan_history_service.dart';
import '../../models/scan_history_model.dart';
import '../../services/wishlist_service.dart';
import '../../services/local_card_service.dart';

import '../../models/scryfall_ruling.dart'; 
import '../../widgets/cards/versions_selector_sheet.dart';

enum ResultPageState { loading, selection, success, error }

class RecognitionResultPage extends StatefulWidget {
  final String? imagePath;
  final String? cardName;

  const RecognitionResultPage({super.key, this.imagePath, this.cardName});

  @override
  State<RecognitionResultPage> createState() => _RecognitionResultPageState();
}

class _RecognitionResultPageState extends State<RecognitionResultPage> {
  final TextEditingController _searchController = TextEditingController();
  ResultPageState _pageState = ResultPageState.loading;
  String _statusMessage = "Démarrage...";
  
  List<ScryfallCard> _candidates = [];
  ScryfallCard? _foundCard;
  
  String _userLang = 'fr';
  List<Keyword> _activeGlossary = [];
  List<ScryfallRuling> _rulings = [];
  bool _isLoadingRulings = false;

  final RegExp _manaSymbolRegex = RegExp(r'(\{.*?\})');
  final DeckService _deckService = DeckService();
  final CollectionService _collectionService = CollectionService();
  final ScanHistoryService _historyService = ScanHistoryService();
  final WishlistService _wishlistService = WishlistService();
  final LocalCardService _localCardService = LocalCardService();
  
  bool _inWishlist = false;
  bool _inCollection = false;
  // ignore: unused_field
  String _currentDisplayLang = 'fr';

  @override
  void initState() {
    super.initState();
    _initializeAndSearch();
  }

  Future<void> _initializeAndSearch() async {
    await _localCardService.loadLocalData();
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentDisplayLang = prefs.getString('glossaryLang') ?? 'fr';
      final String assetPath = (_userLang == 'fr') ? 'assets/glossary_fr.json' : 'assets/glossary_en.json';
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List;
      _activeGlossary = jsonList.map((jsonItem) => Keyword.fromJson(jsonItem as Map<String, dynamic>)).toList();
    } catch (e) {
      _activeGlossary = [];
    }
    
    if (widget.imagePath != null) {
      _startAutomaticProcess();
    } else if (widget.cardName != null) {
      _searchController.text = widget.cardName!;
      _searchForCandidates(widget.cardName!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _cleanOcrText(String text) {
    String cleanedText = text.toUpperCase();
    // cleanedText = cleanedText.replaceAll('0', 'O'); 
    // cleanedText = cleanedText.replaceAll(RegExp(r'\b(W|U|B|R|G|O|X|Y|Z)\b', caseSensitive: false), '');
    // cleanedText = cleanedText.replaceAll(RegExp(r'[{}<>()\[\].,:;]'), '');
    cleanedText = cleanedText.replaceAll(RegExp(r'[\[\].,:;]'), ' ');
    cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleanedText;
  }

  Future<void> _startAutomaticProcess() async {
    setState(() { _pageState = ResultPageState.loading; _statusMessage = "Lecture de la carte..."; });
    if (widget.imagePath == null) return;
    
    final inputImage = InputImage.fromFilePath(widget.imagePath!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      // final RegExp collectorRegex = RegExp(r'([A-Z0-9]{3,4})[\s•\/\-]{1,3}([0-9]{1,4})');
      // Cherche : 3-5 Lettres/Chiffres + Séparateur + 1-4 Chiffres (et optionnellement une lettre)
      final RegExp collectorRegex = RegExp(r'\b([A-Z0-9]{3,5})[\s•\/\-]{1,3}([0-9]{1,4}[a-z]?)\b');
      
      // On cherche d'abord le pattern "SET CODE + NUMBER" (souvent en bas à gauche)
      for (var block in recognizedText.blocks) {
        // On nettoie un peu le bloc pour aider la regex
        String blockText = block.text.replaceAll('\n', ' ');
        final match = collectorRegex.firstMatch(blockText);
        
        if (match != null) {
          final String setCode = match.group(1)!;
          final String collectorNumber = match.group(2)!;
          
          setState(() { _statusMessage = "Code détecté : $setCode #$collectorNumber"; });
          
          bool success = await _fetchExactCard(setCode, collectorNumber);
          if (success) return; 
        }
      }

      // Si la regex échoue, on cherche le titre (bestGuess)
      List<TextBlock> sortedBlocks = List.from(recognizedText.blocks);
      sortedBlocks.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      String? bestGuess;
      const List<String> badKeywords = ['créature', 'creature', 'artefact', 'artifact', 'enchantment', 'instant', 'sorcery', 'land', 'token', 'legendary'];

      for (int i = 0; i < sortedBlocks.length && i < 5; i++) { // On regarde un peu plus bas (5 blocs)
        for (var line in sortedBlocks[i].lines) {
          String text = _cleanOcrText(line.text); // Utilise notre fonction simple
          if (text.length < 3) continue; 
          bool isTypeLine = badKeywords.any((k) => text.toLowerCase().contains(k));
          if (isTypeLine) continue;
          
          // Heuristique simple : si c'est tout en majuscule, c'est probablement pas le titre (souvent le cas pour les types)
          // Mais attention aux cartes anciennes. On garde le premier candidat valide.
          bestGuess = text;
          break; 
        }
        if (bestGuess != null) break;
      }

      if (bestGuess == null || bestGuess.isEmpty) {
        setState(() { _pageState = ResultPageState.error; _statusMessage = "Titre non reconnu."; });
        return;
      }

      _searchController.text = bestGuess;
      await _searchForCandidates(bestGuess);

    } catch (e) {
      setState(() { _pageState = ResultPageState.error; _statusMessage = "Erreur OCR: $e"; });
    }
  }

  Future<bool> _fetchExactCard(String set, String cn) async {
    setState(() { _statusMessage = "Identification précise ($set #$cn)..."; });
    try {
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/$set/$cn'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _selectCard(ScryfallCard.fromJson(data));
        return true;
      }
    } catch (e) { }
    return false;
  }

  Future<void> _searchForCandidates(String query) async {
    setState(() {
      _pageState = ResultPageState.loading;
      _statusMessage = "Recherche de correspondances...";
      _candidates = [];
    });

    bool foundApi = false;

    // 1. API Scryfall
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      try {
        final encoded = Uri.encodeComponent(query);
        final response = await http.get(Uri.parse('https://api.scryfall.com/cards/search?q=$encoded&unique=cards'));
        
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final List<dynamic> rawList = data['data'] ?? [];
          
          final List<ScryfallCard> apiResults = rawList
              .map((json) => ScryfallCard.fromJson(json))
              .take(10)
              .toList();

          if (apiResults.isNotEmpty) {
            if (apiResults.length == 1) {
               _selectCard(apiResults.first);
               return;
            }
            
            setState(() {
              _candidates = apiResults;
              _pageState = ResultPageState.selection; 
            });
            foundApi = true;
          }
        } 
      } catch (e) { print("Erreur API Search: $e"); }
    }

    // 2. Fallback Local
    if (!foundApi && _localCardService.isLoaded) {
      setState(() { _statusMessage = "Recherche locale..."; });
      
      var localResults = _localCardService.findSmartMatch(query, limit: 10);
      
      if (localResults.isEmpty) {
        final searchResult = await _localCardService.searchCards(query: query);
        localResults = searchResult.take(10).toList();
      }

      if (localResults.isNotEmpty) {
        if (localResults.length == 1) {
           _selectCard(localResults.first);
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Résultat unique local")));
           return;
        }

        setState(() {
          _candidates = localResults;
          _pageState = ResultPageState.selection; 
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Résultats locaux (Mode Hors-ligne)")));
        return;
      }
    }

    if (_candidates.isEmpty) {
      setState(() {
        _statusMessage = "Aucune carte trouvée pour \"$query\".";
        _pageState = ResultPageState.error;
      });
    }
  }

  void _selectCard(ScryfallCard card) {
    setState(() { 
      _foundCard = card; 
      _pageState = ResultPageState.success; 
    });
    
    if (widget.imagePath != null) {
      final newItem = ScanHistoryItem(scryfallId: card.id, cardName: card.name, imagePath: widget.imagePath, timestamp: DateTime.now());
      _historyService.addScan(newItem);
    }
    _fetchRulings(card.id);
    _checkCardStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(_pageState == ResultPageState.selection ? "Choisissez la carte" : "Détail Carte", style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        actions: [
          if (_pageState == ResultPageState.success) ...[
            IconButton(icon: const Icon(Icons.style, color: Colors.white), onPressed: _showVersionsModal),
            IconButton(icon: Icon(_inWishlist ? Icons.star : Icons.star_border_outlined, color: _inWishlist ? Colors.blue.shade400 : Colors.white), onPressed: _toggleWishlist),
            IconButton(icon: Icon(_inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, color: _inCollection ? Colors.green.shade400 : Colors.white), onPressed: _toggleCollection)
          ]
        ],
      ),
      body: _buildContent(),
      floatingActionButton: _pageState == ResultPageState.success
          ? FloatingActionButton(onPressed: _showDeckPicker, backgroundColor: Colors.yellow.shade800, child: const Icon(Icons.add_to_photos_outlined))
          : null,
    );
  }

  Widget _buildContent() {
    final mediaQuery = MediaQuery.of(context);
    
    switch (_pageState) {
      case ResultPageState.loading:
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.white))]));
      
      case ResultPageState.selection:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Plusieurs correspondances trouvées.\nVeuillez sélectionner la bonne carte :", 
                style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: _candidates.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final card = _candidates[index];
                  final imgUrl = card.smallImageUrl ?? card.imageUrl;
                  
                  return Card(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: ListTile(
                      leading: imgUrl.isNotEmpty 
                          ? Image.network(imgUrl, width: 40, fit: BoxFit.cover) 
                          : const Icon(Icons.image, color: Colors.white24),
                      title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text("${card.typeLine}\n${card.setName} • ${card.collectorNumber}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.yellow),
                      onTap: () => _selectCard(card),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton.icon(
                icon: const Icon(Icons.search, color: Colors.white54),
                label: const Text("Ce n'est pas dans la liste ? Chercher manuellement", style: TextStyle(color: Colors.white54)),
                onPressed: () {
                  setState(() => _pageState = ResultPageState.error);
                },
              ),
            )
          ],
        );

      case ResultPageState.success:
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0 + mediaQuery.padding.bottom + 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.black.withValues(alpha: 0.4),
                elevation: 4.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.yellow.shade800.withValues(alpha: 0.6), width: 1)),
                child: Column(children: [
                    Image.network(_foundCard!.imageUrl, fit: BoxFit.fitWidth, errorBuilder: (c, e, s) => const SizedBox(height: 300, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white)))),
                    Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
                          _buildManaCostRow(_foundCard!.manaCost),
                          const SizedBox(height: 8),
                          Text(_foundCard!.printedName ?? _foundCard!.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          Text(_foundCard!.typeLine, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                    ]))
                ]),
              ),
              _buildInfoCard(title: 'Texte des règles', child: _buildClickableRulesText(_foundCard!.rulesText, _foundCard!.lang)),
              _buildInfoCard(title: 'Prix & Marché', child: _buildPriceInfo(_foundCard!.prices)),
              _buildInfoCard(title: 'Légalité', child: _buildLegalities(_foundCard!.legalities)),
              _buildInfoCard(title: 'Décisions de Règles', child: _buildRulingsList()),
            ],
          ),
        );

      case ResultPageState.error:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.red.shade300), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                style: GoogleFonts.cinzel(color: Colors.white),
                decoration: InputDecoration(hintText: 'Nom de la carte', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                onSubmitted: (val) => _searchForCandidates(val),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _searchForCandidates(_searchController.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800), child: Text('Rechercher', style: GoogleFonts.cinzel())),
            ],
          ),
        );
    }
  }

  Widget _buildPriceInfo(Map<String, dynamic> prices) {
    final String priceEur = prices['eur'] ?? 'N/A';
    final String priceEurFoil = prices['eur_foil'] ?? 'N/A';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [Text('Normal', style: GoogleFonts.cinzel(color: Colors.white70)), Text('$priceEur €', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]),
        Container(width: 1, height: 30, color: Colors.white24),
        Column(children: [Text('Foil (Brillant)', style: GoogleFonts.cinzel(color: Colors.amber.shade200)), Text('$priceEurFoil €', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]),
      ],
    );
  }
  
  Widget _buildRulingsList() {
    if (_isLoadingRulings) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_rulings.isEmpty) return Text('(Aucune décision)', style: GoogleFonts.cinzel(color: Colors.white70, fontStyle: FontStyle.italic));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _rulings.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.date, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)), Text(r.comment, style: const TextStyle(color: Colors.white))]))).toList());
  }
  
  Widget _buildInfoCard({required String title, required Widget child}) {
    return Card(
      color: Colors.black.withValues(alpha: 0.4), elevation: 2, margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.yellow.shade800.withValues(alpha: 0.6))),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)), const Divider(color: Colors.white24), const SizedBox(height: 8), child])),
    );
  }
  
  Widget _buildLegalities(Map<String, String> legalities) {
    const formats = ['standard', 'commander', 'modern', 'pioneer'];
    return Wrap(spacing: 12, runSpacing: 8, children: formats.map((fmt) {
       final status = legalities[fmt] ?? 'not_legal';
       Color c = status == 'legal' ? Colors.green : (status == 'banned' ? Colors.red : Colors.grey);
       return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: c)), child: Text('${fmt[0].toUpperCase()}${fmt.substring(1)}', style: GoogleFonts.cinzel(color: c, fontWeight: FontWeight.bold)));
    }).toList());
  }

  Future<void> _showVersionsModal() async {
    if (_foundCard == null) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => VersionsSelectorSheet(oracleId: _foundCard!.oracleId, currentCardId: _foundCard!.id, onVersionSelected: (v) => _selectCard(v)),
    );
  }
  
  Future<void> _showDeckPicker() async {
    if (_foundCard == null) return;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (c) => DeckPickerModal(cardToAdd: _foundCard!, deckService: _deckService, onCardAdded: (d,c) => _showFeedback("Ajouté au deck $d", Colors.green)));
  }

  // --- NOUVEAU SELECTEUR DE WISHLIST ---
  Future<String?> _showWishlistSelector() async {
    final wishlists = await _wishlistService.loadWishlists();
    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      // Ajout de SafeArea pour éviter la barre de navigation système
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("Choisir une Wishlist", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.greenAccent),
                    title: Text("Créer une nouvelle liste", style: GoogleFonts.cinzel(color: Colors.white)),
                    onTap: () async {
                      // 1. Ouvrir le dialogue de création par-dessus
                      final name = await _showCreateWishlistDialog();
                      // 2. Si un nom a été saisi, on récupère l'ID de la nouvelle liste
                      if (name != null && mounted) {
                        final updatedLists = await _wishlistService.loadWishlists();
                        try {
                          final newList = updatedLists.lastWhere((w) => w.name == name);
                          // 3. On ferme le sélecteur en renvoyant l'ID
                          Navigator.pop(context, newList.id); 
                        } catch (_) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: wishlists.length,
                      itemBuilder: (context, index) {
                        final list = wishlists[index];
                        return ListTile(
                          leading: const Icon(Icons.bookmark_border, color: Colors.blueAccent),
                          title: Text(list.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text("${list.totalCards} cartes", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          onTap: () => Navigator.pop(context, list.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Future<String?> _showCreateWishlistDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Nouvelle Liste", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Nom de la liste"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _wishlistService.createWishlist(controller.text);
                if (mounted) Navigator.pop(c, controller.text);
              }
            },
            child: const Text("Créer"),
          )
        ],
      )
    );
  }

  Future<void> _toggleWishlist() async {
    if (_foundCard == null) return;
    
    // Si la carte est déjà présente, le bouton sert à retirer (de TOUTES les listes par sécurité/simplicité)
    // Ou alors on pourrait afficher un menu pour retirer d'une liste spécifique, mais restons simple.
    if (_inWishlist) {
      setState(() => _inWishlist = false);
      
      final lists = await _wishlistService.loadWishlists();
      for (var list in lists) {
        if (list.cards.any((c) => c.scryfallId == _foundCard!.id)) {
          await _wishlistService.upsertCard(
            wishlistId: list.id,
            scryfallId: _foundCard!.id,
            cardName: _foundCard!.name,
            absoluteQuantity: 0
          );
        }
      }
      _showFeedback('Retiré de vos Wishlists', Colors.red.shade700);
    } else {
      // AJOUT : On ouvre le sélecteur
      final targetListId = await _showWishlistSelector();
      
      if (targetListId != null) {
        // Si l'utilisateur a créé une nouvelle liste, l'ID pourrait ne pas être passé directement
        // car _showWishlistSelector retourne un Future<String?>.
        // Mais dans mon implémentation ci-dessus, si "Créer" est cliqué, on ferme le sheet, on crée,
        // et il faudrait idéalement retourner l'ID de la nouvelle liste. 
        // Pour faire simple dans _showWishlistSelector j'ai mis un retour simplifié.
        // Corrigeons le flux :
        
        await _wishlistService.upsertCard(
          wishlistId: targetListId,
          scryfallId: _foundCard!.id,
          cardName: _foundCard!.name,
          quantityToAdd: 1
        );
        
        setState(() => _inWishlist = true);
        _showFeedback('Ajouté à la Wishlist', Colors.blue.shade700);
      }
    }
  }

  Future<void> _toggleCollection() async {
    if (_foundCard == null) return;
    setState(() => _inCollection = !_inCollection);
    if (!_inCollection) {
      await _collectionService.upsertCardInCollection(scryfallId: _foundCard!.id, cardName: _foundCard!.name, absoluteQuantity: 0);
      _showFeedback('Retiré de la collection', Colors.red.shade700);
    } else {
      await _collectionService.addCard(_foundCard!, 1);
      _showFeedback('Ajouté à la collection', Colors.green.shade700);
    }
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: color, duration: const Duration(seconds: 1)));
  }

  Future<void> _fetchRulings(String cardId) async {
    setState(() { _isLoadingRulings = true; });
    try {
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/$cardId/rulings'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> rulingsList = data['data'] ?? [];
        setState(() {
          _rulings = rulingsList.map((rulingJson) => ScryfallRuling(date: rulingJson['published_at'], comment: rulingJson['comment'])).toList();
        });
      }
    } catch (e) { }
    if(mounted) setState(() { _isLoadingRulings = false; });
  }

  Future<void> _checkCardStatus() async {
    if (_foundCard == null) return;
    
    // Chargement Collection
    final collection = await _collectionService.loadCollection();
    
    // Chargement Wishlists (Nouvelle version)
    final wishlists = await _wishlistService.loadWishlists();
    
    if (!mounted) return;
    
    setState(() {
      _inCollection = collection.any((c) => c.scryfallId == _foundCard!.id);
      
      // On vérifie si la carte est présente dans AU MOINS UNE des wishlists
      _inWishlist = wishlists.any((w) => w.cards.any((c) => c.scryfallId == _foundCard!.id));
    });
  }

  Keyword? _findKeyword(String word) {
    if (_activeGlossary.isEmpty) return null;
    final normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[,\.]'), '');
    try { return _activeGlossary.firstWhere((k) => k.term.toLowerCase() == normalizedWord); } catch (e) { return null; }
  }

  InlineSpan _buildKeywordSpans(String textChunk) {
    final List<String> words = textChunk.split(' ');
    final List<InlineSpan> spans = [];
    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      final Keyword? keyword = _findKeyword(word);
      if (keyword != null) {
        spans.add(TextSpan(text: '$word ', style: GoogleFonts.cinzel(color: Colors.blue.shade300, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.blue.shade300), recognizer: TapGestureRecognizer()..onTap = () { Navigator.push(context, MaterialPageRoute(builder: (context) => GlossaryDetailPage(keyword: keyword))); }));
      } else {
        spans.add(TextSpan(text: '$word ', style: const TextStyle(color: Colors.white, height: 1.4)));
      }
    }
    return TextSpan(children: spans);
  }

  Widget _buildClickableRulesText(String text, String lang) {
    if (text.isEmpty) return Text("(Pas de texte)", style: GoogleFonts.cinzel(color: Colors.white70, fontStyle: FontStyle.italic));
    final List<InlineSpan> spans = [];
    text.splitMapJoin(_manaSymbolRegex, onMatch: (Match match) {
        final String symbol = match.group(0)!;
        spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1.0), child: _getManaIcon(symbol))));
        return '';
      }, onNonMatch: (String nonMatch) { spans.add(_buildKeywordSpans(nonMatch)); return ''; });
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null) return const SizedBox();
    final matches = _manaSymbolRegex.allMatches(manaCost).map((m) => m.group(0)!).toList();
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: matches.map((s) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: _getManaIcon(s))).toList());
  }
  
  Widget _getManaIcon(String symbol) {
     final clean = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
     return SvgPicture.network('https://svgs.scryfall.io/card-symbols/$clean.svg', width: 16, placeholderBuilder: (_) => Text(symbol, style: const TextStyle(color: Colors.white)));
  }
}