// Fichier : lib/pages/turn_guide_page.dart
// NOUVEAU FICHIER

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';

class TurnGuidePage extends StatelessWidget {
  const TurnGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground, // Fond sombre
      appBar: AppBar(
        title: Text(
          'Phases d\'un Tour',
          style: AppTextStyles.cinzel(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.textOnPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: const [
          _PhaseCard(
            phaseTitle: '1. Phase de Début',
            steps: [
              'Étape de dégagement : Dégagez toutes vos cartes engagées (terrains, créatures, etc.).',
              "Étape d'entretien : Les effets 'au début de votre entretien' se déclenchent. Les joueurs peuvent lancer des éphémères.",
              'Étape de pioche : Vous piochez une carte. (Le premier joueur du match saute cette étape à son premier tour).',
            ],
            color: AppColors.info,
          ),
          _PhaseCard(
            phaseTitle: '2. Phase Principale (Pré-combat)',
            steps: [
              'Vous pouvez jouer un terrain (un seul par tour).',
              'Vous pouvez lancer des sorts (créatures, rituels, artefacts, etc.).',
              'Vous pouvez activer des capacités.',
            ],
            color: AppColors.synergyNeutral,
          ),
          _PhaseCard(
            phaseTitle: '3. Phase de Combat',
            steps: [
              'Étape de début de combat : Les joueurs peuvent lancer des éphémères/capacités.',
              'Étape de déclaration des attaquants : Vous déclarez quelles créatures attaquent.',
              'Étape de déclaration des bloqueurs : Votre adversaire déclare ses bloqueurs.',
              "Étape des blessures de combat : Les créatures s'infligent des blessures.",
              'Étape de fin de combat : Les joueurs peuvent lancer des éphémères/capacités.',
            ],
            color: AppColors.error,
          ),
          _PhaseCard(
            phaseTitle: '4. Phase Principale (Post-combat)',
            steps: [
              'Identique à la première phase principale.',
              "Vous pouvez jouer un terrain si vous ne l'avez pas fait avant.",
              "Vous pouvez lancer d'autres sorts.",
            ],
            color: AppColors.synergyNeutral,
          ),
          _PhaseCard(
            phaseTitle: '5. Phase de Fin',
            steps: [
              "Étape de fin : Les effets 'au début de votre étape de fin' se déclenchent.",
              "Étape de nettoyage : Vous vous défaussez pour n'avoir que 7 cartes en main. Les blessures sont retirées des créatures et les effets 'jusqu'à la fin du tour' se terminent.",
            ],
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

/// Un widget interne pour styliser chaque panneau déroulant
class _PhaseCard extends StatelessWidget {
  final String phaseTitle;
  final List<String> steps;
  final Color color;

  const _PhaseCard({
    required this.phaseTitle,
    required this.steps,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.4),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.8), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Le panneau est ouvert par défaut pour un accès facile
        initiallyExpanded: true, 
        title: Text(
          phaseTitle,
          style: AppTextStyles.bold(fontSize: 18),
        ),
        leading: const Icon(Icons.check_circle_outline, color: AppColors.textPrimary),
        childrenPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        // S'assure que les icônes ne changent pas de couleur quand on déroule
        iconColor: AppColors.textPrimary,
        collapsedIconColor: AppColors.textMuted,
        children: steps.map((step) => Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8.0, top: 4.0),
                child: Icon(Icons.arrow_right, color: AppColors.textMuted, size: 16),
              ),
              Expanded(
                child: Text(
                  step,
                  style: AppTextStyles.subtitle().copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
