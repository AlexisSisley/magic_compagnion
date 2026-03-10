// Fichier : lib/providers/dashboard_config_provider.dart
// Persistence et gestion de la configuration personnalisable du dashboard.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_config_model.dart';
import 'service_providers.dart';

const _settingKey = 'dashboard_config';

class DashboardConfigNotifier extends AsyncNotifier<DashboardConfig> {
  @override
  Future<DashboardConfig> build() async {
    final db = ref.read(appDatabaseProvider);
    final raw = await db.getSetting(_settingKey);
    if (raw == null) return DashboardConfig.defaultConfig();
    final json = jsonDecode(raw) as List<dynamic>;
    return DashboardConfig.fromJson(json);
  }

  Future<void> _persist(DashboardConfig config) async {
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_settingKey, jsonEncode(config.toJson()));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final config = state.value ?? DashboardConfig.defaultConfig();
    final widgets = List<DashboardWidgetConfig>.from(config.widgets)
      ..sort((a, b) => a.order.compareTo(b.order));

    final item = widgets.removeAt(oldIndex);
    widgets.insert(newIndex, item);

    // Reassign order values
    final updated = <DashboardWidgetConfig>[];
    for (int i = 0; i < widgets.length; i++) {
      updated.add(widgets[i].copyWith(order: i));
    }

    final newConfig = DashboardConfig(widgets: updated);
    state = AsyncValue.data(newConfig);
    await _persist(newConfig);
  }

  Future<void> toggleVisibility(DashboardWidgetId id) async {
    final config = state.value ?? DashboardConfig.defaultConfig();
    final updated = config.widgets.map((w) {
      if (w.id == id) return w.copyWith(visible: !w.visible);
      return w;
    }).toList();

    final newConfig = DashboardConfig(widgets: updated);
    state = AsyncValue.data(newConfig);
    await _persist(newConfig);
  }

  Future<void> resize(DashboardWidgetId id, DashboardWidgetSize size) async {
    final config = state.value ?? DashboardConfig.defaultConfig();
    final updated = config.widgets.map((w) {
      if (w.id == id) return w.copyWith(size: size);
      return w;
    }).toList();

    final newConfig = DashboardConfig(widgets: updated);
    state = AsyncValue.data(newConfig);
    await _persist(newConfig);
  }

  Future<void> resetToDefault() async {
    final config = DashboardConfig.defaultConfig();
    state = AsyncValue.data(config);
    await _persist(config);
  }
}

final dashboardConfigProvider =
    AsyncNotifierProvider<DashboardConfigNotifier, DashboardConfig>(
  DashboardConfigNotifier.new,
);
