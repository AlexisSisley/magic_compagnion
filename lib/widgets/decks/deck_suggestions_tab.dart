// Fichier : lib/widgets/decks/deck_suggestions_tab.dart
// VERSION REFACTORISEE : Utilise DeckSuggestionsController via Riverpod.
// Sprint 11, Feature #5 : Synergy banner, theme chips, enriched suggestions.
// Sprint 11, Feature #4 : DeckCombosSection integree en bas.

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/deck_suggestions_controller.dart';
import '../../models/deck_model.dart';
import '../../router/app_router.dart';
import '../../services/edhrec_service.dart';
import '../../utils/price_helper.dart';
import 'deck_combos_section.dart';

class DeckSuggestionsTab extends ConsumerStatefulWidget {
  final Deck deck;

  const DeckSuggestionsTab({
    super.key,
    required this.deck,
  });

  @override
  ConsumerState<DeckSuggestionsTab> createState() => _DeckSuggestionsTabState();
}

class _DeckSuggestionsTabState extends ConsumerState<DeckSuggestionsTab> {
  bool _combosExpanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-load is triggered by the button press, not initState.
  }

  Future<void> _triggerLoad() async {
    final controller = ref.read(
      deckSuggestionsControllerProvider(widget.deck).notifier,
    );
    final ok = await controller.loadSuggestions();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Definissez d'abord un Commandant !"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deck.commanderScryfallId == null) {
      return Center(
        child: Text(
          'Aucun Commandant defini.',
          style: AppTextStyles.cinzel(color: AppColors.textSecondary),
        ),
      );
    }

    final state = ref.watch(
      deckSuggestionsControllerProvider(widget.deck),
    );

    // Not yet loaded: show the load button
    if (!state.hasLoaded && !state.isLoading) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _triggerLoad,
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            'Obtenir les Suggestions',
            style: AppTextStyles.bold(),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade800,
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      );
    }

    // Loading state
    if (state.isLoading && !state.hasLoaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Analyse EDHRec...',
              style: AppTextStyles.bold(),
            ),
          ],
        ),
      );
    }

    // Loaded but empty
    if (state.hasLoaded && state.enrichedSuggestions.isEmpty) {
      return Center(
        child: Text(
          'Aucune suggestion trouvee.',
          style: AppTextStyles.cinzel(color: AppColors.textMuted),
        ),
      );
    }

    // Build full suggestions view
    return _buildSuggestionsView(state);
  }

  Widget _buildSuggestionsView(DeckSuggestionsState state) {
    final categories = state.enrichedSuggestions.keys.toList();
    final themes = state.commanderData?.themes ?? [];
    final topCombos = state.commanderData?.topCombos ?? [];

    return CustomScrollView(
      slivers: [
        // --- Synergy Report Banner ---
        if (state.synergyReport != null)
          SliverToBoxAdapter(
            child: _buildSynergyBanner(state.synergyReport!),
          ),

        // --- Theme Chips ---
        if (themes.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildThemeChips(themes, state),
          ),

        // --- Theme cards (when a theme is selected) ---
        if (state.selectedTheme != null)
          SliverToBoxAdapter(
            child: _buildThemeCardsSection(state),
          ),

        // --- Enriched Suggestions by Category ---
        ...categories.map((category) {
          final suggestions = state.enrichedSuggestions[category]!;
          return SliverToBoxAdapter(
            child: _buildCategorySection(category, suggestions),
          );
        }),

        // --- DeckCombosSection (collapsible) ---
        if (state.hasLoaded)
          SliverToBoxAdapter(
            child: _buildCollapsibleCombos(topCombos),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  // ============================================================
  // SYNERGY BANNER
  // ============================================================

  Widget _buildSynergyBanner(DeckSynergyReport report) {
    final score = report.globalScore;
    final Color bannerColor;
    if (score >= 70) {
      bannerColor = AppColors.synergyPositive;
    } else if (score >= 40) {
      bannerColor = Colors.orange;
    } else {
      bannerColor = AppColors.synergyNegative;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, color: bannerColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score de Synergie',
                  style: AppTextStyles.bold(color: bannerColor, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.cardsWithSynergyData}/${report.totalDeckCards} cartes analysees',
                  style: TextStyle(
                    color: bannerColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${score.toStringAsFixed(0)}/100',
              style: AppTextStyles.bold(color: bannerColor, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // THEME CHIPS
  // ============================================================

  Widget _buildThemeChips(
    List<EdhrecTheme> themes,
    DeckSuggestionsState state,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Themes',
            style: AppTextStyles.bold(
              color: AppColors.primaryShade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: themes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final theme = themes[index];
                final isSelected = state.selectedTheme == theme.slug;
                return FilterChip(
                  label: Text(
                    '${theme.name} (${theme.deckCount})',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.textOnPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.purple.shade600,
                  backgroundColor: AppColors.cardBackground,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.purple.shade400
                        : AppColors.borderMedium,
                  ),
                  onSelected: (_) {
                    final controller = ref.read(
                      deckSuggestionsControllerProvider(widget.deck).notifier,
                    );
                    if (isSelected) {
                      controller.clearTheme();
                    } else {
                      controller.loadThemeCards(theme);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // THEME CARDS SECTION
  // ============================================================

  Widget _buildThemeCardsSection(DeckSuggestionsState state) {
    if (state.isLoadingTheme) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentPurple,
            ),
          ),
        ),
      );
    }

    final themeCards = state.themeCards;
    if (themeCards == null || themeCards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Aucune carte pour ce theme.',
          style: AppTextStyles.cinzel(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.style, color: Colors.purple.shade300, size: 18),
              const SizedBox(width: 6),
              Text(
                'Cartes du theme "${state.selectedTheme}"',
                style: AppTextStyles.bold(
                  color: Colors.purple.shade300,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ...themeCards.take(15).map(_buildThemeCardTile),
        if (themeCards.length > 15)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '... et ${themeCards.length - 15} autres',
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const Divider(color: AppColors.borderSubtle, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildThemeCardTile(EdhrecCardSuggestion suggestion) {
    final synergyColor = suggestion.synergy >= 0
        ? AppColors.synergyPositive
        : AppColors.synergyNegative;

    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: () {
          context.push(AppRoutes.cardDetail, extra: {'cardName': suggestion.name});
        },
        title: Text(
          suggestion.name,
          style: AppTextStyles.cinzel(fontSize: 13),
        ),
        subtitle: Row(
          children: [
            Text(
              '${suggestion.inclusion}% inclusion',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${suggestion.numDecks} decks',
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: _buildSynergyBadge(suggestion.synergy, synergyColor),
      ),
    );
  }

  // ============================================================
  // CATEGORY SECTION (enriched suggestions)
  // ============================================================

  Widget _buildCategorySection(
    String category,
    List<EnrichedSuggestion> suggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            category,
            style: AppTextStyles.bold(
              color: AppColors.primaryShade700,
              fontSize: 18,
            ),
          ),
        ),
        ...suggestions.take(10).map(_buildEnrichedSuggestionTile),
        if (suggestions.length > 10)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '... et ${suggestions.length - 10} autres',
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEnrichedSuggestionTile(EnrichedSuggestion suggestion) {
    final card = suggestion.card;
    final String? imageUrl =
        card.smallImageUrl ?? (card.imageUrl.isNotEmpty ? card.imageUrl : null);
    final String price = PriceHelper.formatCompact(card.prices);
    final bool isFallback = card.id.startsWith('edhrec_');
    final synergyColor = suggestion.synergy >= 0
        ? AppColors.synergyPositive
        : AppColors.synergyNegative;

    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onTap: () {
          context.push(
            AppRoutes.cardDetail,
            extra: {'cardName': card.name},
          );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? Image.network(
                  imageUrl,
                  width: 40,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 40,
                    height: 56,
                    color: AppColors.greyShade800,
                    child: const Icon(
                      Icons.broken_image,
                      color: AppColors.borderMedium,
                    ),
                  ),
                )
              : Container(
                  width: 40,
                  height: 56,
                  color: AppColors.greyShade800,
                  child: const Icon(
                    Icons.search,
                    color: AppColors.borderMedium,
                  ),
                ),
        ),
        title: Text(card.name, style: AppTextStyles.cinzel(fontSize: 16)),
        subtitle: isFallback
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Donnees locales manquantes - Cliquez pour chercher',
                    style: TextStyle(
                      color: AppColors.accentOrange,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildInclusionRow(suggestion),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (card.manaCost != null)
                        _ManaDisplay(manaCost: card.manaCost!),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card.typeLine,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (card.setCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderMedium),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            card.setCode.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      _buildInclusionRow(suggestion),
                      const Spacer(),
                      if (!isFallback)
                        Text(
                          price,
                          style: TextStyle(
                            color: AppColors.primaryShade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSynergyBadge(suggestion.synergy, synergyColor),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                context.push(
                  AppRoutes.cardDetail,
                  extra: {'cardName': card.name},
                );
              },
              child: const Icon(
                Icons.add_circle_outline,
                color: AppColors.accentGreen,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a small row showing inclusion % and number of decks.
  Widget _buildInclusionRow(EnrichedSuggestion suggestion) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${suggestion.inclusion}%',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${suggestion.numDecks} decks)',
          style: const TextStyle(
            color: AppColors.textDisabled,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SYNERGY BADGE
  // ============================================================

  Widget _buildSynergyBadge(double synergy, Color color) {
    final sign = synergy >= 0 ? '+' : '';
    final percent = (synergy * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$sign$percent%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // COLLAPSIBLE COMBOS SECTION
  // ============================================================

  Widget _buildCollapsibleCombos(List<EdhrecCombo> topCombos) {
    return Column(
      children: [
        const Divider(color: AppColors.borderSubtle, height: 32),
        GestureDetector(
          onTap: () {
            setState(() {
              _combosExpanded = !_combosExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.bolt, color: Colors.amber.shade600, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Combos',
                  style: AppTextStyles.sectionTitle(
                    color: Colors.amber.shade600,
                  ),
                ),
                const Spacer(),
                Icon(
                  _combosExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.amber.shade400,
                ),
              ],
            ),
          ),
        ),
        if (_combosExpanded)
          DeckCombosSection(
            deck: widget.deck,
            topCombos: topCombos,
          ),
      ],
    );
  }
}

// ============================================================
// MANA DISPLAY (unchanged)
// ============================================================

class _ManaDisplay extends StatelessWidget {
  final String manaCost;
  const _ManaDisplay({required this.manaCost});

  @override
  Widget build(BuildContext context) {
    final RegExp regex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');
    final matches = regex.allMatches(manaCost);
    if (matches.isEmpty) return const SizedBox();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: matches.map((m) {
        final symbol = m.group(1)?.replaceAll('/', '') ?? '';
        final cleanSymbol = symbol.toUpperCase();
        return Padding(
          padding: const EdgeInsets.only(right: 1.0),
          child: SvgPicture.network(
            'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg',
            width: 12,
            height: 12,
            placeholderBuilder: (_) => Text(
              symbol,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
