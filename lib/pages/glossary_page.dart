// Fichier : lib/pages/glossary_page.dart
// VERSION MISE À JOUR (Multilingue)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- AJOUTÉ
import '../data/glossary_data.dart'; // Importer nos données (FR)
import '../data/glossary_data_en.dart'; // <-- AJOUTÉ (EN)
import 'glossary_detail_page.dart';

class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key});

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  final TextEditingController _searchController = TextEditingController();
  
  // NOUVEAU: Listes de données
  List<Keyword> _displayedTerms = []; // Termes affichés (filtrés)
  List<Keyword> _allTerms = []; // Termes de la langue active
  String _currentLang = 'fr'; // Langue active
  bool _isLoading = true; // Pour le chargement initial

  @override
  void initState() {
    super.initState();
    // Charger la langue et les données au démarrage
    _loadPreferences();
    _searchController.addListener(_filterTerms);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTerms);
    _searchController.dispose();
    super.dispose();
  }

  // --- NOUVELLES FONCTIONS (Gestion de la langue) ---

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Charge la langue (défaut 'fr')
      _currentLang = prefs.getString('glossaryLang') ?? 'fr';
      _loadGlossaryData(); // Charge les données correspondantes
      _isLoading = false;
    });
  }

  Future<void> _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Bascule la langue
      _currentLang = (_currentLang == 'fr') ? 'en' : 'fr';
      // Sauvegarde le choix
      prefs.setString('glossaryLang', _currentLang);
      // Charge les nouvelles données
      _loadGlossaryData();
    });
  }

  void _loadGlossaryData() {
    // Pas besoin de setState ici, car appelé depuis des fonctions
    // qui le font déjà.
    if (_currentLang == 'fr') {
      _allTerms = glossaryTerms; //
    } else {
      _allTerms = glossaryTermsEN; // Données anglaises
    }
    // Met à jour la liste affichée
    _filterTerms();
  }

  // --- FONCTION DE FILTRAGE (Mise à jour) ---

  void _filterTerms() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayedTerms = _allTerms; // Utilise _allTerms
      } else {
        _displayedTerms = _allTerms // Utilise _allTerms
            .where((keyword) => keyword.term.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Affiche un indicateur de chargement pendant la lecture
    // des SharedPreferences
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // --- Barre de recherche (MODIFIÉE) ---
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row( // <-- MODIFIÉ: Ligne pour le champ + bouton
            children: [
              // --- Champ de recherche ---
              Expanded( // Prend l'espace disponible
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: _currentLang == 'fr' 
                              ? 'Rechercher un mot-clé...' 
                              : 'Search a keyword...',
                    hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 16),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white70, width: 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10), // Espace
              
              // --- NOUVEAU: Bouton de langue ---
              TextButton(
                onPressed: _toggleLanguage,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.white70, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                ),
                child: Text(
                  _currentLang.toUpperCase(), // Affiche 'FR' ou 'EN'
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // --- Liste des résultats (Inchangée) ---
        Expanded(
          child: ListView.builder(
            itemCount: _displayedTerms.length,
            itemBuilder: (context, index) {
              final keyword = _displayedTerms[index];
              
              return Card(
                color: Colors.black.withOpacity(0.4),
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: BorderSide(
                    color: Colors.yellow.shade800.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                
                child: ListTile(
                  leading: Icon(
                    Icons.auto_stories_outlined,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  
                  title: Text(
                    keyword.term,
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  splashColor: Colors.yellow.withOpacity(0.1),
                  
                  onTap: () {
                    // La page de détail n'a pas besoin de savoir la langue,
                    // elle reçoit juste l'objet Keyword !
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GlossaryDetailPage(keyword: keyword),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}