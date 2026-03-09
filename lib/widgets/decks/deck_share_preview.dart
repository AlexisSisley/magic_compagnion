// Fichier : lib/widgets/decks/deck_share_preview.dart
// VERSION MISE À JOUR : Icônes Mana SVG

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // <--- Import ajouté
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
    String cmdName = 'Deck sans Commandant';
    if (deck.commanderScryfallId != null) {
      final cmd = fullCardData.where((c) => c.id == deck.commanderScryfallId).firstOrNull;
      if (cmd != null) {
        cmdImageUrl = cmd.artCropUrl ?? (cmd.imageUrl.isNotEmpty ? cmd.imageUrl : cmd.smallImageUrl);
        cmdName = cmd.name;
      }
    } else if (deck.mainboard.isNotEmpty) {
      final first = fullCardData.where((c) => c.id == deck.mainboard.first.scryfallId).firstOrNull;
      if (first != null) {
        cmdImageUrl = first.imageUrl;
        cmdName = deck.name;
      }
    }

    int creatureCount = 0;
    int landCount = 0;
    
    // Courbe de mana simplifiée
    Map<int, int> curve = {0:0, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};

    for (var deckCard in deck.mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      final card = fullCardData.where((c) => c.id == deckCard.scryfallId).firstOrNull;
      if (card == null) continue;
      final type = card.typeLine.toLowerCase();

      if (type.contains('land')) {
        landCount += deckCard.quantity;
      } else {
        if (type.contains('creature')) creatureCount += deckCard.quantity;

        int cmc = (card.cmc ?? 0).toInt();
        if (cmc >= 7) {
          curve[7] = (curve[7] ?? 0) + deckCard.quantity;
        } else {
          curve[cmc] = (curve[cmc] ?? 0) + deckCard.quantity;
        }
      }
    }

    return Container(
      width: 400, // Largeur fixe pour l'export
      color: AppColors.surfaceDarkest,
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
                      colors: [AppColors.transparent, AppColors.surfaceDarkest],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16, left: 16, right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deck.name, style: AppTextStyles.pageTitle().copyWith(shadows: [const Shadow(color: AppColors.textOnPrimary, blurRadius: 10)])),
                      Text(cmdName, style: AppTextStyles.bold(color: AppColors.primaryShade700).copyWith(shadows: [const Shadow(color: AppColors.textOnPrimary, blurRadius: 4)])),
                    ],
                  ),
                ),
                // --- INDICATEURS MANA (MODIFIÉ ICI) ---
                Positioned(
                  top: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.textOnPrimary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: deck.colors.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SvgPicture.network(
                          'https://svgs.scryfall.io/card-symbols/$c.svg',
                          width: 20, 
                          height: 20,
                          placeholderBuilder: (context) => Text(c, style: AppTextStyles.bold()),
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
                _buildStatItem(Icons.style, '${deck.mainboard.fold(0, (s,c)=>s+c.quantity)}', 'Cartes'),
                _buildStatItem(Icons.euro, totalPrice.toStringAsFixed(0), 'Est. Prix'),
                _buildStatItem(Icons.pets, '$creatureCount', 'Créatures'),
                _buildStatItem(Icons.landscape, '$landCount', 'Terrains'),
              ],
            ),
          ),

          const Divider(color: AppColors.borderLight),

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
                          val.toInt() == 7 ? '7+' : '${val.toInt()}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10)
                        ),
                      ),
                    ),
                  ),
                  barGroups: curve.entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(toY: e.value.toDouble(), color: AppColors.accent, width: 8, borderRadius: BorderRadius.circular(2))
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
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            child: Text('Généré par Magic Companion', style: AppTextStyles.cinzel(color: AppColors.textDisabled, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.sectionTitle()),
        Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10)),
      ],
    );
  }
}
