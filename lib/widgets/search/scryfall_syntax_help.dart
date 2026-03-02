// Fichier : lib/widgets/search/scryfall_syntax_help.dart
// Sprint 12 - US-12.1 : Aide syntaxe de recherche avancee Scryfall
// US-12.6 : Migre vers AppColors + AppTextStyles.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Widget modal affichant l'aide syntaxique Scryfall
/// avec les operateurs principaux et des exemples.
class ScryfallSyntaxHelp extends StatelessWidget {
  const ScryfallSyntaxHelp({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => const ScryfallSyntaxHelp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.dialogBackground,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border(
              top: BorderSide(color: AppColors.primaryShade800, width: 2),
            ),
          ),
          child: Column(
            children: [
              // Poignee de drag
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: AppColors.primaryShade700),
                    const SizedBox(width: 8),
                    Text(
                      'Syntaxe de Recherche Scryfall',
                      style: AppTextStyles.sectionTitle(fontSize: 18),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider, height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection(
                      'Operateurs de base',
                      [
                        const _SyntaxEntry('c:', 'Couleur', 'c:red, c:ub, c>=3'),
                        const _SyntaxEntry('t:', 'Type', 't:creature, t:instant'),
                        const _SyntaxEntry('o:', 'Texte Oracle', 'o:"draw a card"'),
                        const _SyntaxEntry('cmc', 'Cout de mana', 'cmc<=3, cmc=5'),
                        const _SyntaxEntry('pow', 'Force', 'pow>=5, pow=*'),
                        const _SyntaxEntry('tou', 'Endurance', 'tou>=4'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Filtres par edition et rarete',
                      [
                        const _SyntaxEntry('set:', 'Edition', 'set:mkm, set:dmu'),
                        const _SyntaxEntry('e:', 'Edition (alias)', 'e:one'),
                        const _SyntaxEntry('r:', 'Rarete', 'r:mythic, r:rare'),
                        const _SyntaxEntry('year:', 'Annee', 'year>=2024'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Proprietes et legalite',
                      [
                        const _SyntaxEntry('is:', 'Propriete', 'is:commander, is:transform'),
                        const _SyntaxEntry('f:', 'Format legal', 'f:modern, f:standard'),
                        const _SyntaxEntry('banned:', 'Banni dans', 'banned:legacy'),
                        const _SyntaxEntry('id:', 'Identite couleur', 'id:wubrg, id<=3'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Prix',
                      [
                        const _SyntaxEntry('eur', 'Prix EUR', 'eur<=5, eur>=10'),
                        const _SyntaxEntry('usd', 'Prix USD', 'usd<=10'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Exemples complets',
                      [
                        const _SyntaxEntry(
                          'c:red cmc<=3 t:creature',
                          'Creatures rouges CMC 3 ou moins',
                          null,
                        ),
                        const _SyntaxEntry(
                          'o:"draw" c:blue r:rare',
                          'Rares bleues avec "draw" dans le texte',
                          null,
                        ),
                        const _SyntaxEntry(
                          'is:commander id:bg pow>=5',
                          'Commandants noir-vert avec force 5+',
                          null,
                        ),
                        const _SyntaxEntry(
                          't:land produces>=3',
                          'Terrains produisant 3+ couleurs',
                          null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'La syntaxe avancee est automatiquement detectee. '
                              'Si votre recherche contient un operateur (comme c:, t:, cmc), '
                              'elle sera envoyee directement a Scryfall.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<_SyntaxEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bold(color: AppColors.primaryShade700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...entries.map(_buildEntryRow),
      ],
    );
  }

  Widget _buildEntryRow(_SyntaxEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: entry.example != null ? 80 : 240,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.overlayDark,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.borderMedium),
            ),
            child: Text(
              entry.operator,
              style: const TextStyle(
                color: AppColors.accentGreen,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (entry.example != null)
                  Text(
                    entry.example!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyntaxEntry {
  final String operator;
  final String description;
  final String? example;

  const _SyntaxEntry(this.operator, this.description, this.example);
}
