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
        // Pas `quickActions` en repli : il est retire de l'affichage, et un
        // identifiant inconnu ne doit pas ressusciter un widget qu'on ne
        // montre plus.
        orElse: () => DashboardWidgetId.collectionSummary,
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

  /// Identifiants encore lisibles dans une configuration persistee, mais
  /// qui ne s'affichent plus.
  ///
  /// `quickActions` proposait Scanner, Deck, Recherche et Collection --
  /// quatre entrees dont toutes dupliquaient un onglet de la barre. La
  /// refonte de navigation existe pour supprimer ce doublon.
  ///
  /// Filtre ici plutot que supprime de l'enum : `DashboardWidgetId` est
  /// serialise dans la configuration de l'utilisateur, et retirer la valeur
  /// casserait la relecture des configurations existantes.
  static const _retires = <DashboardWidgetId>{DashboardWidgetId.quickActions};

  /// Les widgets qu'un utilisateur peut encore montrer ou cacher.
  ///
  /// Le mode edition doit lire CETTE liste, pas `widgets` : sinon un widget
  /// retire y resterait basculable, et l'activer ne ferait rien puisque
  /// `visibleWidgets` le filtre.
  List<DashboardWidgetConfig> get configurableWidgets =>
      widgets.where((w) => !_retires.contains(w.id)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  /// Les widgets effectivement affiches, tries par ordre.
  List<DashboardWidgetConfig> get visibleWidgets =>
      configurableWidgets.where((w) => w.visible).toList();
}
