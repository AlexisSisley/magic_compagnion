// Fichier : lib/pages/tools/hypergeometric_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class HypergeometricPage extends StatefulWidget {
  const HypergeometricPage({super.key});

  @override
  State<HypergeometricPage> createState() => _HypergeometricPageState();
}

class _HypergeometricPageState extends State<HypergeometricPage> {
  // Contrôleurs pour les champs de texte
  final TextEditingController _deckSizeController = TextEditingController(text: '99'); // N
  final TextEditingController _copiesController = TextEditingController(text: '36');   // K
  final TextEditingController _drawController = TextEditingController(text: '7');      // n
  final TextEditingController _wantedController = TextEditingController(text: '3');    // k

  // Résultats
  double _probExact = 0.0;
  double _probMore = 0.0;
  double _probLess = 0.0;
  bool _hasCalculated = false;

  @override
  void dispose() {
    _deckSizeController.dispose();
    _copiesController.dispose();
    _drawController.dispose();
    _wantedController.dispose();
    super.dispose();
  }

  // --- LOGIQUE MATHÉMATIQUE ---

  // Combinaison C(n, k)
  double _combination(int n, int k) {
    if (k < 0 || k > n) return 0;
    if (k > n / 2) k = n - k;
    
    double res = 1;
    for (int i = 1; i <= k; i++) {
      res = res * (n - i + 1) / i;
    }
    return res;
  }

  // Formule Hypergéométrique : P(X=k)
  double _hypergeometric(int N, int K, int n, int k) {
    return (_combination(K, k) * _combination(N - K, n - k)) / _combination(N, n);
  }

  void _calculate() {
    // Récupération des valeurs
    int N = int.tryParse(_deckSizeController.text) ?? 99;
    int K = int.tryParse(_copiesController.text) ?? 36;
    int n = int.tryParse(_drawController.text) ?? 7;
    int k = int.tryParse(_wantedController.text) ?? 3;

    // Validation basique
    if (N <= 0 || K < 0 || n < 0 || k < 0 || K > N || n > N || k > n) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Valeurs incohérentes.")));
      return;
    }

    // 1. Probabilité Exacte (X = k)
    double exact = _hypergeometric(N, K, n, k);

    // 2. Probabilité "Au moins k" (X >= k)
    double orMore = 0.0;
    int maxPossible = min(n, K);
    for (int i = k; i <= maxPossible; i++) {
      orMore += _hypergeometric(N, K, n, i);
    }

    // 3. Probabilité "Moins de k" (X < k)
    double less = 1.0 - orMore;

    setState(() {
      _probExact = exact * 100;
      _probMore = orMore * 100;
      _probLess = less * 100;
      _hasCalculated = true;
    });
    
    FocusScope.of(context).unfocus(); // Fermer le clavier
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Calculateur Proba", style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              
              // --- FORMULAIRE ---
              Row(
                children: [
                  Expanded(child: _buildInput(_deckSizeController, "Taille Deck", "Ex: 99")),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInput(_copiesController, "Cartes Ciblées", "Ex: 36 (Lands)")),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInput(_drawController, "Piochées", "Ex: 7 (Main)")),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInput(_wantedController, "Succès Voulus", "Ex: 3")),
                ],
              ),
              
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade800,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text("CALCULER", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 18)),
              ),

              // --- RÉSULTATS ---
              if (_hasCalculated) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Text("Résultats", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const Divider(color: Colors.white24, height: 24),
                      // Utilisation des contrôleurs pour le texte dynamique
                      _buildResultRow("Exactement ${_wantedController.text} cartes", _probExact, Colors.blueAccent),
                      _buildResultRow("${_wantedController.text} cartes ou plus", _probMore, Colors.greenAccent),
                      _buildResultRow("Moins de ${_wantedController.text} cartes", _probLess, Colors.redAccent),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Icon(Icons.calculate_outlined, size: 48, color: Colors.white54),
        const SizedBox(height: 8),
        Text(
          "Optimisez votre base de mana",
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInput(TextEditingController controller, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            filled: true,
            fillColor: Colors.black45,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // --- CORRECTION ICI ---
  Widget _buildResultRow(String label, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start, // Aligne en haut si le texte passe sur 2 lignes
        children: [
          // On utilise Expanded pour que le texte prenne la place disponible et revienne à la ligne
          Expanded(
            child: Text(
              label, 
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              softWrap: true, // Autorise le retour à la ligne
            ),
          ),
          const SizedBox(width: 16), // Petit espace de sécurité
          Text(
            "${percentage.toStringAsFixed(1)}%",
            style: GoogleFonts.cinzel(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}