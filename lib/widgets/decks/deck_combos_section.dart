// Fichier : lib/widgets/decks/deck_combos_section.dart
// Sprint 11, Phase 4 : Section affichant les combos EDHREC detectes dans le deck.

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/deck_model.dart';
import '../../models/edhrec_models.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/deck_synergy_service.dart';

class DeckCombosSection extends ConsumerStatefulWidget {
  final Deck deck;
  final List<EdhrecCombo> topCombos;

  const DeckCombosSection({
    super.key,
    required this.deck,
    required this.topCombos,
  });

  @override
  ConsumerState<DeckCombosSection> createState() => _DeckCombosSectionState();
}

class _DeckCombosSectionState extends ConsumerState<DeckCombosSection> {
  List<DeckComboStatus> _comboStatuses = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  Future<void> _loadCombos() async {
    setState(() {
      _isLoading = true;
    });

    // Recuperer le nom du commandant
    String commanderName = '';
    try {
      final allCards = [...widget.deck.mainboard, ...widget.deck.sideboard];
      final cmdCard = allCards.firstWhere(
        (c) => c.scryfallId == widget.deck.commanderScryfallId,
        orElse: () => DeckCard(scryfallId: '', name: '', quantity: 0),
      );
      commanderName = cmdCard.name;
    } catch (_) {}

    if (commanderName.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasLoaded = true;
      });
      return;
    }

    // Charger les combos complets depuis EDHREC
    final edhrecService = ref.read(edhrecServiceProvider);
    final combos = await edhrecService.getCommanderCombos(commanderName);

    // Detecter la presence dans le deck
    List<DeckComboStatus> statuses = DeckSynergyService.detectCombos(
      combos: combos,
      deck: widget.deck,
    );

    if (mounted) {
      setState(() {
        _comboStatuses = statuses;
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deck.commanderScryfallId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.borderSubtle, height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.amber.shade600, size: 22),
              const SizedBox(width: 8),
              Text(
                'Combos',
                style: AppTextStyles.sectionTitle(color: Colors.amber.shade600),
              ),
              const Spacer(),
              if (!_hasLoaded)
                TextButton.icon(
                  onPressed: _isLoading ? null : _loadCombos,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
                        )
                      : Icon(Icons.search, color: Colors.amber.shade400, size: 18),
                  label: Text(
                    _isLoading ? 'Analyse...' : 'Detecter',
                    style: TextStyle(color: Colors.amber.shade400, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (!_hasLoaded && widget.topCombos.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Combos populaires (apercu)',
              style: TextStyle(color: AppColors.borderFaint, fontSize: 11),
            ),
          ),
          ...widget.topCombos.take(5).map(_buildTopComboPreview),
        ],
        if (_hasLoaded && _comboStatuses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Aucun combo connu pour ce commandant.',
              style: AppTextStyles.cinzel(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        if (_hasLoaded && _comboStatuses.isNotEmpty)
          ..._comboStatuses.take(20).map(_buildComboCard),
      ],
    );
  }

  Widget _buildTopComboPreview(EdhrecCombo combo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.amber.shade700, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              combo.name,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${combo.deckCount} decks',
            style: const TextStyle(color: AppColors.borderFaint, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildComboCard(DeckComboStatus status) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (status.completeness) {
      case ComboCompleteness.complete:
        badgeColor = AppColors.success;
        badgeText = 'Dans votre deck';
        badgeIcon = Icons.check_circle;
      case ComboCompleteness.partial:
        badgeColor = AppColors.warning;
        final missing = status.cardsMissing.length;
        badgeText = '$missing carte${missing > 1 ? 's' : ''} manquante${missing > 1 ? 's' : ''}';
        badgeIcon = Icons.warning_amber;
      case ComboCompleteness.none:
        badgeColor = AppColors.synergyNeutral;
        badgeText = 'Populaire';
        badgeIcon = Icons.trending_up;
    }

    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header : nom + badge
            Row(
              children: [
                Icon(badgeIcon, color: badgeColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status.combo.name,
                    style: AppTextStyles.bold(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Cartes du combo
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: status.combo.cardNames.map((cardName) {
                final isInDeck = status.cardsInDeck
                    .any((c) => c.toLowerCase() == cardName.toLowerCase());
                return GestureDetector(
                  onTap: () {
                    context.push(AppRoutes.cardDetail, extra: {'cardName': cardName});
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInDeck ? Icons.check_circle : Icons.circle_outlined,
                        color: isInDeck ? AppColors.success : Colors.red.shade300,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cardName,
                        style: TextStyle(
                          color: isInDeck ? Colors.white : Colors.red.shade200,
                          fontSize: 11,
                          decoration: isInDeck ? null : TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Resultats du combo
            if (status.combo.results.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                status.combo.results.join(' / '),
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Stats
            const SizedBox(height: 4),
            Row(
              children: [
                if (status.combo.deckCount > 0)
                  Text(
                    '${status.combo.deckCount} decks',
                    style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                  ),
                if (status.combo.percentage > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${status.combo.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
