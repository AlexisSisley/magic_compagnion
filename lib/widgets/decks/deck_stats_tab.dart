// Fichier : lib/widgets/decks/deck_stats_tab.dart
// VERSION CORRIGÉE

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';

class DeckStatsTab extends StatefulWidget {
  final List<DeckCard> mainboard;
  final List<ScryfallCard> cardData;

  const DeckStatsTab({
    super.key,
    required this.mainboard,
    required this.cardData,
  });

  @override
  State<DeckStatsTab> createState() => _DeckStatsTabState();
}

class _DeckStatsTabState extends State<DeckStatsTab> {
  late Map<int, int> _manaCurveData;
  late Map<String, int> _cardTypeData;
  late Map<String, int> _pipCountData;
  
  final List<Color> _pieColors = [
    Colors.blue.shade700,
    Colors.red.shade700,
    Colors.green.shade700,
    Colors.grey.shade700,
    Colors.purple.shade700,
    Colors.orange.shade700,
    Colors.yellow.shade800,
  ];

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  /// Fonction principale qui lance tous les calculs
  void _calculateStats() {
    _manaCurveData = _calculateManaCurve();
    _cardTypeData = _calculateCardTypes();
    _pipCountData = _calculatePipCount();
  }

  /// Calcule le nombre de cartes pour chaque coût de mana
  Map<int, int> _calculateManaCurve() {
    Map<int, int> curve = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    
    for (final deckCard in widget.mainboard) {
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);

        if (scryfallCard.typeLine.toLowerCase().contains('land')) {
          continue;
        }

        // Utilise le champ 'cmc' qui existe maintenant
        int cmc = (scryfallCard.cmc ?? 0).toInt(); 
        
        if (cmc >= 7) {
          curve[7] = (curve[7] ?? 0) + deckCard.quantity; // Regroupe 7+
        } else {
          curve[cmc] = (curve[cmc] ?? 0) + deckCard.quantity;
        }
      } catch (e) {
        // Ignore la carte si données non trouvées
      }
    }
    return curve;
  }
  
  /// Calcule le nombre de cartes par type
  Map<String, int> _calculateCardTypes() {
    Map<String, int> types = {};
    for (final deckCard in widget.mainboard) {
      String type = "Autre";
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) {
           type = _getPrimaryType(deckCard.name);
        } else {
          final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
          type = _getPrimaryType(scryfallCard.typeLine);
        }
      } catch (e) {
         type = _getPrimaryType(deckCard.name);
      }
      
      types[type] = (types[type] ?? 0) + deckCard.quantity;
    }
    return types;
  }
  
  /// Calcule la répartition des pips de couleur
  Map<String, int> _calculatePipCount() {
    Map<String, int> pipCount = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0};
    final RegExp manaPipRegex = RegExp(r'\{([WUBRG])\}');

    for (final deckCard in widget.mainboard) {
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);

        if (scryfallCard.typeLine.toLowerCase().contains('land')) {
          continue;
        }

        final manaCost = scryfallCard.manaCost ?? '';
        final matches = manaPipRegex.allMatches(manaCost);
        for (final match in matches) {
          final pip = match.group(1);
          if (pip != null) {
            pipCount[pip] = (pipCount[pip] ?? 0) + (1 * deckCard.quantity);
          }
        }
      } catch (e) {
        // Ignore carte
      }
    }
    pipCount.removeWhere((key, value) => value == 0);
    return pipCount;
  }
  
  /// Helper copié de deck_detail_page.dart
  String _getPrimaryType(String typeLine) {
    String lowerType = typeLine.toLowerCase();
    if (!lowerType.contains(' — ') && (lowerType.contains('swamp') || lowerType.contains('plains') || lowerType.contains('island') || lowerType.contains('mountain') || lowerType.contains('forest'))) {
      return 'Terrains';
    }
    if (lowerType.contains('creature')) return 'Créatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('land')) return 'Terrains';
    if (lowerType.contains('artifact')) return 'Artefacts';
    if (lowerType.contains('enchantment')) return 'Enchantements';
    if (lowerType.contains('instant')) return 'Sorts';
    if (lowerType.contains('sorcery')) return 'Sorts';
    if (typeLine.startsWith('LOCAL:')) return 'Autres';
    return 'Autres';
  }

  /// Construit l'interface
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0).copyWith(bottom: 90.0),
      child: Column(
        children: [
          _buildStatsCard(
            title: "Courbe de Mana",
            child: _buildManaCurveChart(),
          ),
          const SizedBox(height: 16),
          _buildStatsCard(
            title: "Distribution des Types",
            child: _buildCardTypeChart(),
          ),
           const SizedBox(height: 16),
          _buildStatsCard(
            title: "Répartition des Pips",
            child: _buildPipChart(),
          ),
        ],
      ),
    );
  }

  /// Widget pour la "carte" de fond de chaque graphique
  Widget _buildStatsCard({required String title, required Widget child}) {
    return Card(
      // --- CORRECTION 'withOpacity' ---
      color: Colors.black.withAlpha((0.4 * 255).round()), 
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        // --- CORRECTION 'withOpacity' ---
        side: BorderSide(color: Colors.yellow.shade800.withAlpha((0.6 * 255).round()), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200, // Hauteur fixe pour les graphiques
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  /// Le graphique en barres pour la courbe de mana
  Widget _buildManaCurveChart() {
    if (_manaCurveData.values.every((v) => v == 0)) {
      return _buildEmptyChartState("Aucune donnée de coût de mana trouvée.");
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
           touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                 return BarTooltipItem(
                  '${rod.toY.toInt()} cartes',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
           ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                value.toInt() == 7 ? "7+" : value.toInt().toString(),
                style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12),
              ),
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: _manaCurveData.entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: Colors.yellow.shade800,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Le graphique en secteurs pour les types
  Widget _buildCardTypeChart() {
    if (_cardTypeData.isEmpty) {
      return _buildEmptyChartState("Aucune donnée de type trouvée.");
    }

    int i = 0;
    final List<PieChartSectionData> sections = _cardTypeData.entries.map((entry) {
      final color = _pieColors[i % _pieColors.length];
      i++;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 80,
        titleStyle: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        badgeWidget: Text(
          entry.key,
          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12),
        ),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();

    return PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: sections));
  }

  /// Le graphique en secteurs pour les pips
  Widget _buildPipChart() {
    if (_pipCountData.isEmpty) {
      return _buildEmptyChartState("Aucun pip de couleur trouvé (terrains exclus).");
    }

    final Map<String, Color> pipColors = {
      'W': Colors.grey.shade200,
      'U': Colors.blue.shade400,
      'B': Colors.black,
      'R': Colors.red.shade600,
      'G': Colors.green.shade600,
    };
    
    final List<PieChartSectionData> sections = _pipCountData.entries.map((entry) {
      final color = pipColors[entry.key] ?? Colors.grey;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 80,
        titleStyle: GoogleFonts.cinzel(
          color: (entry.key == 'W' || entry.key == 'U') ? Colors.black : Colors.white, 
          fontWeight: FontWeight.bold, 
          fontSize: 14
        ),
      );
    }).toList();

    return PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: sections));
  }
  
  Widget _buildEmptyChartState(String message) {
     return Center(
      child: Text(
        message,
        style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}