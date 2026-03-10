// Fichier : lib/models/dashboard_config_model.dart
// Configuration personnalisable du dashboard (ordre, taille, visibilite des widgets).

enum DashboardWidgetId {
  quickActions,
  collectionSummary,
  valueChart,
  recentScans,
  recentDecks,
  favoriteDeck,
  collectionStats,
}

enum DashboardWidgetSize {
  small,
  medium,
  large,
}

class DashboardWidgetConfig {
  final DashboardWidgetId id;
  final int order;
  final DashboardWidgetSize size;
  final bool visible;

  const DashboardWidgetConfig({
    required this.id,
    required this.order,
    required this.size,
    this.visible = true,
  });

  DashboardWidgetConfig copyWith({
    int? order,
    DashboardWidgetSize? size,
    bool? visible,
  }) {
    return DashboardWidgetConfig(
      id: id,
      order: order ?? this.order,
      size: size ?? this.size,
      visible: visible ?? this.visible,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.name,
        'order': order,
        'size': size.name,
        'visible': visible,
      };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetConfig(
      id: DashboardWidgetId.values.firstWhere(
        (e) => e.name == json['id'],
        orElse: () => DashboardWidgetId.quickActions,
      ),
      order: json['order'] as int? ?? 0,
      size: DashboardWidgetSize.values.firstWhere(
        (e) => e.name == json['size'],
        orElse: () => DashboardWidgetSize.medium,
      ),
      visible: json['visible'] as bool? ?? true,
    );
  }
}

class DashboardConfig {
  final List<DashboardWidgetConfig> widgets;

  const DashboardConfig({required this.widgets});

  factory DashboardConfig.defaultConfig() {
    return const DashboardConfig(
      widgets: [
        DashboardWidgetConfig(
          id: DashboardWidgetId.quickActions,
          order: 0,
          size: DashboardWidgetSize.medium,
        ),
        DashboardWidgetConfig(
          id: DashboardWidgetId.collectionSummary,
          order: 1,
          size: DashboardWidgetSize.medium,
        ),
        DashboardWidgetConfig(
          id: DashboardWidgetId.valueChart,
          order: 2,
          size: DashboardWidgetSize.large,
        ),
        DashboardWidgetConfig(
          id: DashboardWidgetId.collectionStats,
          order: 3,
          size: DashboardWidgetSize.medium,
        ),
        DashboardWidgetConfig(
          id: DashboardWidgetId.recentScans,
          order: 4,
          size: DashboardWidgetSize.medium,
        ),
        DashboardWidgetConfig(
          id: DashboardWidgetId.recentDecks,
          order: 5,
          size: DashboardWidgetSize.medium,
        ),
        DashboardWidgetConfig(
          id: DashboardWidgetId.favoriteDeck,
          order: 6,
          size: DashboardWidgetSize.small,
        ),
      ],
    );
  }

  /// Deserialize with merge: any new widget IDs not in saved JSON
  /// get added from default config.
  factory DashboardConfig.fromJson(List<dynamic> json) {
    final saved = json
        .map((e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>))
        .toList();

    final savedIds = saved.map((w) => w.id).toSet();
    final defaults = DashboardConfig.defaultConfig().widgets;

    // Add any new widgets that weren't in the saved config
    for (final def in defaults) {
      if (!savedIds.contains(def.id)) {
        saved.add(def.copyWith(order: saved.length));
      }
    }

    saved.sort((a, b) => a.order.compareTo(b.order));
    return DashboardConfig(widgets: saved);
  }

  List<dynamic> toJson() => widgets.map((w) => w.toJson()).toList();

  /// Visible widgets sorted by order.
  List<DashboardWidgetConfig> get visibleWidgets =>
      widgets.where((w) => w.visible).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
}
