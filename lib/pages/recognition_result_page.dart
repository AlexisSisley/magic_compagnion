// Fichier : lib/pages/recognition_result_page.dart
// CORRECTION : Ajout du padding pour la barre de navigation

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/glossary_data.dart';
import '../data/glossary_data_en.dart';
import 'glossary_detail_page.dart';

// ... (Le modèle ScryfallCard et l'enum sont inchangés) ...
enum ResultPageState { loading, success, error }

class ScryfallCard {
  final String name;
  final String? manaCost;
  final String imageUrl;
  final String rulesText;
  final String typeLine;
  final Map<String, String> legalities;
  final Map<String, dynamic> prices;
  final String lang;

  ScryfallCard({
    required this.name,
    this.manaCost,
    required this.imageUrl,
    required this.rulesText,
    required this.typeLine,
    required this.legalities,
    required this.prices,
    required this.lang,
  });

  factory ScryfallCard.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    String rulesText = '';
    String? manaCost;

    if (json['card_faces'] != null &&
        json['card_faces'][0]['image_uris'] != null) {
      final face = json['card_faces'][0];
      imageUrl = face['image_uris']['normal'];
      rulesText = face['printed_text'] ?? face['oracle_text'] ?? '';
      manaCost = face['mana_cost'];
    } else {
      if (json['image_uris'] != null) {
        imageUrl = json['image_uris']['normal'];
      }
      rulesText = json['printed_text'] ?? json['oracle_text'] ?? '';
      manaCost = json['mana_cost'];
    }

