// Fichier : lib/pages/glossary_detail_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/glossary_data.dart'; // Importer notre modèle

class GlossaryDetailPage extends StatelessWidget {
  final Keyword keyword;

  const GlossaryDetailPage({super.key, required this.keyword});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(keyword.term),
        backgroundColor: Colors.black,
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
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
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
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      keyword.example!,
                      style: GoogleFonts.cinzel(
                        color: Colors.white70,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
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