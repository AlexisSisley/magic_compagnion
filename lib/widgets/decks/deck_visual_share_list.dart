// Fichier : lib/widgets/decks/deck_visual_share_list.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../cards/scryfall_image.dart';

class DeckVisualShareList extends StatelessWidget {
  final Deck deck;
  final List<ScryfallCard> fullCardData;
  final double totalPrice;

  const DeckVisualShareList({
    super.key,
    required this.deck,
    required this.fullCardData,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Préparation des données
    final Map<String, List<DeckCard>> categorizedCards = _categorizeDeck();
    final commanderCard = _getCommanderCard();
    final partnerCard = _getPartnerCard();
    final Map<int, int> manaCurve = _calculateManaCurve();
    
    // Stats rapides
    int creatureCount = _countType('Creature');
    int landCount = _countType('Land');
    int totalCount = deck.mainboard.fold(0, (s, c) => s + c.quantity);

    // Ordre d'affichage
    final List<String> categoryOrder = [
      'Creature', 'Planeswalker', 'Instant', 'Sorcery',
      'Artifact', 'Enchantment', 'Battle', 'Land', 'Other'
    ];

    // DEFINITION DE LA LARGEUR FIXE (Format Poster HD)
    const double fixedWidth = 1080.0; 
    const double padding = 32.0;
    // Calcul pour 5 colonnes de cartes
    const double cardWidth = (fixedWidth - (padding * 2) - (12 * 4)) / 5; 

    return Container(
      width: fixedWidth, // Largeur forcée pour l'export HD
      color: AppColors.surfaceDarkest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- HEADER STYLE (Repris de DeckSharePreview) ---
          SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fond Commandant
                if (commanderCard != null)
                  _buildCommanderBackground(commanderCard)
                else
                  Container(color: AppColors.greyShade900),
                
                // Dégradé sombre
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [AppColors.transparent, AppColors.surfaceDarkest],
                      stops: [0.3, 1.0],
                    ),
                  ),
                ),

