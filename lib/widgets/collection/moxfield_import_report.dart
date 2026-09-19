// Fichier : lib/widgets/collection/moxfield_import_report.dart
// Bilan d'import de collection Moxfield (ecran 3 du parcours guide).
//
// Un compteur d'erreurs ne se corrige pas ; une liste de noms, si. Ce widget
// nomme systematiquement les cartes qui demandent une action (taguees a
// verifier, non identifiees, lignes illisibles) plutot que de se contenter
// de les compter.
//
// CollectionImportResult distingue deux raisons opposees pour lesquelles une
// ligne n'a pas de tirage : `notIdentified` est definitif (Scryfall a
// confirme ne pas connaitre la carte), `failedTransient` est transitoire
// (un lot reseau n'a pas abouti, reessayer l'import peut suffire). Les
// confondre dirait a l'utilisateur "cette carte n'existe pas" alors que la
// vraie cause est une panne passagere : ce widget les affiche donc dans deux
// blocs distincts, chacun avec son propre message.
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

import 'package:flutter/material.dart';

import '../../models/moxfield_import.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class MoxfieldImportReport extends StatelessWidget {
  const MoxfieldImportReport({super.key, required this.result});

  final CollectionImportResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _counterRow('Cartes importées', r.imported, color: AppColors.success),
        _counterRow('Ajoutées', r.added),
        _counterRow('Quantité mise à jour', r.updated),
        if (r.tagged > 0)
          _counterRow('Tagées à vérifier', r.tagged, color: AppColors.amber),
        if (r.notIdentified > 0)
          _counterRow('Non identifiées', r.notIdentified, color: AppColors.error),
        if (r.failedTransient > 0)
          _counterRow('Échecs réseau', r.failedTransient, color: AppColors.amber),
        if (r.tagged > 0) ...[
          const SizedBox(height: 12),
          _namesPanel(
            label: 'Tagées à vérifier',
            explanation:
                "Identifiées par leur nom seul, faute d'édition dans le "
                'fichier : vérifie le tirage retenu pour ces cartes.',
            names: r.taggedNames,
            color: AppColors.amber,
          ),
        ],
        if (r.notIdentified > 0) ...[
          const SizedBox(height: 12),
          _namesPanel(
            label: 'Non identifiées',
            explanation:
                'Scryfall ne connaît pas ces cartes : vérifie le nom dans '
                'le fichier.',
            names: r.notIdentifiedNames,
            color: AppColors.error,
          ),
        ],
        if (r.failedTransient > 0) ...[
          const SizedBox(height: 12),
          _messagePanel(
            label: 'Échecs réseau',
            message:
                "Une erreur réseau a interrompu l'identification de "
                '${r.failedTransient} carte(s) : réessaie l\'import.',
            color: AppColors.amber,
          ),
        ],
        if (r.unreadableLines.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Ton distinct de "Non identifiees" (error/rouge) : une ligne
          // illisible est un probleme de format du fichier, pas une carte
          // que Scryfall a rejetee -- moins grave, un second ton d'alerte
          // (warning/orange) evite de confondre les deux categories.
          _namesPanel(
            label: 'Lignes illisibles',
            explanation:
                "Ces lignes du fichier n'ont pas pu être lues, citées "
                'telles quelles :',
            names: r.unreadableLines,
            color: AppColors.warning,
          ),
        ],
      ],
    );
  }

  Widget _counterRow(String label, int value, {Color? color}) {
    final valueStyle = AppTextStyles.body(color: color ?? AppColors.textPrimary).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderMedium)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body(color: AppColors.textSecondary)),
          Text('$value', style: valueStyle),
        ],
      ),
    );
  }

  Widget _namesPanel({
    required String label,
    required String explanation,
    required List<String> names,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.label(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(explanation, style: AppTextStyles.body(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          for (final name in names)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $name', style: AppTextStyles.body(color: color)),
            ),
        ],
      ),
    );
  }

  Widget _messagePanel({
    required String label,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.label(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.body(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
