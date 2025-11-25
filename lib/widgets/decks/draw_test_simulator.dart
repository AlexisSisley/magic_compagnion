// Fichier : lib/widgets/decks/draw_test_simulator.dart
// VERSION MISE À JOUR : Analyseur de Mana ajouté

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';

class DrawTestSimulator extends StatefulWidget {
  final List<DeckCard> mainboard;
  final List<ScryfallCard> fullCardData;
  
  const DrawTestSimulator({
    super.key, 
    required this.mainboard,
    required this.fullCardData,
  });

  @override
  State<DrawTestSimulator> createState() => _DrawTestSimulatorState();
}

class _DrawTestSimulatorState extends State<DrawTestSimulator> {
  late List<DeckCard> _library;
  List<DeckCard> _hand = [];
  int _mulliganCount = 0;

  // Analyse du mana
  Map<String, int> _manaSources = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      _library = List.from(widget.mainboard);
      _library.shuffle(Random());
      _hand = _drawCards(7);
      _mulliganCount = 0;
      _calculateManaStats();
    });
  }

  List<DeckCard> _drawCards(int count) {
    List<DeckCard> drawn = [];
    for (int i = 0; i < count; i++) {
      if (_library.isNotEmpty) {
        drawn.add(_library.removeAt(0));
      }
    }
    return drawn;
  }
  
  void _mulligan() {
    setState(() {
      _mulliganCount++;
      _library.addAll(_hand);
      _library.shuffle(Random());
      
      int cardsToDraw = 7 - _mulliganCount;
      if (cardsToDraw < 0) cardsToDraw = 0;
      
      _hand = _drawCards(cardsToDraw);
      _calculateManaStats();
    });
  }
  
  void _drawOneCard() {
    setState(() {
      _hand.addAll(_drawCards(1));
      _calculateManaStats();
    });
  }

  /// Analyse les terrains en main pour estimer les sources de mana
  void _calculateManaStats() {
    // Réinitialiser
    final newStats = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};

    for (final card in _hand) {
      if (card.scryfallId.startsWith('LOCAL:')) continue;

      try {
        final scryfallData = widget.fullCardData.firstWhere((s) => s.id == card.scryfallId);
        
        // On ne compte que les Terrains pour l'instant (approximation fiable)
        if (scryfallData.typeLine.toLowerCase().contains('land')) {
          if (scryfallData.colorIdentity.isEmpty) {
             // Terrain incolore (ex: Reliquary Tower)
             newStats['C'] = (newStats['C'] ?? 0) + 1;
          } else {
            // Ajoute 1 à chaque couleur que le terrain peut produire
            // (C'est une estimation basée sur l'identité couleur)
            for (final color in scryfallData.colorIdentity) {
              if (newStats.containsKey(color)) {
                newStats[color] = (newStats[color] ?? 0) + 1;
              }
            }
          }
        }
      } catch (e) {
        // Ignorer si données manquantes
      }
    }

    setState(() {
      _manaSources = newStats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withAlpha((0.98 * 255).round()),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Simulateur de Main',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Biblio: ${_library.length} | Main: ${_hand.length}',
                    style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            
            // --- Analyseur de Mana (NOUVEAU) ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("Sources disponibles :", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  _buildManaIndicator('W', _manaSources['W'] ?? 0),
                  _buildManaIndicator('U', _manaSources['U'] ?? 0),
                  _buildManaIndicator('B', _manaSources['B'] ?? 0),
                  _buildManaIndicator('R', _manaSources['R'] ?? 0),
                  _buildManaIndicator('G', _manaSources['G'] ?? 0),
                  _buildManaIndicator('C', _manaSources['C'] ?? 0),
                ],
              ),
            ),

            // --- Liste des cartes ---
            Expanded(
              child: _hand.isEmpty
                  ? Center(child: Text('Main vide.', style: GoogleFonts.cinzel(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: _hand.length,
                      itemBuilder: (context, index) {
                        final card = _hand[index];
                        
                        String? smallImageUrl;
                        String typeLine = "";
                        try {
                          final scryfallCard = widget.fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
                          if (!scryfallCard.id.startsWith('LOCAL:')) {
                            smallImageUrl = scryfallCard.smallImageUrl;
                            typeLine = scryfallCard.typeLine;
                          }
                        } catch (e) { /* fallback */ }

                        // Indication visuelle si c'est un terrain (pour aider à comprendre l'analyse)
                        final bool isLand = typeLine.toLowerCase().contains('land');

                        return Card(
                          color: isLand ? Colors.brown.shade900.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(3.0),
                              child: (smallImageUrl != null)
                                  ? Image.network(
                                      smallImageUrl,
                                      width: 35, 
                                      height: 49, // Ratio magic
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, e, s) => const Icon(Icons.image_not_supported, size: 30),
                                    )
                                  : Container(
                                      width: 35, height: 49,
                                      color: Colors.grey.shade800,
                                      child: const Icon(Icons.image_not_supported, color: Colors.white30, size: 24),
                                    ),
                            ),
                            title: Text(
                              card.name,
                              style: GoogleFonts.cinzel(color: isLand ? Colors.amber.shade100 : Colors.white, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: isLand 
                              ? const Text("Terrain", style: TextStyle(color: Colors.white38, fontSize: 10)) 
                              : null,
                            dense: true,
                          ),
                        );
                      },
                    ),
            ),
            
            // --- Contrôles ---
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: _drawOneCard,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                    label: Text('Piocher 1', style: GoogleFonts.cinzel(color: Colors.white)),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    onPressed: _mulligan,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                    label: Text('Mulligan (${7 - _mulliganCount - 1})', style: GoogleFonts.cinzel(color: Colors.white)),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 16),
                    onPressed: _startNewGame,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                    label: Text('Reset', style: GoogleFonts.cinzel(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManaIndicator(String symbol, int count) {
    // Si count est 0, on affiche en gris très foncé pour montrer que c'est manquant
    final double opacity = count > 0 ? 1.0 : 0.3;
    final String cleanSymbol = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    
    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.network(
            'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg',
            width: 16, height: 16,
            placeholderBuilder: (_) => Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(height: 2),
          Text(
            "$count",
            style: TextStyle(
              color: count > 0 ? Colors.white : Colors.grey, 
              fontWeight: FontWeight.bold, 
              fontSize: 12
            ),
          ),
        ],
      ),
    );
  }
}