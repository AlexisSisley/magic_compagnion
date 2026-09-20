// Fichier : test/models/dashboard_config_retires_test.dart
// La rangee d'acces rapide ne revient pas sur le tableau de bord.
//
// Ses quatre entrees dupliquaient toutes un onglet de la barre -- Scanner,
// Recherche et Collection litteralement, et "Nouveau deck" ouvrait l'onglet
// Decks au lieu de creer un deck. La refonte de navigation existe pour
// supprimer ce doublon.
//
// La valeur d'enum SURVIT volontairement : `DashboardWidgetId` est serialise
// dans la configuration persistee de l'utilisateur, et la retirer casserait
// la relecture des configurations existantes. C'est donc au rendu qu'elle
// est filtree, et c'est ce filtre que ce fichier tient.

import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/dashboard_config_model.dart';
import 'package:magic_companion/providers/dashboard_config_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';

void main() {
  test('la configuration par defaut ne propose plus la rangee', () {
    final ids = DashboardConfig.defaultConfig().widgets.map((w) => w.id);

    expect(ids, isNot(contains(DashboardWidgetId.quickActions)));
  });

  test("une configuration persistee qui la contient ne l'affiche pas", () {
    // Le cas des utilisateurs existants : leur config stockee la cite encore.
    const config = DashboardConfig(widgets: [
      DashboardWidgetConfig(
          id: DashboardWidgetId.quickActions,
          order: 0,
          size: DashboardWidgetSize.medium),
      DashboardWidgetConfig(
          id: DashboardWidgetId.collectionSummary,
          order: 1,
          size: DashboardWidgetSize.medium),
    ]);

    final affiches = config.visibleWidgets.map((w) => w.id);

    expect(affiches, isNot(contains(DashboardWidgetId.quickActions)),
        reason: 'la rangee dupliquerait la barre d\'onglets');
    expect(affiches, contains(DashboardWidgetId.collectionSummary),
        reason: 'les autres widgets de la config doivent survivre au filtre');
  });

  test('elle ne reste pas basculable en mode edition', () {
    // Sinon l'utilisateur pourrait l'activer, et rien ne se passerait.
    const config = DashboardConfig(widgets: [
      DashboardWidgetConfig(
          id: DashboardWidgetId.quickActions,
          order: 0,
          size: DashboardWidgetSize.medium),
      DashboardWidgetConfig(
          id: DashboardWidgetId.collectionSummary,
          order: 1,
          size: DashboardWidgetSize.medium),
    ]);

    final configurables = config.configurableWidgets.map((w) => w.id);

    expect(configurables, isNot(contains(DashboardWidgetId.quickActions)));
    expect(configurables, contains(DashboardWidgetId.collectionSummary));
  });

  test("un identifiant inconnu ne retombe pas sur un widget retire", () {
    // Le repli de `fromJson` pointait sur quickActions : une config ecrite
    // par une version future aurait ressuscite la rangee.
    final config = DashboardWidgetConfig.fromJson(const {
      'id': 'widget_qui_nexiste_pas',
      'order': 0,
      'size': 'medium',
      'visible': true,
    });

    expect(config.id, isNot(DashboardWidgetId.quickActions));
  });

  test('reorder deplace la tuile designee, pas sa voisine', () async {
    // Le cas de l'utilisateur EXISTANT : sa configuration PERSISTEE cite
    // encore un widget retire, donc la liste affichee et la liste complete
    // different d'un element. Indexer dans la mauvaise faisait deplacer la
    // tuile N-1.
    //
    // La config est semee par la vraie voie de persistance -- pas par une
    // API de test sur le notifier -- pour que le test parte de l'etat qu'un
    // utilisateur a reellement sur son telephone.
    const config = DashboardConfig(widgets: [
      DashboardWidgetConfig(
          id: DashboardWidgetId.quickActions,
          order: 0,
          size: DashboardWidgetSize.medium),
      DashboardWidgetConfig(
          id: DashboardWidgetId.collectionSummary,
          order: 1,
          size: DashboardWidgetSize.medium),
      DashboardWidgetConfig(
          id: DashboardWidgetId.valueChart,
          order: 2,
          size: DashboardWidgetSize.large),
    ]);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting('dashboard_config', jsonEncode(config.toJson()));

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(dashboardConfigProvider.future);

    // Non-vacuite : c'est la PRESENCE du widget retire dans la config
    // complete qui cree le decalage entre liste affichee et liste indexee.
    // Sans elle, ce test mesurerait un cas ou les deux coincident.
    //
    // `fromJson` complete la config semee avec les widgets par defaut
    // manquants -- une migration pour les utilisateurs existants -- donc on
    // n'assert pas une longueur, mais bien la presence du retire.
    final complete = container.read(dashboardConfigProvider).value!;
    expect(complete.widgets.map((w) => w.id),
        contains(DashboardWidgetId.quickActions),
        reason: 'la configuration semee doit etre relue');
    expect(complete.configurableWidgets.length,
        lessThan(complete.widgets.length),
        reason: 'liste affichee et liste complete doivent differer, sinon '
            "le decalage qu'on mesure ne peut pas se produire");

    // Affiche : [collectionSummary, valueChart]. On remonte valueChart.
    await container
        .read(dashboardConfigProvider.notifier)
        .reorder(DashboardWidgetId.valueChart, 0);

    final affiches = container
        .read(dashboardConfigProvider)
        .value!
        .configurableWidgets
        .map((w) => w.id)
        .toList();

    expect(affiches.take(2).toList(), [
      DashboardWidgetId.valueChart,
      DashboardWidgetId.collectionSummary,
    ], reason: "c'est valueChart qui devait bouger, pas sa voisine");
  });
}
