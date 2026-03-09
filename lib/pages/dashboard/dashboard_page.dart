// Fichier : lib/pages/dashboard/dashboard_page.dart
// Sprint 14, US-14.6 : Dashboard Home.
// Resume : nb cartes, valeur totale, derniers scans (5), decks recents (3),
// graphique evolution valeur en preview.
// Remplace le LifeCounter comme tab0 du BottomNav.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/dashboard_provider.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/price_helper.dart';
import '../../widgets/cards/scryfall_image.dart';
import '../../widgets/common/shimmer_loading.dart';
import '../../widgets/common/staggered_fade_in.dart';
import '../../widgets/dashboard/collection_value_chart.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        title: Text('Dashboard', style: AppTextStyles.appBarTitle()),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const _DashboardShimmer(),
        error: (e, _) => Center(
          child: Text('Erreur: $e',
              style: AppTextStyles.body(color: AppColors.error)),
        ),
        data: (state) => _DashboardContent(state: state),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final DashboardState state;

  const _DashboardContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.primaryGold,
      backgroundColor: AppColors.cardBackground,
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // --- SECTION 1 : Resume Collection ---
          StaggeredFadeIn(
            index: 0,
            child: _CollectionSummaryCard(
              totalCards: state.totalCards,
              totalValue: state.totalValue,
              isLoadingValue: state.valueIsLoading,
            ),
          ),

          const SizedBox(height: 16),

          // --- SECTION 2 : Graphique evolution valeur (preview) ---
          StaggeredFadeIn(
            index: 1,
            child: _ValueChartPreview(valueHistory: state.valueHistory),
          ),

          const SizedBox(height: 16),

          // --- SECTION 3 : Derniers Scans ---
          if (state.recentScans.isNotEmpty) ...[
            StaggeredFadeIn(
              index: 2,
              child: _SectionHeader(
                title: 'Derniers Scans',
                icon: Icons.camera_alt,
                onSeeAll: () => context.push(AppRoutes.scanHistory),
              ),
            ),
            ...state.recentScans.asMap().entries.map((entry) {
              final scan = entry.value;
              return StaggeredFadeIn(
                index: 3 + entry.key,
                child: _RecentScanTile(
                  cardName: scan.cardName,
                  scryfallId: scan.scryfallId,
                  timestamp: scan.timestamp,
                  onTap: () => context.push(
                    AppRoutes.cardDetail,
                    extra: <String, dynamic>{'cardName': scan.cardName},
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // --- SECTION 4 : Decks Recents ---
          if (state.recentDecks.isNotEmpty) ...[
            StaggeredFadeIn(
              index: 8,
              child: _SectionHeader(
                title: 'Decks Recents',
                icon: Icons.style_outlined,
                onSeeAll: () => context.go(AppRoutes.decks),
              ),
            ),
            ...state.recentDecks.asMap().entries.map((entry) {
              final deck = entry.value;
              return StaggeredFadeIn(
                index: 9 + entry.key,
                child: _RecentDeckTile(
                  deckName: deck.name,
                  cardCount: deck.mainboard.fold<int>(
                      0, (sum, c) => sum + c.quantity),
                  format: deck.format,
                  onTap: () => context.push(
                    AppRoutes.deckDetail,
                    extra: deck,
                  ),
                ),
              );
            }),
          ],

          // Padding bottom
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================
// SUB-WIDGETS
// ============================================================

class _CollectionSummaryCard extends StatelessWidget {
  final int totalCards;
  final double totalValue;
  final bool isLoadingValue;

  const _CollectionSummaryCard({
    required this.totalCards,
    required this.totalValue,
    required this.isLoadingValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // Nombre de cartes
          Expanded(
            child: _StatColumn(
              icon: Icons.inventory_2_outlined,
              label: 'Cartes',
              value: totalCards.toString(),
              color: AppColors.accent,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.borderLight,
          ),
          // Valeur totale
          Expanded(
            child: isLoadingValue
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  )
                : _StatColumn(
                    icon: Icons.euro,
                    label: 'Valeur',
                    value: PriceHelper.formatValue(totalValue),
                    color: AppColors.primaryGold,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.sectionTitle(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.label(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ValueChartPreview extends StatelessWidget {
  final List<({String dateKey, double value})> valueHistory;

  const _ValueChartPreview({required this.valueHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: AppColors.primaryGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Evolution Valeur (30j)',
                style: AppTextStyles.cardTitle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CollectionValueChart(
            dataPoints: valueHistory,
            height: 120,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.sectionTitle(fontSize: 16)),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'Voir tout',
                style: AppTextStyles.label(
                  color: AppColors.accent,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  final String cardName;
  final String scryfallId;
  final DateTime timestamp;
  final VoidCallback onTap;

  const _RecentScanTile({
    required this.cardName,
    required this.scryfallId,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        'https://api.scryfall.com/cards/$scryfallId?format=image&version=small';
    final timeAgo = _formatTimeAgo(timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                ScryfallImage(
                  imageUrl: imageUrl,
                  width: 36,
                  height: 50,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardName,
                        style: AppTextStyles.cardTitle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo,
                        style: AppTextStyles.label(
                          color: AppColors.textDisabled,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textDisabled,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _RecentDeckTile extends StatelessWidget {
  final String deckName;
  final int cardCount;
  final String format;
  final VoidCallback onTap;

  const _RecentDeckTile({
    required this.deckName,
    required this.cardCount,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.style_outlined,
                    color: AppColors.primaryGold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deckName,
                        style: AppTextStyles.cardTitle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$cardCount cartes - $format',
                        style: AppTextStyles.label(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textDisabled,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SHIMMER LOADING STATE
// ============================================================

class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerDashboardSummary(),
        SizedBox(height: 16),
        ShimmerChartPlaceholder(height: 140),
        SizedBox(height: 16),
        ShimmerCardList(itemCount: 5),
      ],
    );
  }
}
