// Fichier : lib/widgets/decks/deck_stats_tab.dart
// VERSION MISE À JOUR : Répartition Couleurs par Type (Stacked Bar Chart)

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';

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
  // Données existantes
  late Map<int, int> _manaCurveData;
  late Map<String, int> _cardTypeData;
  late Map<String, int> _pipCountData; 
  late Map<String, int> _sourceCountData; 
  
  // --- NOUVELLE DONNÉE ---
  // Structure: { "Creatures": { "G": 10, "R": 5 }, "Instants": { "U": 4 } ... }
  late Map<String, Map<String, int>> _colorByTypeData; 

  final List<Color> _pieColors = [
    Colors.blue.shade700, Colors.red.shade700, Colors.green.shade700,
    Colors.grey.shade700, Colors.purple.shade700, Colors.orange.shade700, AppColors.primaryShade800,
  ];

  final Map<String, Color> _manaColors = {
      'W': const Color(0xFFF0F2C0), 
      'U': const Color(0xFF4287f5), 
      'B': const Color(0xFF333333), 
      'R': const Color(0xFFeb4034), 
      'G': const Color(0xFF4caf50), 
      'C': const Color(0xFF9e9e9e), 
      'M': const Color(0xFFD4AF37), // Or pour Multicolore
  };

  // Ordre d'affichage des segments dans la barre (du bas vers le haut)
  final List<String> _colorOrder = ['W', 'U', 'B', 'R', 'G', 'C', 'M'];

  double _averageCmc = 0.0;
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }
  
  void _calculateStats() {
    _manaCurveData = _calculateManaCurve();
    _cardTypeData = _calculateCardTypes();
    _pipCountData = _calculatePipCount();
    _sourceCountData = _calculateLandSources();
    
    // --- NOUVEAU CALCUL ---
    _colorByTypeData = _calculateColorByType();

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

  // --- NOUVEAU CALCUL : COULEUR PAR TYPE ---
  Map<String, Map<String, int>> _calculateColorByType() {
    Map<String, Map<String, int>> data = {};

    for (final deckCard in widget.mainboard) {
      String type = 'Autres';
      List<String> colors = [];
      
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) {
           type = _getPrimaryType(deckCard.name);
           colors = []; // Local = Incolore par défaut ou à déduire
        } else {
          final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
          type = _getPrimaryType(scryfallCard.typeLine);
          colors = scryfallCard.colorIdentity; // Ou scryfallCard.colors si dispo dans le modèle
        }
      } catch (e) { type = _getPrimaryType(deckCard.name); }

      // Détermination de la catégorie de couleur
      String colorKey = 'C';
      if (colors.isEmpty) {
        colorKey = 'C';
      } else if (colors.length > 1) {
        colorKey = 'M'; // Multicolore
      } else {
        colorKey = colors.first;
      }

      data.putIfAbsent(type, () => {});
      data[type]![colorKey] = (data[type]![colorKey] ?? 0) + deckCard.quantity;
    }
    
    // Nettoyage des types vides
    data.removeWhere((key, value) => value.isEmpty);
    return data;
  }

  // --- ANCIENS CALCULS (Inchangés) ---
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
      } catch (e) { /* Card not found in data */ }
    }
    return curve;
  }
  
  Map<String, int> _calculateCardTypes() {
    Map<String, int> types = {};
    for (final deckCard in widget.mainboard) {
      String type = 'Autres';
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
      } catch (e) { /* Card not found in data */ }
    }
    pipCount.removeWhere((key, value) => value == 0);
    return pipCount;
  }

  Map<String, int> _calculateLandSources() {
    Map<String, int> sources = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
    for (final deckCard in widget.mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      try {
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
        if (scryfallCard.typeLine.toLowerCase().contains('land')) {
           if (scryfallCard.colorIdentity.isEmpty) {
             sources['C'] = (sources['C'] ?? 0) + deckCard.quantity;
           } else {
             for (var color in scryfallCard.colorIdentity) {
               if (sources.containsKey(color)) {
                 sources[color] = (sources[color] ?? 0) + deckCard.quantity;
               }
             }
           }
        } else if (scryfallCard.typeLine.toLowerCase().contains('artifact') && (scryfallCard.name.contains('Signet') || scryfallCard.name.contains('Sol Ring') || scryfallCard.name.contains('Arcane Signet'))) {
           if (scryfallCard.name.contains('Sol Ring')) sources['C'] = (sources['C'] ?? 0) + deckCard.quantity;
        }
      } catch (e) { /* Card not found in data */ }
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
    if (lowerType.contains('instant')) return 'Instant';
    if (lowerType.contains('sorcery')) return 'Rituels';
    if (lowerType.contains('battle')) return 'Batailles';
    return 'Autres';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0).copyWith(bottom: 90.0),
      child: Column(
        children: [
          _buildStatsCard(
            title: 'Balance des Couleurs',
            subtitle: 'Dévotion (Symboles) vs Sources (Terrains)',
            height: 300,
            child: _buildRadarChart(),
          ),
          const SizedBox(height: 16),
          
          _buildStatsCard(
            title: 'Courbe de Mana',
            height: 200,
            child: _buildManaCurveChart(), // Existant
          ),
          _buildSummaryCard(),
          const SizedBox(height: 16),
          
          _buildStatsCard(
            title: 'Analyseur de Mana',
            subtitle: 'Comparaison : Pips (Besoins) vs Terrains (Sources)',
            child: _buildManaAnalysisChart(),
            height: 250,
          ),
          
          const SizedBox(height: 16),
          
          // --- NOUVEAU GRAPHIQUE ---
          _buildStatsCard(
            title: 'Couleurs par Type',
            subtitle: 'Répartition des couleurs pour chaque type de carte',
            child: _buildColorByTypeChart(),
            height: 250,
          ),

          const SizedBox(height: 16),
          _buildStatsCard(
            title: 'Courbe de Mana',
            child: _buildManaCurveChart(),
            height: 200,
          ),
          const SizedBox(height: 16),
          _buildStatsCard(
            title: 'Types de Cartes',
            child: _buildCardTypeChart(),
            height: 300, 
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---
  Widget _buildRadarChart() {
    final colors = ['W', 'U', 'B', 'R', 'G'];
    // Normalisation pour que le radar soit lisible (max value = 100%)
    double maxVal = 1.0;
    
    // Trouver le max pour normaliser
    for(var c in colors) {
      if ((_pipCountData[c]??0) > maxVal) maxVal = (_pipCountData[c]??0).toDouble();
      if ((_sourceCountData[c]??0) > maxVal) maxVal = (_sourceCountData[c]??0).toDouble();
    }

    return RadarChart(
      RadarChartData(
        dataSets: [
          // Dataset 1 : Pips (Besoins)
          RadarDataSet(
            fillColor: AppColors.accentOrange.withValues(alpha: 0.2),
            borderColor: AppColors.accentOrange,
            entryRadius: 3,
            dataEntries: colors.map((c) => RadarEntry(value: (_pipCountData[c]??0).toDouble())).toList(),
            borderWidth: 2,
          ),
          // Dataset 2 : Sources (Terrains)
          RadarDataSet(
            fillColor: AppColors.accent.withValues(alpha: 0.2),
            borderColor: AppColors.accent,
            entryRadius: 3,
            dataEntries: colors.map((c) => RadarEntry(value: (_sourceCountData[c]??0).toDouble())).toList(),
            borderWidth: 2,
          ),
        ],
        radarBackgroundColor: AppColors.transparent,
        borderData: FlBorderData(show: false),
        radarBorderData: const BorderSide(color: AppColors.borderSubtle),
        titlePositionPercentageOffset: 0.1,
        titleTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
        getTitle: (index, angle) {
          if (index >= colors.length) return const RadarChartTitle(text: '');
          return RadarChartTitle(text: colors[index]); // Affiche W, U, B...
        },
        tickCount: 3,
        ticksTextStyle: const TextStyle(color: AppColors.transparent),
        tickBorderData: const BorderSide(color: AppColors.borderLight),
        gridBorderData: const BorderSide(color: AppColors.borderMedium, width: 1),
      ),
      swapAnimationDuration: const Duration(milliseconds: 400),
    );
  }
  
  Widget _buildSummaryCard() {
    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: AppColors.primaryShade800.withValues(alpha: 0.6))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('CMC Moyen', _averageCmc.toStringAsFixed(2)),
            Container(width: 1, height: 40, color: AppColors.borderMedium),
            _buildSummaryItem('Prix Est.', '${_totalPrice.toStringAsFixed(2)} €'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.subtitle()),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.pageTitle(fontSize: 20)),
      ],
    );
  }

  Widget _buildStatsCard({required String title, String? subtitle, required Widget child, required double height}) {
    return Card(
      color: AppColors.textOnPrimary.withAlpha((0.4 * 255).round()), 
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: AppColors.primaryShade800.withAlpha((0.6 * 255).round()), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.pageTitle(fontSize: 20)),
            if (subtitle != null) 
               Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 24),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }

  // --- NOUVEAU GRAPHIQUE STACKED ---
  Widget _buildColorByTypeChart() {
    if (_colorByTypeData.isEmpty) return _buildEmptyChartState('Pas assez de données.');

    final types = _colorByTypeData.keys.toList()..sort();
    
    // Trouver la valeur Y max (la somme max d'une colonne)
    double maxY = 0;
    for (var type in types) {
      double sum = 0;
      _colorByTypeData[type]!.forEach((_, v) => sum += v);
      if (sum > maxY) maxY = sum;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.1, // Marge en haut
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.borderLight, strokeWidth: 1)
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= types.length) return const SizedBox();
                // Affiche les 3 premières lettres du type (ex: CRE, INS, LAN)
                String label = types[index];
                if (label.length > 4) label = label.substring(0, 4); 
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(types.length, (index) {
          final type = types[index];
          final colorCounts = _colorByTypeData[type]!;
          
          // Création des segments empilés (Rods)
          List<BarChartRodStackItem> rodStackItems = [];
          double currentY = 0;

          // On empile dans un ordre précis pour que les couleurs soient toujours au même endroit
          for (var colorKey in _colorOrder) {
            final count = colorCounts[colorKey] ?? 0;
            if (count > 0) {
              rodStackItems.add(
                BarChartRodStackItem(currentY, currentY + count, _manaColors[colorKey]!)
              );
              currentY += count;
            }
          }

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: currentY,
                rodStackItems: rodStackItems,
                width: 20,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          );
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final type = types[group.x];
              // On retrouve la couleur touchée (c'est un peu tricky avec fl_chart stacked)
              // Pour simplifier, on affiche le total du type
              int total = _colorByTypeData[type]!.values.fold(0, (a, b) => a + b);
              return BarTooltipItem(
                '$type\nTotal: $total',
                const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildManaAnalysisChart() {
    final colors = ['W', 'U', 'B', 'R', 'G', 'C'];
    final List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    
    for (int i = 0; i < colors.length; i++) {
      final colorKey = colors[i];
      final needs = _pipCountData[colorKey]?.toDouble() ?? 0;
      final sources = _sourceCountData[colorKey]?.toDouble() ?? 0;
      if (needs == 0 && sources == 0) continue;
      if (needs > maxY) maxY = needs;
      if (sources > maxY) maxY = sources;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: needs,
              color: _manaColors[colorKey]!.withValues(alpha: 0.3),
              width: 12, borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(color: _manaColors[colorKey]!, width: 1)
            ),
            BarChartRodData(
              toY: sources,
              color: _manaColors[colorKey]!,
              width: 12, borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    if (barGroups.isEmpty) return _buildEmptyChartState('Pas assez de données de mana.');

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.1,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.borderLight, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < colors.length) {
                  final c = colors[index];
                  if ((_pipCountData[c] ?? 0) == 0 && (_sourceCountData[c] ?? 0) == 0) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(c, style: AppTextStyles.bold(color: _manaColors[c])));
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
              final isSource = rodIndex == 1; 
              return BarTooltipItem(
                isSource ? 'Sources: ${rod.toY.toInt()}' : 'Pips: ${rod.toY.toInt()}',
                TextStyle(color: _manaColors[colorKey], fontWeight: FontWeight.bold)
              );
            }
          )
        )
      ),
    );
  }

  Widget _buildManaCurveChart() {
    if (_manaCurveData.values.every((v) => v == 0)) return _buildEmptyChartState('Aucune donnée.');
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
           touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${rod.toY.toInt()} cartes', const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
           ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(v.toInt() == 7 ? '7+' : v.toInt().toString(), style: AppTextStyles.label(color: AppColors.textSecondary)), reservedSize: 30),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: _manaCurveData.entries.map((entry) {
          return BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: entry.value.toDouble(), color: AppColors.primaryShade800, width: 16, borderRadius: BorderRadius.circular(4))]);
        }).toList(),
      ),
    );
  }

  Widget _buildCardTypeChart() {
    if (_cardTypeData.isEmpty) return _buildEmptyChartState('Aucune donnée.');
    final double totalCount = _cardTypeData.values.fold(0, (a, b) => a + b).toDouble();
    int i = 0;
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];
    final sortedEntries = _cardTypeData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      final color = _pieColors[i % _pieColors.length];
      final percentage = (entry.value / totalCount) * 100;
      sections.add(PieChartSectionData(color: color, value: entry.value.toDouble(), title: '${percentage.toStringAsFixed(0)}%', radius: 80, titleStyle: AppTextStyles.bold()));
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
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, color: color), const SizedBox(width: 8), Text('$text ($count)', style: AppTextStyles.body())]);
  }
  
  Widget _buildEmptyChartState(String message) {
     return Center(child: Text(message, style: AppTextStyles.subtitle(), textAlign: TextAlign.center));
  }
}
