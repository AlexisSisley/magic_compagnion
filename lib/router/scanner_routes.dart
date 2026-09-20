// Fichier : lib/router/scanner_routes.dart
// Branche Scanner du shell : le scanner, son historique, et la fiche carte
// qu'on ouvre depuis un scan.

import 'package:go_router/go_router.dart';

import '../pages/scans/scan_history_page.dart';
import '../pages/scans/scanner_page.dart';
import 'app_routes.dart';
import 'card_detail_route.dart';
import 'page_transitions.dart';

GoRoute scannerBranchRoute() {
  return GoRoute(
    path: AppRoutes.scanner,
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const ScannerPage(),
    ),
    routes: [
      GoRoute(
        path: 'history',
        builder: (context, state) => const ScanHistoryPage(),
      ),
      cardDetailRoute(),
    ],
  );
}
