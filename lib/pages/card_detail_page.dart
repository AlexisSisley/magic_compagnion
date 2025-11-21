// Fichier : lib/pages/card_detail_page.dart
// VERSION MISE À JOUR (avec bouton Wishlist)

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; 
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart'; 
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/widgets/decks/deck_picker_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/deck_service.dart';
import '../data/glossary_data.dart'; 
import 'glossary_detail_page.dart';
import '../services/collection_service.dart'; 
import '../services/scan_history_service.dart'; 
import '../models/scan_history_model.dart'; 
import '../services/wishlist_service.dart'; // <-- 1. AJOUT DE L'IMPORT


enum ResultPageState { loading, success, error }

// Classe helper (inchangée)
class _ScryfallRuling {
  final String date;
  final String comment;
  _ScryfallRuling({required this.date, required this.comment});
}

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

  List<_ScryfallRuling> _rulings = [];
  bool _isLoadingRulings = false;

  final RegExp _manaSymbolRegex = RegExp(r'(\{.*?\})');
  final DeckService _deckService = DeckService();
  final CollectionService _collectionService = CollectionService();
  final ScanHistoryService _historyService = ScanHistoryService();
  final WishlistService _wishlistService = WishlistService();
  bool _inWishlist = false;
  bool _inCollection = false;

  @override
  void initState() {
    super.initState();
    _initializeAndSearch();
  }

  String _currentDisplayLang = 'fr';

  Future<void> _initializeAndSearch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentDisplayLang = prefs.getString('glossaryLang') ?? 'fr';
      final String assetPath = (_userLang == 'fr') ? 'assets/glossary_fr.json' : 'assets/glossary_en.json';
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List;
      _activeGlossary = jsonList.map((jsonItem) => Keyword.fromJson(jsonItem as Map<String, dynamic>)).toList();
    } catch (e) {
      print("Erreur chargement glossaire (CardDetail): $e"); _activeGlossary = []; 
    }
    if (widget.imagePath != null) { 
      _startAutomaticProcess(); 
    } 
    else if (widget.cardName != null) { 
      _searchController.text = widget.cardName!; 
      _searchScryfall(); 
    }
  }

  @override
  void dispose() { 
    _searchController.dispose(); 
    super.dispose(); 
  }

  /// Nettoie le texte brut de l'OCR pour isoler le nom de la carte
  String _cleanOcrText(String text) {
    String cleanedText = text;

    // 1. Remplacer les '0' par 'O' (souvent confondus)
    cleanedText = cleanedText.replaceAll('0', 'O');

    // 2. Supprimer les symboles de mana (WUBRG), les 'O' (confondus) 
    //    et les 'X'/'Y'/'Z' s'ils sont des mots "seuls".
    //    \b = limite de mot (word boundary)
    cleanedText = cleanedText.replaceAll(RegExp(r'\b(W|U|B|R|G|O|X|Y|Z)\b', caseSensitive: false), '');

    // 3. Supprimer tous les chiffres et les slashs (coûts incolores {5}, P/T "1/4")
    cleanedText = cleanedText.replaceAll(RegExp(r'[\d\/]'), '');

    // 4. Supprimer la ponctuation inutile que l'OCR pourrait mal lire
    //    On garde les apostrophes et les tirets (ex: "Clé-runique", "D'ailleurs")
    cleanedText = cleanedText.replaceAll(RegExp(r'[{}<>()\[\].,:;]'), '');

    // 5. Nettoyer les espaces multiples
    cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleanedText;
  }

  Future<void> _startAutomaticProcess() async {
    setState(() { _pageState = ResultPageState.loading; _statusMessage = "Analyse de l'image..."; });
    if (widget.imagePath == null) {
       setState(() { _pageState = ResultPageState.error; _statusMessage = "Erreur interne: Aucun chemin d'image fourni."; });
      return;
    }
    
    final inputImage = InputImage.fromFilePath(widget.imagePath!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    String? bestGuess;
    int bestLength = 0;
    
    // Mots-clés de ligne de type à ignorer (en minuscules)
    const List<String> typeKeywords = [
      'créature', 'creature', 'artefact', 'artifact', 'enchantement', 'enchantment',
      'éphémère', 'instant', 'rituel', 'sorcery', 'planeswalker', 'terrain', 'land',
      'tribal', 'légendaire', 'legendary', 'neigeux', 'snow'
    ];

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      // 1. Itérer sur toutes les lignes reconnues
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          String originalLine = line.text.trim();
          if (originalLine.isEmpty) continue;
          
          // 2. Nettoyer la ligne
          String cleanedLine = _cleanOcrText(originalLine);
          if (cleanedLine.isEmpty) continue;

          // 3. Vérifier si c'est une ligne de type (ex: "Créature : humain")
          String lowerCleaned = cleanedLine.toLowerCase();
          bool isTypeLine = typeKeywords.any((keyword) => lowerCleaned.startsWith(keyword));
          
          if (isTypeLine) {
            print("Ligne ignorée (type): $originalLine");
            continue;
          }

          // 4. Garder la ligne nettoyée la plus longue
          //    (Le titre est souvent plus long que les P/T ou les restes de mana)
          if (cleanedLine.length > bestLength) {
            bestLength = cleanedLine.length;
            bestGuess = cleanedLine;
            print("Meilleur candidat trouvé: $bestGuess (depuis: $originalLine)");
          }
        }
      }
    } catch (e) {
      setState(() { _pageState = ResultPageState.error; _statusMessage = "Erreur OCR: $e. Veuillez réessayer."; });
      return;
    }

    if (bestGuess == null || bestGuess.isEmpty) {
      setState(() { _pageState = ResultPageState.error; _statusMessage = "Aucun texte de titre reconnu. Veuillez entrer le nom manuellement."; });
      return;
    }

    // 5. Utiliser le meilleur candidat (nettoyé) pour la recherche
    _searchController.text = bestGuess;
    await _searchScryfall();
  }

  Future<void> _searchScryfall() async {
    final String cardName = _searchController.text.trim();
    if (cardName.isEmpty) { /* ... */ return; }
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) { /* ... */ return; }
    setState(() {
      _pageState = ResultPageState.loading;
      _statusMessage = "Recherche de \"$cardName\" (${_currentDisplayLang.toUpperCase()})..."; 
      _rulings = [];
    });

    try {
      // Utilise _currentDisplayLang dans l'URL
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/named?fuzzy=$cardName&lang=$_currentDisplayLang'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final ScryfallCard foundCard = ScryfallCard.fromJson(data);
        setState(() { _foundCard = foundCard; _pageState = ResultPageState.success; });
        if (widget.imagePath != null) {
          final newItem = ScanHistoryItem(
            scryfallId: foundCard.id, cardName: foundCard.name,
            imagePath: widget.imagePath, timestamp: DateTime.now()
          );
          await _historyService.addScan(newItem);
        }
        _fetchRulings(foundCard.id);
        await _checkCardStatus();
      } else {
        setState(() {
          _statusMessage = "Carte \"$cardName\" non trouvée (Code: ${response.statusCode}). Vérifiez le nom et réessayez.";
          _pageState = ResultPageState.error;
        });
      }
    } catch (e) {
      setState(() { _statusMessage = "Erreur réseau: $e"; _pageState = ResultPageState.error; });
    }
  }

  void _toggleLanguage() {
    setState(() {
      _currentDisplayLang = (_currentDisplayLang == 'fr') ? 'en' : 'fr';
    });
    _searchScryfall(); // Relance la recherche avec la nouvelle langue
  }

  Future<void> _fetchRulings(String cardId) async {
    setState(() { _isLoadingRulings = true; });
    try {
      final response = await http.get(Uri.parse('https://api.scryfall.com/cards/$cardId/rulings'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> rulingsList = data['data'] ?? [];
        final DateFormat apiFormatter = DateFormat('yyyy-MM-dd');
        final DateFormat displayFormatter = DateFormat('d MMM y', 'fr_FR');
        setState(() {
          _rulings = rulingsList.map((rulingJson) {
            String formattedDate = '';
            try { formattedDate = displayFormatter.format(apiFormatter.parse(rulingJson['published_at'])); } 
            catch (e) { formattedDate = rulingJson['published_at']; }
            return _ScryfallRuling(date: formattedDate, comment: rulingJson['comment']);
          }).toList();
        });
      }
    } catch (e) { print("Erreur chargement rulings: $e"); }
    if(mounted) { setState(() { _isLoadingRulings = false; }); }
  }

  /// Vérifie si la carte trouvée est dans la wishlist ou la collection
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

  /// Ajoute ou retire la carte de la wishlist
  Future<void> _toggleWishlist() async {
    if (_foundCard == null) return;
    
    if (_inWishlist) {
      // Retirer
      await _wishlistService.upsertCardInWishlist(
        scryfallId: _foundCard!.id,
        cardName: _foundCard!.name,
        absoluteQuantity: 0, // Met la quantité à 0, ce qui la supprime
      );
      _showFeedback(context, '"${_foundCard!.name}" retiré de la Wishlist', Colors.red.shade700);
    } else {
      // Ajouter
      await _wishlistService.addCard(_foundCard!, 1);
      _showFeedback(context, '"${_foundCard!.name}" ajouté à la Wishlist', Colors.blue.shade700);
    }
    
    // Met à jour l'icône
    setState(() {
      _inWishlist = !_inWishlist;
    });
  }

  /// Ajoute ou retire la carte de la collection
  Future<void> _toggleCollection() async {
    if (_foundCard == null) return;
    
    if (_inCollection) {
      // Retirer
      await _collectionService.upsertCardInCollection(
        scryfallId: _foundCard!.id,
        cardName: _foundCard!.name,
        absoluteQuantity: 0, // Met la quantité à 0, ce qui la supprime
      );
      _showFeedback(context, '"${_foundCard!.name}" retiré de la collection', Colors.red.shade700);
    } else {
      // Ajouter
      await _collectionService.addCard(_foundCard!, 1);
      _showFeedback(context, '"${_foundCard!.name}" ajouté à la collection', Colors.green.shade700);
    }
    
    // Met à jour l'icône
    setState(() {
      _inCollection = !_inCollection;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Résultat", style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        
        actions: [
          if (_pageState == ResultPageState.success)
            TextButton(
              onPressed: _toggleLanguage,
              child: Text(
                _currentDisplayLang.toUpperCase(),
                style: GoogleFonts.cinzel(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          if (_pageState == ResultPageState.success && _foundCard != null) ...[
            // Bouton Wishlist (Toggle)
            IconButton(
              icon: Icon(
                _inWishlist ? Icons.star : Icons.star_border_outlined, // Icône dynamique
                color: _inWishlist ? Colors.blue.shade400 : Colors.white,
              ),
              tooltip: _inWishlist ? 'Retirer de la Wishlist' : 'Ajouter à la Wishlist',
              onPressed: _toggleWishlist, // Appelle la fonction de toggle
            ),
            // Bouton Collection (Toggle)
            IconButton(
              icon: Icon(
                _inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, // Icône dynamique
                color: _inCollection ? Colors.green.shade400 : Colors.white,
              ),
              tooltip: _inCollection ? 'Retirer de la collection' : 'Ajouter à la collection',
              onPressed: _toggleCollection, // Appelle la fonction de toggle
            )
          ]
        ],
      ),
      
      body: _buildBody(), 
      
      floatingActionButton: _pageState == ResultPageState.success
          ? FloatingActionButton(
              onPressed: _showDeckPicker, // Inchangé (pour les decks)
              backgroundColor: Colors.yellow.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_to_photos_outlined), 
            )
          : null,
    );
  }
  
  // Helper pour afficher les notifications
  void _showFeedback(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      duration: const Duration(seconds: 1),
    ));
  }

  // --- (Toutes les autres fonctions _showDeckPicker, _buildBody, _buildInfoCard, _buildPriceInfo, _buildLegalities, _buildRulingsList, etc... sont INCHANGÉES) ---
  Future<void> _showDeckPicker() async {
    if (_foundCard == null) return;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (modalContext) {
        return DeckPickerModal(
          deckService: _deckService,
          cardToAdd: _foundCard!,
          onCardAdded: (deckName, cardName) {
            if (!context.mounted) return;
            _showFeedback(context, '"$cardName" ajouté à "$deckName"', Colors.yellow.shade700);
          },
        );
      },
    );
  }
  Widget _buildBody() {
    final mediaQuery = MediaQuery.of(context);
    switch (_pageState) {
      case ResultPageState.loading:
        return Center(
          child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        );
      case ResultPageState.success:
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0 + mediaQuery.padding.bottom + 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.black.withAlpha((0.4 * 255).round()), elevation: 2.0, margin: const EdgeInsets.symmetric(vertical: 5.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: BorderSide(color:Colors.yellow.shade800.withAlpha((0.6 * 255).round()), width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.network(_foundCard!.imageUrl, fit: BoxFit.fitWidth),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildManaCostRow(_foundCard!.manaCost),
                          Text(
                            _foundCard!.printedName ?? _foundCard!.name, // <-- LA CLÉ EST ICI
                            style: GoogleFonts.cinzel(
                              color: Colors.white, 
                              fontSize: 24, 
                              fontWeight: FontWeight.bold
                            ), 
                            textAlign: TextAlign.center
                          ),
                          Text(_foundCard!.typeLine, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildInfoCard(title: 'Texte des règles', child: _buildClickableRulesText(_foundCard!.rulesText, _foundCard!.lang)),
              _buildInfoCard(title: 'Prix (approximatif)', child: _buildPriceInfo(_foundCard!.prices)),
              _buildInfoCard(title: 'Légalité en tournoi', child: _buildLegalities(_foundCard!.legalities)),
              
              
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
              Text(_statusMessage, style: GoogleFonts.cinzel(color: Colors.red.shade300, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Nom de la carte', hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 16),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true, fillColor: Colors.black.withAlpha((0.5 * 255).round()),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white70, width: 1)),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _searchScryfall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade800.withAlpha((0.8 * 255).round()),
                  foregroundColor: Colors.white,
                ),
                child: Text('Rechercher', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
    }
  }
  Widget _buildRulingsList() {
    if (_isLoadingRulings) { return const Center(child: CircularProgressIndicator(strokeWidth: 2)); }
    if (_rulings.isEmpty) {
      return Text('(Aucune décision de règle officielle trouvée)', style: GoogleFonts.cinzel(color: Colors.white70, fontStyle: FontStyle.italic));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _rulings.map((ruling) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ruling.date, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(ruling.comment, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildInfoCard({required String title, required Widget child}) {
    return Card(
      color: Colors.black.withAlpha((0.4 * 255).round()), elevation: 2.0, margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: Colors.yellow.shade800.withAlpha((0.6 * 255).round()), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(title, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          Container(height: 1, color: Colors.yellow.shade800.withAlpha((0.6 * 255).round())),
          Padding(padding: const EdgeInsets.all(16.0), child: child),
        ],
      ),
    );
  }
  Widget _buildPriceInfo(Map<String, dynamic> prices) {
    final String priceEur = prices['eur'] ?? 'N/A';
    final String priceEurFoil = prices['eur_foil'] ?? 'N/A';
    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Normal : $priceEur €', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16)),
        Text('Foil : $priceEurFoil €', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16)),
      ],
    );
  }
  Widget _buildLegalities(Map<String, String> legalities) {
    const List<String> formats = ['standard', 'pioneer', 'modern', 'commander'];
    String formatName(String key) { return key[0].toUpperCase() + key.substring(1); }
    Widget formatStatus(String status) {
      Color color; String text;
      switch (status) {
        case 'legal': text = 'Légal'; color = Colors.green.shade400; break;
        case 'not_legal': text = 'Non Légal'; color = Colors.grey; break;
        case 'banned': text = 'Banni'; color = Colors.red.shade400; break;
        case 'restricted': text = 'Restreint'; color = Colors.orange.shade400; break;
        default: text = status; color = Colors.white;
      }
      return Text(text, style: GoogleFonts.cinzel(color: color, fontWeight: FontWeight.bold, fontSize: 16));
    }
    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...formats.map((formatKey) {
          final status = legalities[formatKey] ?? 'N/A';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row( children: [
                Text('${formatName(formatKey)} :', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                formatStatus(status),
              ],
            ),
          );
        })
      ],
    );
  }
  Widget _getManaIcon(String symbol) {
    final String cleanSymbol = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    final String svgUrl = 'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg';
    return SvgPicture.network(
      svgUrl, height: 16, width: 16,
      placeholderBuilder: (context) => Text(symbol, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
    );
  }
  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) { return const SizedBox.shrink(); }
    final List<String> symbols = _manaSymbolRegex.allMatches(manaCost).map((match) => match.group(0)!).toList();
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row( mainAxisAlignment: MainAxisAlignment.center, children: symbols.map((symbol) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: _getManaIcon(symbol),
                )).toList(),
      ),
    );
  }
  Keyword? _findKeyword(String word) {
    if (_activeGlossary.isEmpty) return null;
    final normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[,\.]'), '');
    try { return _activeGlossary.firstWhere((keyword) => keyword.term.toLowerCase() == normalizedWord); } 
    catch (e) { return null; }
  }
  InlineSpan _buildKeywordSpans(String textChunk) {
    final List<String> words = textChunk.split(' ');
    final List<InlineSpan> spans = [];
    for (final word in words) {
      final keyword = _findKeyword(word);
      if (keyword != null) {
        spans.add(TextSpan(
            text: '$word ',
            style: GoogleFonts.cinzel(
              color: Colors.blue.shade300, fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline, fontSize: 16,
            ),
            recognizer: TapGestureRecognizer()..onTap = () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => GlossaryDetailPage(keyword: keyword)));
              },
          ),
        );
      } else {
        spans.add(TextSpan(text: '$word ', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, height: 1.4)));
      }
    }
    return TextSpan(children: spans);
  }
  Widget _buildClickableRulesText(String text, String cardLang) {
    if (text.trim().isEmpty) {
      return Text('(Aucun texte de règles)', style: GoogleFonts.cinzel(color: Colors.white70, fontStyle: FontStyle.italic));
    }
    final List<InlineSpan> spans = [];
    text.splitMapJoin(
      _manaSymbolRegex,
      onMatch: (Match match) {
        final String symbol = match.group(0)!;
        spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1.0), child: _getManaIcon(symbol)),
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(_buildKeywordSpans(nonMatch));
        return '';
      },
    );
    return RichText(text: TextSpan(children: spans));
  }
}