// Fichier : lib/widgets/cards/card_detail_collection_modal.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../controllers/card_detail_controller.dart';

/// Shows the collection manager modal for adjusting normal/foil quantities.
void showCollectionManagerModal({
  required BuildContext context,
  required CardDetailState state,
  required CardDetailController controller,
  required void Function(String message, Color color) onFeedback,
}) {
  if (state.foundCard == null) return;

  int tempNormal = state.collectionNormalCount;
  int tempFoil = state.collectionFoilCount;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.scaffoldBackground,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              height: 350,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gerer ma Collection',
                      style: AppTextStyles.bold(fontSize: 20)),
                  const SizedBox(height: 24),
                  _CollectionQuantityRow(
                    label: 'Normal',
                    value: tempNormal,
                    color: AppColors.textPrimary,
                    onMinus: () {
                      setModalState(
                          () => tempNormal = (tempNormal - 1).clamp(0, 99));
                    },
                    onPlus: () {
                      setModalState(() => tempNormal++);
                    },
                  ),
                  const SizedBox(height: 16),
                  _CollectionQuantityRow(
                    label: 'Foil (Brillant)',
                    value: tempFoil,
                    color: AppColors.amber,
                    onMinus: () {
                      setModalState(
                          () => tempFoil = (tempFoil - 1).clamp(0, 99));
                    },
                    onPlus: () {
                      setModalState(() => tempFoil++);
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await controller.saveCollection(
                          normalCount: tempNormal,
                          foilCount: tempFoil,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        onFeedback('Collection mise a jour', AppColors.success);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16)),
                      child: Text('ENREGISTRER',
                          style:
                              AppTextStyles.bold()),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _CollectionQuantityRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CollectionQuantityRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(label.contains('Foil') ? Icons.star : Icons.style,
                  color: color),
              const SizedBox(width: 12),
              Text(label,
                  style: AppTextStyles.bold(color: color, fontSize: 16)),
            ],
          ),
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textMuted),
                  onPressed: onMinus),
              SizedBox(
                  width: 30,
                  child: Text('$value',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold))),
              IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: AppColors.accentGreen),
                  onPressed: onPlus),
            ],
          )
        ],
      ),
    );
  }
}
