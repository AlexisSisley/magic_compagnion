// Fichier : lib/pages/card_search_page.dart
// VERSION MISE À JOUR (Multilingue)

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- AJOUTÉ
import 'recognition_result_page.dart';

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({super.key});

  @override
  State<CardSearchPage> createState() => _CardSearchPageState();
}

class _CardSearchPageState extends State<CardSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String _statusMessage = 'Entrez un nom de carte pour commencer.';

  Future<void> _searchCards() async {
    final String query = _searchController.text.trim();
    if (query.isEmpty) return;

    // --- Vérification de connexion (inchangée) ---
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        _isLoading = false;
        _searchResults = [];
        _statusMessage = "Erreur : Pas de connexion internet.";
      });
      return;
    }
    
    // --- NOUVEAU : Charger la langue préférée ---
    final prefs = await SharedPreferences.getInstance();
    final String lang = prefs.getString('glossaryLang') ?? 'fr';
    // ---

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _statusMessage = 'Recherche de "$query"...';
    });

    try {
      // --- MODIFIÉ : Utilisation de la variable 'lang' ---
      final response = await http.get(Uri.parse(
          'https://api.scryfall.com/cards/search?q=$query&lang=$lang'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _isLoading = false;
          _searchResults = data['data'] ?? [];
          if (_searchResults.isEmpty) {
            _statusMessage = 'Aucune carte trouvée pour "$query".';
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Erreur: ${response.statusCode}. Veuillez réessayer.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Erreur réseau: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le reste du build est inchangé...
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Rechercher une carte...', // Gardé simple
              hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 16),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.white70),
                onPressed: _searchCards,
              ),
              filled: true,
              fillColor: Colors.black54,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white70, width: 1),
              ),
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
    // ... (inchangé)
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _statusMessage,
            style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final card = _searchResults[index];
        final String cardName = card['name'] ?? 'Nom inconnu';
        final String cardType = card['type_line'] ?? '';

        String? imageUrl;
        if (card['image_uris'] != null) {
          imageUrl = card['image_uris']['small'];
        } else if (card['card_faces'] != null) {
          imageUrl = card['card_faces'][0]['image_uris']['small'];
        }

        return Card(
          color: Colors.black.withAlpha(102),
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: Colors.yellow.shade800.withAlpha(153),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: imageUrl != null
                  ? Image.network(imageUrl,
                      width: 50, height: 70, fit: BoxFit.cover)
                  : Container(
                      width: 50,
                      height: 70,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.image, color: Colors.white30)),
            ),
            title: Text(
              cardName,
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              cardType,
              style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            splashColor: Colors.yellow.withAlpha(26),
            onTap: () {
              // On passe le nom ; la page de résultat
              // fera sa propre recherche multilingue
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      RecognitionResultPage(cardName: cardName),
                ),
              );
            },
          ),
        );
      },
    );
  }
}