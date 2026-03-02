// Fichier : lib/router/scanner_routes.dart
// Routes liees au scanner et a l'historique de scans.

import 'package:go_router/go_router.dart';

import '../pages/scans/scan_history_page.dart';
import '../pages/scans/scanner_page.dart';
import 'app_routes.dart';

/// Routes de detail pour le scanner (push par-dessus le shell).
List<RouteBase> scannerDetailRoutes() {
  return [
    GoRoute(
      path: AppRoutes.scanHistory,
      builder: (context, state) => const ScanHistoryPage(),
    ),
  ];
}

/// Route shell pour l'onglet scanner.
GoRoute scannerShellRoute() {
  return GoRoute(
    path: '/scanner',
    pageBuilder: (context, state) => const NoTransitionPage(
      child: ScannerPage(),
    ),
  );
}
