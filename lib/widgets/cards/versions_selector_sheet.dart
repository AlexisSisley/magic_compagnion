// Fichier : lib/widgets/cards/versions_selector_sheet.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../models/scryfall_card_model.dart';

class VersionsSelectorSheet extends StatefulWidget {
  final String oracleId;
  final String currentCardId;
  final Function(ScryfallCard) onVersionSelected;

  const VersionsSelectorSheet({
    super.key,
    required this.oracleId,
    required this.currentCardId,
    required this.onVersionSelected,
  });

  @override
  State<VersionsSelectorSheet> createState() => _VersionsSelectorSheetState();
}

class _VersionsSelectorSheetState extends State<VersionsSelectorSheet> {
  List<ScryfallCard> _versions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPrints();
  }

  Future<void> _fetchPrints() async {
    if (widget.oracleId.isEmpty) {
      setState(() { 
        _isLoading = false; 
        _errorMessage = "Impossible de trouver les autres versions (Oracle ID manquant)."; 
      });
      return;
    }

    try {
      // API Scryfall : Cherche toutes les impressions uniques avec cet Oracle ID
      final uri = Uri.parse('https://api.scryfall.com/cards/search?q=oracle_id:${widget.oracleId}&unique=prints&order=released&dir=desc');
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> dataList = data['data'] ?? [];
        
        if (mounted) {
          setState(() {
            _versions = dataList.map((json) => ScryfallCard.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() { 
            _isLoading = false; 
            _errorMessage = "Erreur API Scryfall (${response.statusCode})"; 
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          _errorMessage = "Erreur réseau : $e"; 
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Versions & Artworks", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // Liste des versions
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage, style: GoogleFonts.cinzel(color: Colors.red)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _versions.length,
                        itemBuilder: (context, index) {
                          final card = _versions[index];
                          final bool isCurrent = card.id == widget.currentCardId;

                          return GestureDetector(
                            onTap: () {
                              widget.onVersionSelected(card);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: isCurrent ? Border.all(color: Colors.green.shade400, width: 3) : null,
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black45,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Image
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                      child: Image.network(
                                        card.imageUrl.isNotEmpty ? card.imageUrl : (card.smallImageUrl ?? ''),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_,__,___) => const Center(child: Icon(Icons.image_not_supported, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                  // Infos
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.setName,
                                          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "#${card.collectorNumber} • ${card.lang.toUpperCase()}",
                                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                                        ),
                                        const SizedBox(height: 4),
                                        // Prix
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              card.prices['eur'] != null ? "${card.prices['eur']}€" : "--",
                                              style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            if (card.prices['eur_foil'] != null)
                                              Text(
                                                "${card.prices['eur_foil']}€",
                                                style: GoogleFonts.cinzel(color: Colors.amber.shade300, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}