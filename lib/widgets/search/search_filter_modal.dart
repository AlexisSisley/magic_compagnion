// Fichier : lib/widgets/search/search_filter_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/search_filters.dart';

class SearchFilterModal extends StatefulWidget {
  final SearchFilters initialFilters;

  const SearchFilterModal({
    super.key,
    required this.initialFilters,
  });

  @override
  State<SearchFilterModal> createState() => _SearchFilterModalState();
}

class _SearchFilterModalState extends State<SearchFilterModal> {
  // État local de la modale
  late TextEditingController _setController;
  late String? _selectedType;
  late Set<String> _selectedColors;

  final List<String> _cardTypes = [
    'Creature', 'Instant', 'Sorcery', 'Artifact',
    'Enchantment', 'Land', 'Planeswalker'
  ];
  final Map<String, String> _colorSymbols = {
    'W': 'W', 'U': 'U', 'B': 'B', 'R': 'R', 'G': 'G', 'C': 'C'
  };

  @override
  void initState() {
    super.initState();
    // Initialise l'état local avec les filtres actuels
    _setController = TextEditingController(text: widget.initialFilters.setCode);
    _selectedType = widget.initialFilters.cardType;
    _selectedColors = Set.from(widget.initialFilters.colors);
  }

  @override
  void dispose() {
    _setController.dispose();
    super.dispose();
  }

  // Fonction pour renvoyer les filtres à la page de recherche
  void _applyFilters() {
    final newFilters = SearchFilters(
      setCode: _setController.text.trim().isEmpty ? null : _setController.text.trim(),
      cardType: _selectedType,
      colors: _selectedColors,
    );
    // Renvoie le nouvel objet SearchFilters à la page précédente
    Navigator.pop(context, newFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 1. Ce Padding gère la montée du clavier
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        // 2. C'est le fond coloré de la modale
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withAlpha(240),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        
        // 3. --- CORRECTION ---
        // Ce Padding interne gère le contenu ET la barre de navigation
        child: Padding(
          padding: EdgeInsets.only(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            // Ajoute la hauteur de la barre de navigation (viewPadding)
            // au padding normal de 16.0
            bottom: MediaQuery.of(context).viewPadding.bottom + 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // S'adapte au contenu
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filtres avancés',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white24, height: 32),
              
              // ... (Le reste des champs TextField, Dropdown, etc. est inchangé) ...
              TextField(
                controller: _setController,
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  hintText: 'Code extension (ex: mkm, woe...)',
                  icon: Icons.collections_bookmark_outlined,
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedType,
                hint: Text(
                  'Type de carte (ex: Creature...)',
                  style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14),
                ),
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14),
                dropdownColor: const Color(0xFF1A1A1A),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                decoration: _buildInputDecoration(
                  hintText: '',
                  icon: Icons.category_outlined,
                ).copyWith(
                   suffixIcon: _selectedType == null ? null : IconButton(
                      icon: const Icon(Icons.clear, size: 20, color: Colors.white54),
                      onPressed: () => setState(() => _selectedType = null),
                    ),
                ),
                items: _cardTypes.map((String type) {
                  return DropdownMenuItem<String>(value: type, child: Text(type));
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedType = newValue);
                },
              ),
              const SizedBox(height: 16),

              _buildColorFilters(),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Appliquer les filtres',
                  style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper pour la décoration des champs
  InputDecoration _buildInputDecoration({required String hintText, required IconData icon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      filled: true,
      fillColor: Colors.black.withAlpha(140),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  // Helper pour les filtres de couleur
  Widget _buildColorFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Couleurs (contient au moins)',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center, // Centre les icônes
          spacing: 12.0,
          children: _colorSymbols.keys.map((color) {
            final bool isSelected = _selectedColors.contains(color);
            final String symbol = _colorSymbols[color]!;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedColors.remove(color);
                  } else {
                    _selectedColors.add(color);
                  }
                });
              },
              child: Opacity(
                opacity: isSelected ? 1.0 : 0.4,
                child: Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.yellow.withAlpha(100) : Colors.transparent,
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black.withAlpha(150),
                    child: SvgPicture.network(
                      'https://svgs.scryfall.io/card-symbols/$symbol.svg',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}