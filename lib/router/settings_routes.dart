// Fichier : lib/router/settings_routes.dart
// Routes liees aux parametres et gestion de profils.

import 'package:go_router/go_router.dart';

import '../pages/settings/profile_management_page.dart';
import '../pages/settings/settings_page.dart';
import 'app_routes.dart';

/// Routes pour les parametres et profils (drawer).
List<RouteBase> settingsRoutes() {
  return [
    GoRoute(
      path: AppRoutes.profiles,
      builder: (context, state) => const ProfileManagementPage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
  ];
}