                // Infos du Deck
                Positioned(
                  bottom: 20, left: 32, right: 32,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(deck.name, style: AppTextStyles.pageTitle(fontSize: 42).copyWith(shadows: [const Shadow(color: AppColors.textOnPrimary, blurRadius: 10)])),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('${deck.format} • $totalCount cartes', style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 20, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 16),
                                _buildColorIdentityRow(deck.colors),
                              ],
                            )
                          ],
                        ),
                      ),
                      // Prix
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textOnPrimary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accentOrange),
                        ),
                        child: Text(
                          '${totalPrice.toStringAsFixed(0)} €',
                          style: AppTextStyles.pageTitle(fontSize: 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- STATS & COURBE MANA ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats (Colonne gauche)
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.pets, '$creatureCount', 'Créatures'),
                      _buildStatItem(Icons.landscape, '$landCount', 'Terrains'),
                      _buildStatItem(Icons.bolt, '${totalCount - creatureCount - landCount}', 'Sorts'),
                    ],
                  ),
                ),
                // Séparateur
                Container(width: 1, height: 80, color: AppColors.borderSubtle, margin: const EdgeInsets.symmetric(horizontal: 32)),
                // Courbe (Colonne droite)
                Expanded(
                  flex: 3,
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
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                        ),
                        barGroups: manaCurve.entries.map((e) {
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(toY: e.value.toDouble(), color: AppColors.accent, width: 16, borderRadius: BorderRadius.circular(4))
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 24),

          // --- CONTENU DU DECK ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // COMMANDANTS
                if (commanderCard != null || partnerCard != null) ...[
                  _buildSectionTitle('Zone de Commandement'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (commanderCard != null) Expanded(child: _buildLargeCardItem(commanderCard, true)),
                      if (commanderCard != null && partnerCard != null) const SizedBox(width: 24),
                      if (partnerCard != null) Expanded(child: _buildLargeCardItem(partnerCard, true)),
                      if ((commanderCard == null || partnerCard == null) && (commanderCard != null || partnerCard != null))
                        const Spacer(), // Équilibre
                    ],
                  ),
                  const SizedBox(height: 32),
                ],

                // GRILLE PAR CATEGORIE
                ...categoryOrder.map((category) {
                  final cards = categorizedCards[category] ?? [];
                  if (cards.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSectionTitle('$category (${cards.fold(0, (sum, c) => sum + c.quantity)})'),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: cards.map((card) => _buildGridCardItem(card, cardWidth)).toList(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                }),
              ],
            ),
          ),

          // --- FOOTER ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            color: AppColors.textPrimary.withValues(alpha: 0.02),
            child: Center(
              child: Text(
                'Généré avec Magic Companion',
                style: AppTextStyles.bold(color: AppColors.borderMedium, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS HELPERS ---

  Widget _buildCommanderBackground(DeckCard cmd) {
    final scryfall = _getScryfallData(cmd);
    final url = scryfall?.imageUrl ?? scryfall?.smallImageUrl;
    if (url == null) return Container(color: AppColors.greyShade900);
    
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (_, _, _) => Container(color: AppColors.greyShade900),
    );
  }

  Widget _buildColorIdentityRow(List<String> colors) {
    if (colors.isEmpty) return const Icon(Icons.circle_outlined, color: AppColors.synergyNeutral, size: 24);
    return Row(
      children: colors.map((c) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SvgPicture.network(
          'https://svgs.scryfall.io/card-symbols/$c.svg',
          width: 28, height: 28,
          placeholderBuilder: (_) => Text(c, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20)),
        ),
      )).toList(),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 32),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.pageTitle(fontSize: 28)),
        Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 14)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4, height: 24, color: AppColors.accentOrange),
        const SizedBox(width: 12),
        Text(title.toUpperCase(), style: AppTextStyles.pageTitle(fontSize: 20).copyWith(letterSpacing: 1.5)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: AppColors.borderLight)),
      ],
    );
  }

  Widget _buildLargeCardItem(DeckCard card, bool isCommander) {
    final scryfall = _getScryfallData(card);
    final imageUrl = scryfall?.artCropUrl ?? scryfall?.imageUrl;

    return AspectRatio(
      aspectRatio: 2.5, // Format très large type bannière
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.5), width: 2),
          color: AppColors.overlayDark,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ScryfallImage(imageUrl: imageUrl, alignment: Alignment.topCenter),
            
            Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [AppColors.overlayVeryDark, AppColors.transparent, AppColors.overlayVeryDark]))),
            
            Center(
              child: Text(
                card.name,
                style: AppTextStyles.pageTitle(fontSize: 22).copyWith(shadows: [const Shadow(color: AppColors.textOnPrimary, blurRadius: 10)]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCardItem(DeckCard card, double width) {
    final scryfall = _getScryfallData(card);
    final imageUrl = scryfall?.artCropUrl ?? scryfall?.imageUrl;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          AspectRatio(
            aspectRatio: 1.5, // Format paysage
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
                color: AppColors.greyShade900,
              ),
              clipBehavior: Clip.antiAlias,
              child: ScryfallImage(imageUrl: imageUrl),
            ),
          ),
          const SizedBox(height: 6),
          // Texte
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)),
                child: Text('${card.quantity}', style: const TextStyle(color: AppColors.accentOrange, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(card.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- LOGIQUE DATA ---

  DeckCard? _getCommanderCard() {
    if (deck.commanderScryfallId == null) return null;
    try { return deck.mainboard.firstWhere((c) => c.scryfallId == deck.commanderScryfallId); } catch (e) { return null; }
  }
  DeckCard? _getPartnerCard() {
    if (deck.commanderSecondaryScryfallId == null) return null;
    try { return deck.mainboard.firstWhere((c) => c.scryfallId == deck.commanderSecondaryScryfallId); } catch (e) { return null; }
  }

  ScryfallCard? _getScryfallData(DeckCard card) {
    if (card.scryfallId.startsWith('LOCAL:')) return null;
    try { return fullCardData.firstWhere((s) => s.id == card.scryfallId); } catch (e) { return null; }
  }

  Map<String, List<DeckCard>> _categorizeDeck() {
    Map<String, List<DeckCard>> categories = {};
    for (final deckCard in deck.mainboard) {
      if (deckCard.scryfallId == deck.commanderScryfallId || deckCard.scryfallId == deck.commanderSecondaryScryfallId) continue;
      final scryfall = _getScryfallData(deckCard);
      String type = 'Other';
      if (scryfall != null) {
        final tl = scryfall.typeLine.toLowerCase();
        if (tl.contains('land')) {
          type = 'Land';
        } else if (tl.contains('creature')) {
          type = 'Creature';
        } else if (tl.contains('planeswalker')) {
          type = 'Planeswalker';
        } else if (tl.contains('instant')) {
          type = 'Instant';
        } else if (tl.contains('sorcery')) {
          type = 'Sorcery';
        } else if (tl.contains('artifact')) {
          type = 'Artifact';
        } else if (tl.contains('enchantment')) {
          type = 'Enchantment';
        } else if (tl.contains('battle')) {
          type = 'Battle';
        }
      }
      if (!categories.containsKey(type)) categories[type] = [];
      categories[type]!.add(deckCard);
    }
    for(var k in categories.keys) {
      categories[k]!.sort((a,b) => a.name.compareTo(b.name));
    }
    return categories;
  }

  int _countType(String typeKeyword) {
    int count = 0;
    for (final c in deck.mainboard) {
      if (c.scryfallId == deck.commanderScryfallId || c.scryfallId == deck.commanderSecondaryScryfallId) continue;
      final sc = _getScryfallData(c);
      if (sc != null && sc.typeLine.toLowerCase().contains(typeKeyword.toLowerCase())) count += c.quantity;
    }
    return count;
  }

  Map<int, int> _calculateManaCurve() {
    Map<int, int> curve = {0:0, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};
    for (var c in deck.mainboard) {
      final sc = _getScryfallData(c);
      if (sc != null && !sc.typeLine.toLowerCase().contains('land')) {
        int cmc = (sc.cmc ?? 0).toInt();
        if (cmc >= 7) {
          curve[7] = (curve[7] ?? 0) + c.quantity;
        } else {
          curve[cmc] = (curve[cmc] ?? 0) + c.quantity;
        }
      }
    }
    return curve;
  }
}
