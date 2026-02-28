// Fichier : lib/widgets/decks/deck_share_preview.dart
// VERSION MISE À JOUR : Icônes Mana SVG

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // <--- Import ajouté
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../cards/scryfall_image.dart';

class DeckSharePreview extends StatelessWidget {
  final Deck deck;
  final List<ScryfallCard> fullCardData;
  final double totalPrice;

  const DeckSharePreview({
    super.key,
    required this.deck,
    required this.fullCardData,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    // Récupération image commandant
    String? cmdImageUrl;
    String cmdName = "Deck sans Commandant";
    if (deck.commanderScryfallId != null) {
      try {
        final cmd = fullCardData.firstWhere((c) => c.id == deck.commanderScryfallId);
        cmdImageUrl = cmd.artCropUrl ?? (cmd.imageUrl.isNotEmpty ? cmd.imageUrl : cmd.smallImageUrl);
        cmdName = cmd.name;
      } catch (e) { /* */ }
    } else if (deck.mainboard.isNotEmpty) {
       try {
         final first = fullCardData.firstWhere((c) => c.id == deck.mainboard.first.scryfallId);
         cmdImageUrl = first.imageUrl;
         cmdName = deck.name;
       } catch (e) { /* */ }
    }

    int creatureCount = 0;
    int landCount = 0;
    
    // Courbe de mana simplifiée
    Map<int, int> curve = {0:0, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};

    for (var deckCard in deck.mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      try {
        final card = fullCardData.firstWhere((c) => c.id == deckCard.scryfallId);
        final type = card.typeLine.toLowerCase();
        
        if (type.contains('land')) landCount += deckCard.quantity;
        else {
          if (type.contains('creature')) creatureCount += deckCard.quantity;
          
          int cmc = (card.cmc ?? 0).toInt();
          if (cmc >= 7) curve[7] = (curve[7] ?? 0) + deckCard.quantity;
          else curve[cmc] = (curve[cmc] ?? 0) + deckCard.quantity;
        }
      } catch (e) { /* */ }
    }

    return Container(
      width: 400, // Largeur fixe pour l'export
      color: const Color(0xFF121212),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- HEADER (Image + Titre) ---
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ScryfallImage(imageUrl: cmdImageUrl, alignment: Alignment.topCenter),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xFF121212)],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16, left: 16, right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deck.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [const Shadow(color: Colors.black, blurRadius: 10)])),
                      Text(cmdName, style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontSize: 14, fontWeight: FontWeight.bold, shadows: [const Shadow(color: Colors.black, blurRadius: 4)])),
                    ],
                  ),
                ),
                // --- INDICATEURS MANA (MODIFIÉ ICI) ---
                Positioned(
                  top: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: deck.colors.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SvgPicture.network(
                          'https://svgs.scryfall.io/card-symbols/$c.svg',
                          width: 20, 
                          height: 20,
                          placeholderBuilder: (context) => Text(c, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )).toList(),
                    ),
                  ),
                )
              ],
            ),
          ),

          // --- STATS ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.style, "${deck.mainboard.fold(0, (s,c)=>s+c.quantity)}", "Cartes"),
                _buildStatItem(Icons.euro, totalPrice.toStringAsFixed(0), "Est. Prix"),
                _buildStatItem(Icons.pets, "$creatureCount", "Créatures"),
                _buildStatItem(Icons.landscape, "$landCount", "Terrains"),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // --- MANA CURVE ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: SizedBox(
              height: 100,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt() == 7 ? "7+" : "${val.toInt()}",
                          style: const TextStyle(color: Colors.white54, fontSize: 10)
                        ),
                      ),
                    ),
                  ),
                  barGroups: curve.entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(toY: e.value.toDouble(), color: Colors.blueAccent, width: 8, borderRadius: BorderRadius.circular(2))
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          
          // --- FOOTER ---
          Container(
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            color: Colors.white.withOpacity(0.05),
            child: Text("Généré par Magic Companion", style: GoogleFonts.cinzel(color: Colors.white30, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10)),
      ],
    );
  }
}