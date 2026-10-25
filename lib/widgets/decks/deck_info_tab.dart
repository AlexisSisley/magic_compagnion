// Fichier : lib/widgets/decks/deck_info_tab.dart
// Onglet Infos : les tokens requis puis la légalité, dans un seul défilement.
// Les deux étaient des onglets à part ; regroupés, ils libèrent la barre
// d'onglets pour les quatre vues principales.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

import '../../controllers/deck_detail_controller.dart';
import '../../models/legality_report.dart';
import 'deck_legality_tab.dart';
import 'deck_tokens_tab.dart';

class DeckInfoTab extends StatelessWidget {
  final List<TokenInfo> tokens;
  final LegalityReport report;

  const DeckInfoTab({super.key, required this.tokens, required this.report});

  @override
  Widget build(BuildContext context) {
    // Les sections sont posées sans défilement propre : un seul défilement
    // vertical pour tout l'onglet.
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        _sectionTitle('Tokens (${tokens.length})'),
        DeckTokensTab(tokens: tokens, embedded: true),
        _sectionTitle('Légalité'),
        DeckLegalityTab(report: report, embedded: true),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTextStyles.sectionTitle()),
      ),
    );
  }
}
