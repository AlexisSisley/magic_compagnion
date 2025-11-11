// Fichier : lib/widgets/decks/draw_test_simulator.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../models/deck_model.dart';

class DrawTestSimulator extends StatefulWidget {
  final List<DeckCard> mainboard;
  
  const DrawTestSimulator({super.key, required this.mainboard});

  @override
  State<DrawTestSimulator> createState() => _DrawTestSimulatorState();
}

class _DrawTestSimulatorState extends State<DrawTestSimulator> {
  late List<DeckCard> _library;
  List<DeckCard> _hand = [];
  int _mulliganCount = 0;

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
    });
  }
  
  void _drawOneCard() {
    setState(() {
      _hand.addAll(_drawCards(1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Main de départ',
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
            Expanded(
              child: _hand.isEmpty
                  ? Center(child: Text('Main vide.', style: GoogleFonts.cinzel(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: _hand.length,
                      itemBuilder: (context, index) {
                        final card = _hand[index];
                        return Card(
                          color: Colors.black.withAlpha((0.3 * 255).round()),
                          child: ListTile(
                            title: Text(
                              card.name,
                              style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _drawOneCard,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                    child: Text('Piocher 1', style: GoogleFonts.cinzel(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: _mulligan,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                    child: Text('Mulligan (${7 - _mulliganCount - 1})', style: GoogleFonts.cinzel(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: _startNewGame,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                    child: Text('Recommencer', style: GoogleFonts.cinzel(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}