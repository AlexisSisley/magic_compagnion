// lib/widgets/life_counter/reorganise_bar.dart
// Barre de mode : on sait qu'on réorganise, et comment en sortir (spec §1.9).
//
// Avant, rien ne distinguait une table qu'on joue d'une table qu'on
// réarrange : seule l'icône du bouton changeait de teinte. C'est ainsi qu'on
// déplace un joueur en croyant lui retirer un point de vie. Cette barre en
// pied, présente tant que le mode dure, dit le mode, suspend explicitement
// le décompte, et porte la sortie (« Terminé ») là où on la cherche.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Un preset d'orientation tel que la barre l'affiche : un libellé et ce
/// qu'il fait. La barre ne connaît pas la géométrie -- la page dérive les
/// presets de la disposition réellement rendue (`_getOrientationPresets`) et
/// les lui passe tout faits. L'enum `OrientationPreset` du plan arrivera
/// avec la refonte des presets (tâche 8b) si elle s'avère utile.
typedef ReorganisePreset = ({String label, VoidCallback onTap});

class ReorganiseBar extends StatelessWidget {
  const ReorganiseBar({
    super.key,
    required this.presets,
    required this.onDone,
  });

  final List<ReorganisePreset> presets;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
      ),
      // La barre est en pied d'écran : sans `SafeArea`, « Terminé » passerait
      // sous la barre de gestes système.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.drag_handle,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Réorganisation',
                      style: AppTextStyles.bold(
                          fontSize: 15, color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'le décompte est suspendu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.text(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in presets)
                    OutlinedButton(
                      key: ValueKey('reorganise-preset-${preset.label}'),
                      onPressed: preset.onTap,
                      style: OutlinedButton.styleFrom(
                        // 48 de haut : aucune cible sous
                        // `kMinInteractiveDimension`.
                        minimumSize: const Size(
                            kMinInteractiveDimension, kMinInteractiveDimension),
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderMedium),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(preset.label),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('reorganise-done'),
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(kMinInteractiveDimension),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                child: const Text('Terminé'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
