// Fichier : lib/widgets/decks/deck_stats_tab.dart
// VERSION MISE À JOUR : Analyseur de Mana (Sources vs Besoins)

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
  late Map<String, int> _pipCountData; // Besoins
  late Map<String, int> _sourceCountData; // Sources (Terrains)

  final List<Color> _pieColors = [
    Colors.blue.shade700,
    Colors.red.shade700,
    Colors.green.shade700,
    Colors.grey.shade700,
    Colors.purple.shade700,
    Colors.orange.shade700,
    Colors.yellow.shade800,
  ];

  final Map<String, Color> _manaColors = {
      'W': const Color(0xFFF0F2C0), // Blanc crème
      'U': const Color(0xFF4287f5), // Bleu
      'B': const Color(0xFF333333), // Noir (Gris foncé pour visibilité)
      'R': const Color(0xFFeb4034), // Rouge
      'G': const Color(0xFF4caf50), // Vert
      'C': const Color(0xFF9e9e9e), // Incolore
    };

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }
  
  double _averageCmc = 0.0;
  double _totalPrice = 0.0;

  void _calculateStats() {
    _manaCurveData = _calculateManaCurve();
    _cardTypeData = _calculateCardTypes();
    _pipCountData = _calculatePipCount();
    _sourceCountData = _calculateLandSources(); // Calcul des sources

    double totalCmc = 0;
    int totalNonLandCards = 0;
    double tempPrice = 0;

    for (final deckCard in widget.mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      try {
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
        final String? priceStr = scryfallCard.prices['eur'];
        if (priceStr != null) {
          tempPrice += (double.tryParse(priceStr) ?? 0) * deckCard.quantity;
        }
        if (!scryfallCard.typeLine.toLowerCase().contains('land')) {
           totalCmc += (scryfallCard.cmc ?? 0) * deckCard.quantity;
           totalNonLandCards += deckCard.quantity;
        }
      } catch (e) { /* ignore */ }
    }

    _totalPrice = tempPrice;
    _averageCmc = totalNonLandCards > 0 ? totalCmc / totalNonLandCards : 0.0;
  }

  // --- CALCULS EXISTANTS ---
  Map<int, int> _calculateManaCurve() {
    Map<int, int> curve = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final deckCard in widget.mainboard) {
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
        if (scryfallCard.typeLine.toLowerCase().contains('land')) continue;
        int cmc = (scryfallCard.cmc ?? 0).toInt(); 
        if (cmc >= 7) {
          curve[7] = (curve[7] ?? 0) + deckCard.quantity;
        } else {
          curve[cmc] = (curve[cmc] ?? 0) + deckCard.quantity;
        }
      } catch (e) { }
    }
    return curve;
  }
  
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
      } catch (e) { type = _getPrimaryType(deckCard.name); }
      types[type] = (types[type] ?? 0) + deckCard.quantity;
    }
    return types;
  }
  
  Map<String, int> _calculatePipCount() {
    Map<String, int> pipCount = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0};
    final RegExp manaPipRegex = RegExp(r'\{([WUBRG])\}');
    for (final deckCard in widget.mainboard) {
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
        if (scryfallCard.typeLine.toLowerCase().contains('land')) continue;
        final manaCost = scryfallCard.manaCost ?? '';
        final matches = manaPipRegex.allMatches(manaCost);
        for (final match in matches) {
          final pip = match.group(1);
          if (pip != null) {
            pipCount[pip] = (pipCount[pip] ?? 0) + (1 * deckCard.quantity);
          }
        }
      } catch (e) { }
    }
    pipCount.removeWhere((key, value) => value == 0);
    return pipCount;
  }

  // --- NOUVEAU CALCUL : SOURCES DE MANA ---
  Map<String, int> _calculateLandSources() {
    Map<String, int> sources = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
    for (final deckCard in widget.mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      try {
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
        if (scryfallCard.typeLine.toLowerCase().contains('land')) {
           if (scryfallCard.colorIdentity.isEmpty) {
             // Terrain produisant de l'incolore (approximation)
             sources['C'] = (sources['C'] ?? 0) + deckCard.quantity;
           } else {
             // Terrain coloré
             for (var color in scryfallCard.colorIdentity) {
               if (sources.containsKey(color)) {
                 sources[color] = (sources[color] ?? 0) + deckCard.quantity;
               }
             }
           }
        } else if (scryfallCard.typeLine.toLowerCase().contains('artifact') && (scryfallCard.oracleId == '56db0954-55e5-469f-9e39-034105eb3e96' || scryfallCard.name.contains('Signet') || scryfallCard.name.contains('Sol Ring'))) {
           // Bonus: Ajout simple des Artefacts à mana connus (Sol Ring, Signets...)
           // Pour une app parfaite, il faudrait parser le texte, mais c'est complexe.
           // Ici on compte juste Sol Ring comme source incolore
           if (scryfallCard.name.contains('Sol Ring')) sources['C'] = (sources['C'] ?? 0) + deckCard.quantity;
        }
      } catch (e) { }
    }
    sources.removeWhere((key, value) => value == 0);
    return sources;
  }
  
  String _getPrimaryType(String typeLine) {
    String lowerType = typeLine.toLowerCase();
    if (!lowerType.contains(' — ') && (lowerType.contains('swamp') || lowerType.contains('plains') || lowerType.contains('island') || lowerType.contains('mountain') || lowerType.contains('forest'))) return 'Terrains';
    if (lowerType.contains('creature')) return 'Créatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('land')) return 'Terrains';
    if (lowerType.contains('artifact')) return 'Artefacts';
    if (lowerType.contains('enchantment')) return 'Enchantements';
    if (lowerType.contains('instant')) return 'Sorts';
    if (lowerType.contains('sorcery')) return 'Sorts';
    return 'Autres';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0).copyWith(bottom: 90.0),
      child: Column(
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          
          _buildStatsCard(
            title: "Analyseur de Mana",
            subtitle: "Comparaison : Pips (Besoins) vs Terrains (Sources)",
            child: _buildManaAnalysisChart(),
            height: 250,
          ),
          
          const SizedBox(height: 16),
          _buildStatsCard(
            title: "Courbe de Mana",
            child: _buildManaCurveChart(),
            height: 200,
          ),
          const SizedBox(height: 16),
          _buildStatsCard(
            title: "Types de Cartes",
            child: _buildCardTypeChart(),
            height: 300, 
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.yellow.shade800.withOpacity(0.6))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem("CMC Moyen", _averageCmc.toStringAsFixed(2)),
            Container(width: 1, height: 40, color: Colors.white24),
            _buildSummaryItem("Prix Est.", "${_totalPrice.toStringAsFixed(2)} €"),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatsCard({required String title, String? subtitle, required Widget child, required double height}) {
    return Card(
      color: Colors.black.withAlpha((0.4 * 255).round()), 
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.yellow.shade800.withAlpha((0.6 * 255).round()), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            if (subtitle != null) 
               Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 24),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }

  // --- NOUVEAU GRAPHIQUE : ANALYSEUR DE MANA ---
  Widget _buildManaAnalysisChart() {
    final colors = ['W', 'U', 'B', 'R', 'G', 'C'];
    final List<BarChartGroupData> barGroups = [];
    
    // Trouve la valeur max pour l'échelle
    double maxY = 0;
    
    for (int i = 0; i < colors.length; i++) {
      final colorKey = colors[i];
      final needs = _pipCountData[colorKey]?.toDouble() ?? 0;
      final sources = _sourceCountData[colorKey]?.toDouble() ?? 0;
      
      if (needs == 0 && sources == 0) continue; // On n'affiche pas les couleurs inutilisées
      
      if (needs > maxY) maxY = needs;
      if (sources > maxY) maxY = sources;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            // Barre 1 : Besoins (Pips) - Transparente ou Hachurée
            BarChartRodData(
              toY: needs,
              color: _manaColors[colorKey]!.withOpacity(0.3),
              width: 12,
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(color: _manaColors[colorKey]!, width: 1)
            ),
            // Barre 2 : Sources (Terrains) - Pleine
            BarChartRodData(
              toY: sources,
              color: _manaColors[colorKey]!,
              width: 12,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    if (barGroups.isEmpty) return _buildEmptyChartState("Pas assez de données de mana.");

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.1,
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false, 
          getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1)
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < colors.length) {
                  final c = colors[index];
                  if ((_pipCountData[c] ?? 0) == 0 && (_sourceCountData[c] ?? 0) == 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(c, style: GoogleFonts.cinzel(color: _manaColors[c], fontWeight: FontWeight.bold)),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        barGroups: barGroups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final colorKey = colors[group.x];
              final isSource = rodIndex == 1; // 2ème barre
              return BarTooltipItem(
                isSource ? "Sources: ${rod.toY.toInt()}" : "Pips: ${rod.toY.toInt()}",
                TextStyle(color: _manaColors[colorKey], fontWeight: FontWeight.bold)
              );
            }
          )
        )
      ),
    );
  }

  // --- GRAPHIQUES EXISTANTS ---
  Widget _buildManaCurveChart() {
    if (_manaCurveData.values.every((v) => v == 0)) return _buildEmptyChartState("Aucune donnée.");
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
           touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${rod.toY.toInt()} cartes', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
           ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(v.toInt() == 7 ? "7+" : v.toInt().toString(), style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)), reservedSize: 30),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: _manaCurveData.entries.map((entry) {
          return BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: entry.value.toDouble(), color: Colors.yellow.shade800, width: 16, borderRadius: BorderRadius.circular(4))]);
        }).toList(),
      ),
    );
  }

  Widget _buildCardTypeChart() {
    if (_cardTypeData.isEmpty) return _buildEmptyChartState("Aucune donnée.");
    final double totalCount = _cardTypeData.values.fold(0, (a, b) => a + b).toDouble();
    int i = 0;
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];
    final sortedEntries = _cardTypeData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      final color = _pieColors[i % _pieColors.length];
      final percentage = (entry.value / totalCount) * 100;
      sections.add(PieChartSectionData(color: color, value: entry.value.toDouble(), title: '${percentage.toStringAsFixed(0)}%', radius: 80, titleStyle: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)));
      legendItems.add(_buildLegendItem(color, entry.key, entry.value));
      i++;
    }
    return Column(
      children: [
        Expanded(child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: sections))),
        const SizedBox(height: 24),
        Wrap(spacing: 16.0, runSpacing: 8.0, alignment: WrapAlignment.center, children: legendItems),
      ],
    );
  }
  
  Widget _buildLegendItem(Color color, String text, int count) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, color: color), const SizedBox(width: 8), Text('$text ($count)', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14))]);
  }
  
  Widget _buildEmptyChartState(String message) {
     return Center(child: Text(message, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center));
  }
}