// Fichier : lib/pages/glossary_page.dart
// VERSION MISE À JOUR (Catégories + Recherche)

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:developer';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/glossary_data.dart'; // Importer notre modèle (Keyword)
import '../../router/app_router.dart';

class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key});

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Keyword> _displayedTerms = [];
  List<Keyword> _allTerms = []; 
  String _currentLang = 'fr';
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndData(); 
    _searchController.addListener(_filterTerms);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTerms);
    _searchController.dispose();
    super.dispose();
  }

  // --- GESTION DES DONNÉES (Inchangée) ---

  Future<void> _loadPreferencesAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final String savedLang = prefs.getString('glossaryLang') ?? 'fr';
    await _loadGlossaryData(savedLang);
  }

  Future<void> _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final String newLang = (_currentLang == 'fr') ? 'en' : 'fr';
    await prefs.setString('glossaryLang', newLang);
    await _loadGlossaryData(newLang);
  }

  Future<void> _loadGlossaryData(String lang) async {
    if (mounted) setState(() { _isLoading = true; _currentLang = lang; });

    try {
      final String assetPath = (lang == 'fr') 
          ? 'assets/glossary_fr.json' 
          : 'assets/glossary_en.json';
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List;
      
      List<Keyword> loadedTerms = jsonList
          .map((jsonItem) => Keyword.fromJson(jsonItem as Map<String, dynamic>))
          .toList();
      
      // Tri alphabétique (pour l'affichage filtré ET catégorisé)
      loadedTerms.sort((a, b) => a.term.compareTo(b.term));

      if (mounted) {
        setState(() {
          _allTerms = loadedTerms;
          _filterTerms(); 
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Erreur de chargement du glossaire: $e', name: 'GlossaryPage');
      if (mounted) setState(() { _isLoading = false; _allTerms = []; _displayedTerms = []; });
    }
  }

  // --- FONCTION DE FILTRAGE (Inchangée) ---

  void _filterTerms() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // Quand la recherche est vide, _displayedTerms n'est pas utilisé
        _displayedTerms = _allTerms; 
      } else {
        // Quand on tape, on filtre la liste complète
        _displayedTerms = _allTerms
            .where((keyword) => keyword.term.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  // --- INTERFACE UTILISATEUR (MISE À JOUR) ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // --- Barre de recherche (Inchangée) ---
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: AppTextStyles.cinzel(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: _currentLang == 'fr' 
                              ? 'Rechercher un mot-clé...' 
                              : 'Search a keyword...',
                    hintStyle: AppTextStyles.cinzel(color: AppColors.textMuted, fontSize: 16),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.textOnPrimary.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _toggleLanguage,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.textSecondary, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                ),
                child: Text(
                  _currentLang.toUpperCase(),
                  style: AppTextStyles.bold(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        
        // --- NOUVELLE LOGIQUE D'AFFICHAGE ---
        Expanded(
          // Si on recherche, on affiche la liste filtrée
          // Sinon, on affiche la nouvelle liste par catégories
          child: _searchController.text.isNotEmpty
              ? _buildFilteredList()
              : _buildCategorizedList(),
        ),
      ],
    );
  }

  // --- NOUVEAU WIDGET : Liste filtrée (ce qu'on avait avant) ---
  Widget _buildFilteredList() {
    return ListView.builder(
      itemCount: _displayedTerms.length, // Utilise la liste filtrée
      itemBuilder: (context, index) {
        final keyword = _displayedTerms[index];
        // Construit la même ListTile qu'avant
        return _buildKeywordTile(keyword);
      },
    );
  }

  // --- NOUVEAU WIDGET : Liste par catégories ---
  Widget _buildCategorizedList() {
    // 1. Grouper les termes par catégorie
    Map<String, List<Keyword>> groupedMap = {};
    for (final keyword in _allTerms) {
      if (!groupedMap.containsKey(keyword.category)) {
        groupedMap[keyword.category] = [];
      }
      groupedMap[keyword.category]!.add(keyword);
    }

    // 2. Trier les catégories (ex: "1. Zones", "2. Types"...)
    final sortedCategories = groupedMap.keys.toList()..sort();

    // 3. Construire la liste
    return ListView.builder(
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final categoryName = sortedCategories[index];
        final keywordsInCategory = groupedMap[categoryName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Titre de la catégorie ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
              child: Text(
                categoryName,
                style: AppTextStyles.sectionTitle(color: AppColors.primaryShade800),
              ),
            ),
            
            // --- Liste des termes dans cette catégorie ---
            // On utilise un Column plutôt qu'un ListView.builder imbriqué
            // car la liste externe est déjà scrollable.
            ...keywordsInCategory.map((keyword) {
              return _buildKeywordTile(keyword);
            }),
          ],
        );
      },
    );
  }

  // --- NOUVEAU WIDGET (Factorisé) : La ListTile d'un mot-clé ---
  Widget _buildKeywordTile(Keyword keyword) {
    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.4),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: AppColors.primaryShade800.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          Icons.auto_stories_outlined,
          color: AppColors.textPrimary.withValues(alpha: 0.7),
        ),
        title: Text(
          keyword.term,
          style: AppTextStyles.cinzel(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        splashColor: Colors.yellow.withValues(alpha: 0.1),
        onTap: () {
          context.push(AppRoutes.glossaryDetail, extra: keyword);
        },
      ),
    );
  }
}
