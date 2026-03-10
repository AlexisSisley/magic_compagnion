// Fichier : lib/router/dashboard_routes.dart
// Sprint 15, US-LC03 : Dashboard est maintenant une route Drawer (push).
// N'est plus un shell tab.

import 'package:go_router/go_router.dart';

import '../pages/dashboard/dashboard_page.dart';
import 'app_routes.dart';

/// Route push pour le Dashboard (accessible depuis le Drawer).
/// US-LC03 : Dashboard descend dans le Drawer.
List<RouteBase> dashboardRoutes() {
  return [
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardPage(),
    ),
  ];
}
