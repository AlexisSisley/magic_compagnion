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
import 'package:magic_companion/models/dashboard_config_model.dart';

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
}