    return ScryfallCard(
      name: json['name'],
      manaCost: manaCost,
      imageUrl: imageUrl,
      rulesText: rulesText,
      typeLine: json['type_line'],
      legalities: Map<String, String>.from(json['legalities']),
      prices: Map<String, dynamic>.from(json['prices']),
      lang: json['lang'] ?? 'en',
    );
  }
}
// ...

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
  List<Keyword> _activeGlossary = glossaryTerms;

  final RegExp _manaSymbolRegex = RegExp(r'(\{.*?\})');

  @override
  void initState() {
    super.initState();
    _initializeAndSearch();
  }

  Future<void> _initializeAndSearch() async {
    final prefs = await SharedPreferences.getInstance();
    _userLang = prefs.getString('glossaryLang') ?? 'fr';
    
    _activeGlossary = (_userLang == 'fr') ? glossaryTerms : glossaryTermsEN;
    
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

  Future<void> _startAutomaticProcess() async {
    setState(() {
      _pageState = ResultPageState.loading;
      _statusMessage = "Analyse de l'image...";
    });

    if (widget.imagePath == null) {
       setState(() {
        _pageState = ResultPageState.error;
        _statusMessage = "Erreur interne: Aucun chemin d'image fourni.";
      });
      return;
    }

    final inputImage = InputImage.fromFilePath(widget.imagePath!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String? cardName;

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          if (line.text.trim().isNotEmpty) {
            cardName = line.text.trim();
            break;
          }
        }
        if (cardName != null) break;
      }
    } catch (e) {
      setState(() {
        _pageState = ResultPageState.error;
        _statusMessage = "Erreur OCR: $e. Veuillez réessayer.";
      });
      return;
    }

    if (cardName == null || cardName.isEmpty) {
    setState(() {
      _pageState = ResultPageState.error;
      _statusMessage = "Aucun texte reconnu. Veuillez entrer le nom manuellement.";
    });
    return;
  }
    
    _searchController.text = cardName;
    await _searchScryfall();
  }

  Future<void> _searchScryfall() async {
    final String cardName = _searchController.text.trim();
    if (cardName.isEmpty) {
      setState(() {
        _pageState = ResultPageState.error;
        _statusMessage = "Veuillez entrer un nom de carte.";
      });
      return;
    }
    
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        _pageState = ResultPageState.error;
        _statusMessage = "Erreur : Pas de connexion internet.";
      });
      return;
    }

    setState(() {
      _pageState = ResultPageState.loading;
      _statusMessage = "Recherche de \"$cardName\"...";
    });

    try {
      final response = await http.get(Uri.parse(
          'https://api.scryfall.com/cards/named?fuzzy=$cardName&lang=$_userLang'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _foundCard = ScryfallCard.fromJson(data);
          _pageState = ResultPageState.success;
        });
      } else {
        setState(() {
          _statusMessage =
              "Carte \"$cardName\" non trouvée (Code: ${response.statusCode}). Vérifiez le nom et réessayez.";
          _pageState = ResultPageState.error;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Erreur réseau: $e";
        _pageState = ResultPageState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(
          "Résultat",
          style: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
      ),
      body: _buildBody(), // Appel de la méthode modifiée
    );
  }

  // --- WIDGETS D'AFFICHAGE ---

  Widget _buildBody() {
    // --- CORRECTION : On récupère le MediaQuery ici ---
    final mediaQuery = MediaQuery.of(context);
    
    switch (_pageState) {
      case ResultPageState.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case ResultPageState.success:
        return SingleChildScrollView(
          // --- CORRECTION : On modifie le padding ---
          padding: EdgeInsets.fromLTRB(
            8.0, // left
            8.0, // top
            8.0, // right
            8.0 + mediaQuery.padding.bottom, // bottom (padding de 8 + zone de nav)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ... (Le reste des Cards reste inchangé) ...
              Card(
                color: Colors.black.withOpacity(0.4),
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(vertical: 5.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: BorderSide(
                    color: Colors.yellow.shade800.withOpacity(0.6),
                    width: 1,
                  ),
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
                            _foundCard!.name,
                            style: GoogleFonts.cinzel(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _foundCard!.typeLine,
                            style: GoogleFonts.cinzel(
                                color: Colors.white70,
                                fontSize: 18,
                                fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildInfoCard(
                title: 'Prix (approximatif)',
                child: _buildPriceInfo(_foundCard!.prices),
              ),

              _buildInfoCard(
                title: 'Légalité en tournoi',
                child: _buildLegalities(_foundCard!.legalities),
              ),

              _buildInfoCard(
                title: 'Texte des règles',
                child: _buildClickableRulesText(_foundCard!.rulesText, _foundCard!.lang),
              ),
              
              // On n'a plus besoin du SizedBox en bas,
              // le padding s'en charge.
            ],
          ),
        );

      case ResultPageState.error:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _statusMessage,
                style: GoogleFonts.cinzel(
                    color: Colors.red.shade300, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Nom de la carte',
                  hintStyle:
                      GoogleFonts.cinzel(color: Colors.white54, fontSize: 16),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Colors.white70, width: 1),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _searchScryfall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade800.withOpacity(0.8),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Rechercher',
                  style: GoogleFonts.cinzel(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
    }
  }

  // ... (Tous les autres widgets helpers _buildInfoCard, _findKeyword, etc. sont inchangés) ...
  
  Widget _buildInfoCard({required String title, required Widget child}) {
    return Card(
      color: Colors.black.withOpacity(0.4),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(
          vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: Colors.yellow.shade800.withOpacity(0.6),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              title,
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            height: 1,
            color: Colors.yellow.shade800.withOpacity(0.6),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInfo(Map<String, dynamic> prices) {
    final String priceEur = prices['eur'] ?? 'N/A';
    final String priceEurFoil = prices['eur_foil'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Normal : $priceEur €',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
        ),
        Text(
          'Foil : $priceEurFoil €',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildLegalities(Map<String, String> legalities) {
    const List<String> formats = ['standard', 'pioneer', 'modern', 'commander'];

    String formatName(String key) {
      return key[0].toUpperCase() + key.substring(1);
    }

    Widget formatStatus(String status) {
      Color color;
      String text;
      switch (status) {
        case 'legal':
          text = 'Légal';
          color = Colors.green.shade400;
          break;
        case 'not_legal':
          text = 'Non Légal';
          color = Colors.grey;
          break;
        case 'banned':
          text = 'Banni';
          color = Colors.red.shade400;
          break;
        case 'restricted':
          text = 'Restreint';
          color = Colors.orange.shade400;
          break;
        default:
          text = status;
          color = Colors.white;
      }
      return Text(
        text,
        style: GoogleFonts.cinzel(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...formats.map((formatKey) {
          final status = legalities[formatKey] ?? 'N/A';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Text(
                  '${formatName(formatKey)} :',
                  style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
                ),
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
        style: GoogleFonts.cinzel(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<String> symbols = _manaSymbolRegex
        .allMatches(manaCost)
        .map((match) => match.group(0)!)
        .toList();

    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: symbols
            .map((symbol) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: _getManaIcon(symbol),
                ))
            .toList(),
      ),
    );
  }

  Keyword? _findKeyword(String word) {
    if (_foundCard!.lang != _userLang) {
      return null;
    }
    
    final normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[,\.]'), '');
    
    for (final keyword in _activeGlossary) {
      if (keyword.term.toLowerCase() == normalizedWord) {
        return keyword;
      }
    }
    return null;
  }

  InlineSpan _buildKeywordSpans(String textChunk) {
    final List<String> words = textChunk.split(' ');
    final List<InlineSpan> spans = [];

    for (final word in words) {
      final keyword = _findKeyword(word);

      if (keyword != null) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: GoogleFonts.cinzel(
              color: Colors.blue.shade300,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              fontSize: 16,
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
        spans.add(
          TextSpan(
            text: '$word ',
            style: GoogleFonts.cinzel(
                color: Colors.white, fontSize: 16, height: 1.4),
          ),
        );
      }
    }
    return TextSpan(children: spans);
  }

  Widget _buildClickableRulesText(String text, String cardLang) {
    if (text.trim().isEmpty) {
      return Text(
        '(Aucun texte de règles)',
        style: GoogleFonts.cinzel(color: Colors.white70, fontStyle: FontStyle.italic),
      );
    }
    
    final List<InlineSpan> spans = [];

    text.splitMapJoin(
      _manaSymbolRegex,
      onMatch: (Match match) {
        final String symbol = match.group(0)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: _getManaIcon(symbol),
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(_buildKeywordSpans(nonMatch));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}