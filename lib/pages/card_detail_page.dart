// Fichier : lib/pages/card_detail_page.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:magic_companion/pages/glossary_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// IMPORTS LOCAUX
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/widgets/decks/deck_picker_modal.dart';
import '../services/deck_service.dart';
import '../data/glossary_data.dart';
import '../services/collection_service.dart';
import '../services/scan_history_service.dart';
import '../models/scan_history_model.dart';
import '../services/wishlist_service.dart';

// NOUVEAUX IMPORTS
import '../models/scryfall_ruling.dart'; 
import '../widgets/cards/versions_selector_sheet.dart';

enum ResultPageState { loading, success, error }

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
  String _statusMessage = "Analyse de l'image...";
  
  ScryfallCard? _foundCard;
  
  String _userLang = 'fr';
  List<Keyword> _activeGlossary = [];
  List<ScryfallRuling> _rulings = []; // Utilise la nouvelle classe importée
  bool _isLoadingRulings = false;

  final RegExp _manaSymbolRegex = RegExp(r'(\{.*?\})');
  final DeckService _deckService = DeckService();
  final CollectionService _collectionService = CollectionService();
  final ScanHistoryService _historyService = ScanHistoryService();
  final WishlistService _wishlistService = WishlistService();
  
  bool _inWishlist = false;
  bool _inCollection = false;
  String _currentDisplayLang = 'fr';

  @override
  void initState() {
    super.initState();
    _initializeAndSearch();
  }

  Future<void> _initializeAndSearch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentDisplayLang = prefs.getString('glossaryLang') ?? 'fr';
      final String assetPath = (_userLang == 'fr') ? 'assets/glossary_fr.json' : 'assets/glossary_en.json';
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List;
      _activeGlossary = jsonList.map((jsonItem) => Keyword.fromJson(jsonItem as Map<String, dynamic>)).toList();
    } catch (e) {
      print("Erreur chargement glossaire: $e");
      _activeGlossary = [];
    }
    if (widget.imagePath != null) {
      _startAutomaticProcess();
    } else if (widget.cardName != null) {
      _searchController.text = widget.cardName!;
      _searchScryfall();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _cleanOcrText(String text) {
    String cleanedText = text;
    cleanedText = cleanedText.replaceAll('0', 'O');
    cleanedText = cleanedText.replaceAll(RegExp(r'\b(W|U|B|R|G|O|X|Y|Z)\b', caseSensitive: false), '');
    cleanedText = cleanedText.replaceAll(RegExp(r'[\d\/]'), '');
    cleanedText = cleanedText.replaceAll(RegExp(r'[{}<>()\[\].,:;]'), '');
    cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleanedText;
  }

  Future<void> _startAutomaticProcess() async {
    setState(() { _pageState = ResultPageState.loading; _statusMessage = "Analyse de l'image..."; });
    if (widget.imagePath == null) {
      setState(() { _pageState = ResultPageState.error; _statusMessage = "Erreur interne: Aucun chemin d'image."; });
      return;
    }
    
    final inputImage = InputImage.fromFilePath(widget.imagePath!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    String? bestGuess;
    int bestLength = 0;
    const List<String> typeKeywords = ['créature', 'creature', 'artefact', 'artifact', 'enchantement', 'enchantment', 'éphémère', 'instant', 'rituel', 'sorcery', 'planeswalker', 'terrain', 'land', 'tribal', 'légendaire', 'legendary', 'neigeux', 'snow'];

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          String originalLine = line.text.trim();
          if (originalLine.isEmpty) continue;
          String cleanedLine = _cleanOcrText(originalLine);
          if (cleanedLine.isEmpty) continue;
          String lowerCleaned = cleanedLine.toLowerCase();
          bool isTypeLine = typeKeywords.any((keyword) => lowerCleaned.startsWith(keyword));
          if (isTypeLine) continue;
          if (cleanedLine.length > bestLength) {
            bestLength = cleanedLine.length;
            bestGuess = cleanedLine;
          }
        }
      }
    } catch (e) {
      setState(() { _pageState = ResultPageState.error; _statusMessage = "Erreur OCR: $e"; });
      return;
    }

    if (bestGuess == null || bestGuess.isEmpty) {
      setState(() { _pageState = ResultPageState.error; _statusMessage = "Titre non reconnu."; });
      return;
    }
    _searchController.text = bestGuess;
    await _searchScryfall();
  }

  Future<void> _searchScryfall() async {
    final String cardName = _searchController.text.trim();
    if (cardName.isEmpty) return;
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) return;
    
    setState(() {
      _pageState = ResultPageState.loading;
      _statusMessage = "Recherche de \"$cardName\"...";
      _rulings = [];
    });

    try {
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/named?fuzzy=$cardName&lang=$_currentDisplayLang'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final ScryfallCard foundCard = ScryfallCard.fromJson(data);
        
        setState(() { _foundCard = foundCard; _pageState = ResultPageState.success; });
        
        if (widget.imagePath != null) {
          final newItem = ScanHistoryItem(scryfallId: foundCard.id, cardName: foundCard.name, imagePath: widget.imagePath, timestamp: DateTime.now());
          await _historyService.addScan(newItem);
        }
        _fetchRulings(foundCard.id);
        await _checkCardStatus();
      } else {
        setState(() {
          _statusMessage = "Carte non trouvée (Code: ${response.statusCode}).";
          _pageState = ResultPageState.error;
        });
      }
    } catch (e) {
      setState(() { _statusMessage = "Erreur réseau: $e"; _pageState = ResultPageState.error; });
    }
  }

  // APPEL AU WIDGET SÉPARÉ
  Future<void> _showVersionsModal() async {
    if (_foundCard == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VersionsSelectorSheet(
        oracleId: _foundCard!.oracleId,
        currentCardId: _foundCard!.id,
        onVersionSelected: (ScryfallCard selectedVersion) {
           setState(() {
             _foundCard = selectedVersion;
           });
           _checkCardStatus(); 
        },
      ),
    );
  }

  void _toggleLanguage() {
    setState(() => _currentDisplayLang = (_currentDisplayLang == 'fr') ? 'en' : 'fr');
    _searchScryfall();
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
    } catch (e) { /* ... */ }
    if(mounted) setState(() { _isLoadingRulings = false; });
  }

  Future<void> _checkCardStatus() async {
    if (_foundCard == null) return;
    final collection = await _collectionService.loadCollection();
    final wishlist = await _wishlistService.loadWishlist();
    if (!mounted) return;
    setState(() {
      _inCollection = collection.any((c) => c.scryfallId == _foundCard!.id);
      _inWishlist = wishlist.any((c) => c.scryfallId == _foundCard!.id);
    });
  }

  Future<void> _toggleWishlist() async {
    if (_foundCard == null) return;
    if (_inWishlist) {
      await _wishlistService.upsertCardInWishlist(scryfallId: _foundCard!.id, cardName: _foundCard!.name, absoluteQuantity: 0);
      _showFeedback('"Let\'s remove it!"', Colors.red.shade700);
    } else {
      await _wishlistService.addCard(_foundCard!, 1);
      _showFeedback('Ajouté à la Wishlist', Colors.blue.shade700);
    }
    setState(() => _inWishlist = !_inWishlist);
  }

  Future<void> _toggleCollection() async {
    if (_foundCard == null) return;
    if (_inCollection) {
      await _collectionService.upsertCardInCollection(scryfallId: _foundCard!.id, cardName: _foundCard!.name, absoluteQuantity: 0);
      _showFeedback('Retiré de la collection', Colors.red.shade700);
    } else {
      await _collectionService.addCard(_foundCard!, 1);
      _showFeedback('Ajouté à la collection', Colors.green.shade700);
    }
    setState(() => _inCollection = !_inCollection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Détail Carte", style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        actions: [
          if (_pageState == ResultPageState.success) ...[
            IconButton(
              icon: const Icon(Icons.style, color: Colors.white),
              tooltip: 'Autres Versions / Editions',
              onPressed: _showVersionsModal,
            ),
            TextButton(
              onPressed: _toggleLanguage,
              child: Text(_currentDisplayLang.toUpperCase(), style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(_inWishlist ? Icons.star : Icons.star_border_outlined, color: _inWishlist ? Colors.blue.shade400 : Colors.white),
              onPressed: _toggleWishlist,
            ),
            IconButton(
              icon: Icon(_inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, color: _inCollection ? Colors.green.shade400 : Colors.white),
              onPressed: _toggleCollection,
            )
          ]
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _pageState == ResultPageState.success
          ? FloatingActionButton(
              onPressed: _showDeckPicker,
              backgroundColor: Colors.yellow.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_to_photos_outlined),
            )
          : null,
    );
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color, duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _showDeckPicker() async {
    if (_foundCard == null) return;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (modalContext) => DeckPickerModal(
          deckService: _deckService,
          cardToAdd: _foundCard!,
          onCardAdded: (deckName, cardName) => _showFeedback('Ajouté à "$deckName"', Colors.yellow.shade700),
      ),
    );
  }

  Widget _buildBody() {
    final mediaQuery = MediaQuery.of(context);
    switch (_pageState) {
      case ResultPageState.loading:
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.white))]));
      case ResultPageState.success:
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0 + mediaQuery.padding.bottom + 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.black.withAlpha(100),
                elevation: 4.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.yellow.shade800.withAlpha(150), width: 1)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.network(_foundCard!.imageUrl, fit: BoxFit.fitWidth,
                       loadingBuilder: (c, child, progress) => progress == null ? child : const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
                       errorBuilder: (c, e, s) => const SizedBox(height: 300, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white))),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          _buildManaCostRow(_foundCard!.manaCost),
                          const SizedBox(height: 8),
                          Text(_foundCard!.printedName ?? _foundCard!.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          Text(_foundCard!.typeLine, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '${_foundCard!.setName}  •  #${_foundCard!.collectorNumber}',
                              style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _searchScryfall, style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800), child: Text('Rechercher', style: GoogleFonts.cinzel())),
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
        Column(children: [
          Text('Normal', style: GoogleFonts.cinzel(color: Colors.white70)),
          Text('$priceEur €', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        Container(width: 1, height: 30, color: Colors.white24),
        Column(children: [
          Text('Foil (Brillant)', style: GoogleFonts.cinzel(color: Colors.amber.shade200)),
          Text('$priceEurFoil €', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
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
      color: Colors.black.withAlpha(102), elevation: 2, margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.yellow.shade800.withAlpha(150))),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)), const Divider(color: Colors.white24), const SizedBox(height: 8), child])),
    );
  }
  
  Widget _buildLegalities(Map<String, String> legalities) {
    const formats = ['standard', 'commander', 'modern', 'pioneer'];
    return Wrap(spacing: 12, runSpacing: 8, children: formats.map((fmt) {
       final status = legalities[fmt] ?? 'not_legal';
       Color c = status == 'legal' ? Colors.green : (status == 'banned' ? Colors.red : Colors.grey);
       return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: c)), child: Text('${fmt[0].toUpperCase()}${fmt.substring(1)}', style: GoogleFonts.cinzel(color: c, fontWeight: FontWeight.bold)));
    }).toList());
  }

  // --- GESTION DES MOTS-CLÉS (GLOSSAIRE) ---

  // 1. Cherche si un mot existe dans le glossaire actif
  Keyword? _findKeyword(String word) {
    if (_activeGlossary.isEmpty) return null;
    // Nettoyage basique (enlever ponctuation comme virgules ou points)
    final normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[,\.]'), '');
    try {
      return _activeGlossary.firstWhere(
        (keyword) => keyword.term.toLowerCase() == normalizedWord
      );
    } catch (e) {
      return null;
    }
  }

  // 2. Construit les spans de texte (mots normaux + mots-clés cliquables)
  InlineSpan _buildKeywordSpans(String textChunk) {
    final List<String> words = textChunk.split(' ');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      final Keyword? keyword = _findKeyword(word);

      if (keyword != null) {
        // C'est un mot-clé : on le rend bleu et cliquable
        spans.add(
          TextSpan(
            text: '$word ', // Remet l'espace après le mot
            style: GoogleFonts.cinzel(
              color: Colors.blue.shade300,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: Colors.blue.shade300,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GlossaryDetailPage(keyword: keyword),
                  ),
                );
              },
          ),
        );
      } else {
        // Mot normal
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(color: Colors.white, height: 1.4),
        ));
      }
    }
    return TextSpan(children: spans);
  }

  // 3. La méthode principale qui remplace celle simplifiée
  Widget _buildClickableRulesText(String text, String lang) {
    if (text.isEmpty) {
      return Text("(Pas de texte)", style: GoogleFonts.cinzel(color: Colors.white70, fontStyle: FontStyle.italic));
    }
    
    final List<InlineSpan> spans = [];
    
    // On sépare le texte par les symboles de mana ({T}, {1}, etc.)
    text.splitMapJoin(
      _manaSymbolRegex,
      onMatch: (Match match) {
        final String symbol = match.group(0)!;
        // Ajoute l'icône de mana
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle, 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0), 
            child: _getManaIcon(symbol)
          )
        ));
        return '';
      },
      onNonMatch: (String nonMatch) {
        // Analyse le texte entre les symboles pour trouver les mots-clés
        spans.add(_buildKeywordSpans(nonMatch));
        return '';
      },
    );
    
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