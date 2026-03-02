// Fichier : lib/pages/collections/global_stats_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';

class GlobalStatsPage extends StatefulWidget {
  final List<DeckCard> collection;
  final List<ScryfallCard> fullCardData;
  final double totalValue;

  const GlobalStatsPage({
    super.key,
    required this.collection,
    required this.fullCardData,
    required this.totalValue,
  });

  @override
  State<GlobalStatsPage> createState() => _GlobalStatsPageState();
}

class _GlobalStatsPageState extends State<GlobalStatsPage> {
  Map<String, int> _colorDistribution = {};
  Map<String, int> _rarityDistribution = {};
  List<Map<String, dynamic>> _topValueCards = [];

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _calculateStats() {
    Map<String, int> colors = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0, 'M': 0};
    Map<String, int> rarities = {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0};
    List<Map<String, dynamic>> valuableCards = [];

    for (var deckCard in widget.collection) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;

      try {
        final card = widget.fullCardData.firstWhere((c) => c.id == deckCard.scryfallId);
        
        // 1. Couleurs (Basé sur l'identité couleur)
        if (card.colorIdentity.isEmpty) {
          colors['C'] = (colors['C'] ?? 0) + deckCard.quantity;
        } else if (card.colorIdentity.length > 1) {
          colors['M'] = (colors['M'] ?? 0) + deckCard.quantity;
        } else {
          String c = card.colorIdentity.first;
          colors[c] = (colors[c] ?? 0) + deckCard.quantity;
        }

        // 2. Rareté
        String r = card.rarity.toLowerCase();
        if (rarities.containsKey(r)) {
          rarities[r] = (rarities[r] ?? 0) + deckCard.quantity;
        }

        // 3. Top Valeur
        double price = double.tryParse(card.prices['eur'] ?? '0') ?? 0.0;
        if (price > 1.0) { // On ne garde que les cartes > 1€ pour le top
          valuableCards.add({
            'name': card.name,
            'price': price,
            'image': card.smallImageUrl,
            'set': card.setCode.toUpperCase(),
            'quantity': deckCard.quantity
          });
        }

      } catch (e) { /* ignore */ }
    }

    // Tri des cartes par valeur
    valuableCards.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));

    setState(() {
      _colorDistribution = colors;
      _rarityDistribution = rarities;
      _topValueCards = valuableCards.take(10).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Analyses Collection', style: AppTextStyles.bold()),
        backgroundColor: AppColors.textOnPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER VALEUR ---
            _buildValueHeader(),
            const SizedBox(height: 24),

            // --- GRAPHIQUE COULEURS ---
            _buildSectionTitle('Répartition par Couleur'),
            _buildColorPieChart(),
            const SizedBox(height: 24),

            // --- GRAPHIQUE RARETÉ ---
            _buildSectionTitle('Répartition par Rareté'),
            SizedBox(height: 200, child: _buildRarityBarChart()),
            const SizedBox(height: 24),

            // --- TOP CARTES ---
            _buildSectionTitle('Top 10 Cartes (Valeur unitaire)'),
            ..._topValueCards.map((c) => _buildTopCardTile(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildValueHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryShade900.withValues(alpha: 0.3), Colors.black]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryShade800),
      ),
      child: Column(
        children: [
          Text('Valeur Totale Estimée', style: AppTextStyles.subtitle()),
          const SizedBox(height: 8),
          Text(
            '${widget.totalValue.toStringAsFixed(2)} €',
            style: AppTextStyles.pageTitle(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.collection.fold(0, (s, c) => s + c.quantity)} cartes collectées',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPieChart() {
    // Map couleurs String -> Color Flutter
    final Map<String, Color> colorMap = {
      'W': const Color(0xFFF0F2C0), 
      'U': Colors.blue.shade400, 
      'B': AppColors.greyShade800,
      'R': Colors.red.shade400, 
      'G': Colors.green.shade400, 
      'C': Colors.brown.shade200, // Incolore
      'M': Colors.amber.shade600, // Multicolore
    };

    final Map<String, String> labelMap = {
      'W': 'Blanc', 'U': 'Bleu', 'B': 'Noir', 'R': 'Rouge', 
      'G': 'Vert', 'C': 'Incolore', 'M': 'Multi'
    };

    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];
    
    // Calcul du total pour les pourcentages
    int totalCount = _colorDistribution.values.fold(0, (a, b) => a + b);

    _colorDistribution.forEach((key, value) {
      if (value > 0) {
        final double percentage = totalCount > 0 ? (value / totalCount) * 100 : 0;
        final Color sectionColor = colorMap[key] ?? AppColors.synergyNeutral;

        // 1. Création de la section du graphique
        sections.add(PieChartSectionData(
          color: sectionColor,
          value: value.toDouble(),
          title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '', // Cache si < 5%
          radius: 50,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.overlayVeryDark),
        ));

        // 2. Création de l'item de légende
        legendItems.add(_buildLegendItem(sectionColor, labelMap[key] ?? key, value));
      }
    });

    if (sections.isEmpty) return const Center(child: Text('Pas assez de données', style: TextStyle(color: AppColors.textMuted)));

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Affichage de la légende en Wrap (retour à la ligne automatique)
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: legendItems,
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: AppTextStyles.label(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRarityBarChart() {
    final rarities = ['common', 'uncommon', 'rare', 'mythic'];
    final colors = [Colors.white, Colors.blue.shade300, AppColors.amber, Colors.orange.shade900];
    
    // Trouver le max pour l'échelle
    double maxY = 0;
    _rarityDistribution.forEach((_, v) { if (v > maxY) maxY = v.toDouble(); });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= rarities.length) return const SizedBox();
                // Affiche juste la première lettre en majuscule (C, U, R, M)
                return Text(rarities[idx][0].toUpperCase(), style: TextStyle(color: colors[idx], fontWeight: FontWeight.bold));
              }
            )
          )
        ),
        barGroups: List.generate(rarities.length, (index) {
          final key = rarities[index];
          final value = _rarityDistribution[key]?.toDouble() ?? 0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: colors[index],
                width: 20,
                borderRadius: BorderRadius.circular(4),
              )
            ],
            showingTooltipIndicators: [0], // Affiche la valeur au dessus
          );
        }),
      ),
    );
  }

  Widget _buildTopCardTile(Map<String, dynamic> item) {
    return Card(
      color: AppColors.textPrimary.withValues(alpha: 0.05),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: item['image'] != null 
            ? Image.network(item['image'], width: 30, fit: BoxFit.cover) 
            : const Icon(Icons.image),
        ),
        title: Text(item['name'], style: AppTextStyles.cinzel()),
        subtitle: Text("${item['set']} • x${item['quantity']}", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: Text("${item['price']} €", style: AppTextStyles.bold(color: AppColors.primaryShade700)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: title == 'Répartition par Rareté' ? 50.0 : 12.0),
      child: Text(title, style: AppTextStyles.sectionTitle()),
    );
  }
}
