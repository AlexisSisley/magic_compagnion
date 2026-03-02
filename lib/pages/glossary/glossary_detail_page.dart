// Fichier : lib/pages/glossary_detail_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../data/glossary_data.dart'; // Importer notre modèle

class GlossaryDetailPage extends StatelessWidget {
  final Keyword keyword;

  const GlossaryDetailPage({super.key, required this.keyword});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(keyword.term),
        backgroundColor: AppColors.textOnPrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Définition (Inchangé) ---
              Text(
                keyword.definition,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.5),
              ),

              // --- NOUVEAU : Affichage de l'image ---
              if (keyword.image != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Center(
                    child: Image.asset(keyword.image!),
                  ),
                ),

              // --- NOUVEAU : Affichage de l'exemple ---
              if (keyword.example != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: AppColors.borderMedium),
                    ),
                    child: Text(
                      keyword.example!,
                      style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 15, fontStyle: FontStyle.italic).copyWith(height: 1.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
