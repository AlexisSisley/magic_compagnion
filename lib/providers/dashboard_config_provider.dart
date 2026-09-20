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

  /// Deplace [deplace] a la position [nouvelIndex] de la liste AFFICHEE.
  ///
  /// Le widget est designe par son identifiant, pas par un index, et c'est
  /// le coeur de la correction : la liste affichee est
  /// `configurableWidgets` (filtree des widgets retires), tandis que la
  /// version precedente indexait dans `widgets` (complete). Les deux
  /// coincident pour un utilisateur neuf, mais different d'un element pour
  /// un utilisateur dont la configuration cite encore un widget retire --
  /// deplacer la tuile N deplacait alors la N-1.
  Future<void> reorder(DashboardWidgetId deplace, int nouvelIndex) async {
    final config = state.value ?? DashboardConfig.defaultConfig();

    final affiches = config.configurableWidgets;
    final ancienIndex = affiches.indexWhere((w) => w.id == deplace);
    if (ancienIndex < 0) return;

    final item = affiches.removeAt(ancienIndex);
    affiches.insert(nouvelIndex.clamp(0, affiches.length), item);

    // Les widgets retires gardent leur place dans la configuration, apres
    // les affiches : ils ne sont pas rendus, donc leur ordre relatif n'a
    // aucun effet, mais les supprimer perdrait le reglage d'un utilisateur
    // si le widget revenait un jour.
    final idsAffiches = affiches.map((w) => w.id).toSet();
    final retires =
        config.widgets.where((w) => !idsAffiches.contains(w.id)).toList();

    final updated = <DashboardWidgetConfig>[
      for (var i = 0; i < affiches.length; i++) affiches[i].copyWith(order: i),
      for (var j = 0; j < retires.length; j++)
        retires[j].copyWith(order: affiches.length + j),
    ];

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
