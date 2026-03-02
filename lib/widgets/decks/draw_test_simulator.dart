// Fichier : lib/widgets/decks/draw_test_simulator.dart
// VERSION MISE À JOUR : Analyseur de Mana ajouté

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
          color: AppColors.scaffoldBackground.withAlpha((0.98 * 255).round()),
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
                    style: AppTextStyles.bold(fontSize: 20),
                  ),
                  Text(
                    'Biblio: ${_library.length} | Main: ${_hand.length}',
                    style: AppTextStyles.subtitle(),
                  ),
                ],
              ),
            ),
            
            // --- Analyseur de Mana (NOUVEAU) ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.overlayDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const Text('Sources disponibles :', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                  ? Center(child: Text('Main vide.', style: AppTextStyles.cinzel(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: _hand.length,
                      itemBuilder: (context, index) {
                        final card = _hand[index];
                        
                        String? smallImageUrl;
                        String typeLine = '';
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
                          color: isLand ? Colors.brown.shade900.withValues(alpha: 0.3) : AppColors.textOnPrimary.withValues(alpha: 0.3),
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
                                      color: AppColors.greyShade800,
                                      child: const Icon(Icons.image_not_supported, color: AppColors.textDisabled, size: 24),
                                    ),
                            ),
                            title: Text(
                              card.name,
                              style: AppTextStyles.cinzel(color: isLand ? Colors.amber.shade100 : AppColors.textPrimary, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: isLand 
                              ? const Text('Terrain', style: TextStyle(color: AppColors.borderFaint, fontSize: 10)) 
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
                    label: Text('Piocher 1', style: AppTextStyles.cinzel()),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    onPressed: _mulligan,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                    label: Text('Mulligan (${7 - _mulliganCount - 1})', style: AppTextStyles.cinzel()),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 16),
                    onPressed: _startNewGame,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                    label: Text('Reset', style: AppTextStyles.cinzel()),
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
            placeholderBuilder: (_) => Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              color: count > 0 ? Colors.white : AppColors.synergyNeutral, 
              fontWeight: FontWeight.bold, 
              fontSize: 12
            ),
          ),
        ],
      ),
    );
  }
}
