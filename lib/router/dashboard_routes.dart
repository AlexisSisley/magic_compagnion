// Fichier : lib/router/dashboard_routes.dart
// Sprint 14, US-14.6 : Route shell pour le Dashboard Home (tab0).
// Remplace le LifeCounter comme onglet principal.

import 'package:go_router/go_router.dart';

import '../pages/dashboard/dashboard_page.dart';
import 'page_transitions.dart';

/// Route shell pour l'onglet Dashboard (tab0).
GoRoute dashboardShellRoute() {
  return GoRoute(
    path: '/',
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const DashboardPage(),
    ),
  );
}
