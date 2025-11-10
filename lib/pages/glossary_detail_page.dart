// Fichier : lib/pages/glossary_detail_page.dart

import 'package:flutter/material.dart';
import '../data/glossary_data.dart'; // Importer notre modèle

class GlossaryDetailPage extends StatelessWidget {
  final Keyword keyword;

  const GlossaryDetailPage({super.key, required this.keyword});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Fond sombre
      appBar: AppBar(
        title: Text(keyword.term),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            keyword.definition,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}