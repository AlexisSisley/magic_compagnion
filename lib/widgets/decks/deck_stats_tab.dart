// Fichier : lib/widgets/decks/deck_stats_tab.dart
// VERSION AMÉLIORÉE (Design des graphiques)

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
  
  // --- MODIFICATION : Ces couleurs sont maintenant aussi pour la légende
  final List<Color> _pieColors = [
    Colors.blue.shade700,
    Colors.red.shade700,
    Colors.green.shade700,
    Colors.grey.shade700,
    Colors.purple.shade700,
    Colors.orange.shade700,
    Colors.yellow.shade800,
  ];

  // --- MODIFICATION : Couleurs pour le nouveau graphique des pips
  final Map<String, Color> _pipColors = {
      'W': Colors.grey.shade200,
      'U': Colors.blue.shade400,
      'B': Colors.grey.shade800, // Un gris foncé, plus visible que le noir pur
      'R': Colors.red.shade600,
      'G': Colors.green.shade600,
    };

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

  // ... (Les fonctions _calculateManaCurve, _calculateCardTypes, _calculatePipCount, _getPrimaryType sont INCHANGÉES) ...
  
  Map<int, int> _calculateManaCurve() {
    Map<int, int> curve = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final deckCard in widget.mainboard) {
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
        final scryfallCard = widget.cardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
        if (scryfallCard.typeLine.toLowerCase().contains('land')) {
          continue;
        }
        int cmc = (scryfallCard.cmc ?? 0).toInt(); 
        if (cmc >= 7) {
          curve[7] = (curve[7] ?? 0) + deckCard.quantity;
        } else {
          curve[cmc] = (curve[cmc] ?? 0) + deckCard.quantity;
        }
      } catch (e) {
        // Ignore
      }
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
      } catch (e) {
         type = _getPrimaryType(deckCard.name);
      }
      
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
        // Ignore
      }
    }
    pipCount.removeWhere((key, value) => value == 0);
    return pipCount;
  }
  
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
            // --- MODIFICATION : Hauteur fixe pour les graphiques
            height: 200,
          ),
          const SizedBox(height: 16),
          _buildStatsCard(
            title: "Distribution des Types",
            child: _buildCardTypeChart(),
            // --- MODIFICATION : Augmentation de la hauteur pour la légende
            height: 300, 
          ),
           const SizedBox(height: 16),
          _buildStatsCard(
            title: "Répartition des Pips",
            child: _buildPipChart(),
            // --- MODIFICATION : Hauteur fixe pour les graphiques
            height: 200,
          ),
        ],
      ),
    );
  }

  /// Widget pour la "carte" de fond de chaque graphique
  Widget _buildStatsCard({
    required String title, 
    required Widget child,
    required double height, // --- MODIFICATION : Ajout d'une hauteur
  }) {
    return Card(
      color: Colors.black.withAlpha((0.4 * 255).round()), 
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
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
              height: height, // --- MODIFICATION : Hauteur utilisée ici
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  /// Le graphique en barres pour la courbe de mana (INCHANGÉ)
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

  /// --- MODIFICATION : Le graphique en secteurs pour les types (avec légende) ---
  Widget _buildCardTypeChart() {
    if (_cardTypeData.isEmpty) {
      return _buildEmptyChartState("Aucune donnée de type trouvée.");
    }

    final double totalCount = _cardTypeData.values.fold(0, (a, b) => a + b).toDouble();
    
    int i = 0;
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];

    // On trie pour avoir la plus grosse part en premier
    final sortedEntries = _cardTypeData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      final color = _pieColors[i % _pieColors.length];
      final percentage = (entry.value / totalCount) * 100;
      
      // 1. Créer la section du camembert
      sections.add(PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        // Affiche le pourcentage à l'intérieur
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 80,
        titleStyle: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        // Fini les 'badgeWidget' !
      ));
      
      // 2. Créer l'item de légende correspondant
      legendItems.add(_buildLegendItem(color, entry.key, entry.value));
      
      i++;
    }

    // 3. Retourner le graphique ET la légende
    return Column(
      children: [
        // Le graphique (prend l'espace dispo)
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2, 
              centerSpaceRadius: 40, 
              sections: sections
            )
          ),
        ),
        const SizedBox(height: 24),
        // La légende (s'adapte au contenu)
        Wrap(
          spacing: 16.0, // Espace horizontal
          runSpacing: 8.0, // Espace vertical
          alignment: WrapAlignment.center,
          children: legendItems,
        ),
      ],
    );
  }
  
  /// --- NOUVEAU HELPER : Construit un item de légende ---
  Widget _buildLegendItem(Color color, String text, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Pour que le Row soit juste assez large
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          '$text ($count)',
          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }


  /// --- MODIFICATION : Le graphique en barres pour les pips ---
  Widget _buildPipChart() {
    if (_pipCountData.isEmpty) {
      return _buildEmptyChartState("Aucun pip de couleur trouvé (terrains exclus).");
    }

    // Calculer la hauteur max pour le graphique
    final double maxY = _pipCountData.values.fold(0.0, (max, v) => v > max ? v.toDouble() : max);

    int i = 0;
    final List<BarChartGroupData> barGroups = [];
    
    // On itère sur les pips pour créer les barres
    for (final entry in _pipCountData.entries) {
      barGroups.add(
        BarChartGroupData(
          x: i, // Position sur l'axe X (0, 1, 2...)
          barRods: [
            BarChartRodData(
              toY: entry.value.toDouble(),
              color: _pipColors[entry.key] ?? Colors.grey, // Couleur de la barre
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
      i++;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2, // Laisse un peu d'espace en haut
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        
        // --- Tooltip au survol ---
        barTouchData: BarTouchData(
           touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                 final String key = _pipCountData.keys.elementAt(group.x);
                 return BarTooltipItem(
                  '$key: ${rod.toY.toInt()}',
                  TextStyle(color: _pipColors[key] ?? Colors.white, fontWeight: FontWeight.bold),
                );
              },
           ),
        ),
        
        // --- Axes ---
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          
          // --- Axe X (les lettres W, U, B...) ---
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                // 'value' est l'index (0, 1, 2...)
                final int index = value.toInt();
                if (index < 0 || index >= _pipCountData.length) {
                  return const SizedBox();
                }
                // Récupère la clé ("W", "U"...) correspondante
                final String key = _pipCountData.keys.elementAt(index);
                // Affiche la lettre avec la bonne couleur
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    key,
                    style: GoogleFonts.cinzel(
                      color: _pipColors[key] ?? Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: barGroups, // Appliquer les barres créées
      ),
    );
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