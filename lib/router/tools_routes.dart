// Fichier : lib/router/tools_routes.dart
// Routes liees aux outils : calculateur, glossaire, tournoi, oracle, grimoire.

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../chat_screen.dart';
import '../data/glossary_data.dart';
import '../pages/glossary/glossary_detail_page.dart';
import '../pages/glossary/glossary_page.dart';
import '../pages/glossary/turn_guide_page.dart';
import '../pages/oracle/magic_oracle_page.dart';
import '../pages/tools/hypergeometric_page.dart';
import '../pages/tournaments/tournament_page.dart';
import 'app_routes.dart';

/// Routes pour les outils (drawer et detail).
List<RouteBase> toolsRoutes() {
  return [
    GoRoute(
      path: AppRoutes.tournament,
      builder: (context, state) => const TournamentPage(),
    ),
    GoRoute(
      path: AppRoutes.oracle,
      builder: (context, state) => const MagicOraclePage(),
    ),
    GoRoute(
      path: AppRoutes.grimoire,
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: AppRoutes.calculator,
      builder: (context, state) => const HypergeometricPage(),
    ),
    GoRoute(
      path: AppRoutes.glossary,
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text('Glossaire', style: AppTextStyles.cinzel())),
        backgroundColor: AppColors.scaffoldBackground,
        body: const GlossaryPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.turnGuide,
      builder: (context, state) => const TurnGuidePage(),
    ),
    GoRoute(
      path: AppRoutes.glossaryDetail,
      builder: (context, state) {
        final keyword = state.extra as Keyword;
        return GlossaryDetailPage(keyword: keyword);
      },
    ),
  ];
}
