// Fichier : lib/pages/dashboard/dashboard_page.dart
// Dashboard Home avec widgets personnalisables (ordre, taille, visibilite).
// Grille StaggeredGrid config-driven + mode edition avec ReorderableListView.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/dashboard_config_model.dart';
import '../../providers/dashboard_config_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/shimmer_loading.dart';
import '../../widgets/common/staggered_fade_in.dart';
import '../../widgets/dashboard/dashboard_collection_stats.dart';
import '../../widgets/dashboard/dashboard_collection_summary.dart';
import '../../widgets/dashboard/dashboard_favorite_deck.dart';
import '../../widgets/dashboard/dashboard_quick_actions.dart';
import '../../widgets/dashboard/dashboard_recent_decks.dart';
import '../../widgets/dashboard/dashboard_recent_scans.dart';
import '../../widgets/dashboard/dashboard_value_chart_preview.dart';
import '../../widgets/dashboard/dashboard_widget_wrapper.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final configAsync = ref.watch(dashboardConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        title: Text('Dashboard', style: AppTextStyles.bold(fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_editMode)
            TextButton(
              onPressed: () {
                ref.read(dashboardConfigProvider.notifier).resetToDefault();
                setState(() => _editMode = false);
              },
              child: Text(
                'Reset',
                style: AppTextStyles.label(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              _editMode ? Icons.check : Icons.edit_outlined,
              color: _editMode ? AppColors.primaryGold : AppColors.textPrimary,
            ),
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const _DashboardShimmer(),
        error: (e, _) => Center(
          child: Text('Erreur: $e',
              style: AppTextStyles.body(color: AppColors.error)),
        ),
        data: (state) => configAsync.when(
          loading: () => const _DashboardShimmer(),
          error: (_, _) => _DashboardBody(
            state: state,
            config: DashboardConfig.defaultConfig(),
            editMode: _editMode,
          ),
          data: (config) => _DashboardBody(
            state: state,
            config: config,
            editMode: _editMode,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BODY: normal mode (StaggeredGrid) or edit mode (ReorderableListView)
// ============================================================

class _DashboardBody extends ConsumerWidget {
  final DashboardState state;
  final DashboardConfig config;
  final bool editMode;

  const _DashboardBody({
    required this.state,
    required this.config,
    required this.editMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (editMode) {
      return _EditModeList(state: state, config: config);
    }
    return _NormalModeGrid(state: state, config: config);
  }
}

// ============================================================
// NORMAL MODE: StaggeredGrid
// ============================================================

class _NormalModeGrid extends ConsumerWidget {
  final DashboardState state;
  final DashboardConfig config;

  const _NormalModeGrid({required this.state, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = config.visibleWidgets;

    return RefreshIndicator(
      color: AppColors.primaryGold,
      backgroundColor: AppColors.cardBackground,
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: visible.asMap().entries.map((entry) {
            final idx = entry.key;
            final wc = entry.value;
            return StaggeredGridTile.fit(
              crossAxisCellCount: wc.size == DashboardWidgetSize.small ? 1 : 2,
              child: StaggeredFadeIn(
                index: idx,
                child: DashboardWidgetWrapper(
                  child: _buildWidget(wc.id),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWidget(DashboardWidgetId id) {
    switch (id) {
      case DashboardWidgetId.quickActions:
        return const DashboardQuickActions();
      case DashboardWidgetId.collectionSummary:
        return DashboardCollectionSummary(
          totalCards: state.totalCards,
          totalValue: state.totalValue,
          isLoadingValue: state.valueIsLoading,
        );
      case DashboardWidgetId.valueChart:
        return DashboardValueChartPreview(
          valueHistory: state.valueHistory,
        );
      case DashboardWidgetId.recentScans:
        return DashboardRecentScans(recentScans: state.recentScans);
      case DashboardWidgetId.recentDecks:
        return DashboardRecentDecks(recentDecks: state.recentDecks);
      case DashboardWidgetId.favoriteDeck:
        return DashboardFavoriteDeck(favoriteDeck: state.favoriteDeck);
      case DashboardWidgetId.collectionStats:
        return DashboardCollectionStats(
          topValueCards: state.topValueCards,
          colorDistribution: state.colorDistribution,
          editionCount: state.editionCount,
        );
    }
  }
}

// ============================================================
// EDIT MODE: ReorderableListView
// ============================================================

class _EditModeList extends ConsumerWidget {
  final DashboardState state;
  final DashboardConfig config;

  const _EditModeList({required this.state, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = List<DashboardWidgetConfig>.from(config.widgets)
      ..sort((a, b) => a.order.compareTo(b.order));

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref.read(dashboardConfigProvider.notifier).reorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            color: AppColors.transparent,
            elevation: 4,
            shadowColor: AppColors.primaryGold.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final wc = sorted[index];
        return Padding(
          key: ValueKey(wc.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: DashboardWidgetWrapper(
            editMode: true,
            visible: wc.visible,
            size: wc.size,
            onToggleVisibility: () {
              ref
                  .read(dashboardConfigProvider.notifier)
                  .toggleVisibility(wc.id);
            },
            onResize: (newSize) {
              ref
                  .read(dashboardConfigProvider.notifier)
                  .resize(wc.id, newSize);
            },
            child: _EditWidgetPreview(id: wc.id),
          ),
        );
      },
    );
  }
}

class _EditWidgetPreview extends StatelessWidget {
  final DashboardWidgetId id;

  const _EditWidgetPreview({required this.id});

  String get _label {
    switch (id) {
      case DashboardWidgetId.quickActions:
        return 'Actions rapides';
      case DashboardWidgetId.collectionSummary:
        return 'Resume Collection';
      case DashboardWidgetId.valueChart:
        return 'Evolution Valeur';
      case DashboardWidgetId.recentScans:
        return 'Derniers Scans';
      case DashboardWidgetId.recentDecks:
        return 'Decks Recents';
      case DashboardWidgetId.favoriteDeck:
        return 'Deck Favori';
      case DashboardWidgetId.collectionStats:
        return 'Stats Collection';
    }
  }

  IconData get _icon {
    switch (id) {
      case DashboardWidgetId.quickActions:
        return Icons.flash_on;
      case DashboardWidgetId.collectionSummary:
        return Icons.inventory_2_outlined;
      case DashboardWidgetId.valueChart:
        return Icons.show_chart;
      case DashboardWidgetId.recentScans:
        return Icons.camera_alt;
      case DashboardWidgetId.recentDecks:
        return Icons.style_outlined;
      case DashboardWidgetId.favoriteDeck:
        return Icons.star_outline;
      case DashboardWidgetId.collectionStats:
        return Icons.bar_chart;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_icon, color: AppColors.primaryGold, size: 20),
        const SizedBox(width: 10),
        Text(
          _label,
          style: AppTextStyles.cardTitle(fontSize: 14),
        ),
      ],
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
