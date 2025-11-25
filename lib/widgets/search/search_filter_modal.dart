// Fichier : lib/widgets/search/search_filter_modal.dart
// VERSION MISE À JOUR : Interface Pro avec CMC et Rareté

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
  late TextEditingController _setController;
  late String? _selectedType;
  late Set<String> _selectedColors;
  
  // Nouveaux états
  late RangeValues _cmcRange;
  late String? _selectedRarity;

  final List<String> _cardTypes = [
    'Creature', 'Instant', 'Sorcery', 'Artifact',
    'Enchantment', 'Land', 'Planeswalker', 'Battle'
  ];
  final Map<String, String> _colorSymbols = {
    'W': 'W', 'U': 'U', 'B': 'B', 'R': 'R', 'G': 'G', 'C': 'C'
  };
  
  final List<String> _rarities = ['common', 'uncommon', 'rare', 'mythic'];

  @override
  void initState() {
    super.initState();
    _setController = TextEditingController(text: widget.initialFilters.setCode);
    _selectedType = widget.initialFilters.cardType;
    _selectedColors = Set.from(widget.initialFilters.colors);
    
    // Init CMC (Défaut 0-10)
    double min = widget.initialFilters.minCmc ?? 0;
    double max = widget.initialFilters.maxCmc ?? 10;
    _cmcRange = RangeValues(min, max);
    
    _selectedRarity = widget.initialFilters.rarity;
  }

  @override
  void dispose() {
    _setController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    // Si la plage est complète (0-10), on envoie null pour ne pas filtrer
    double? finalMin = _cmcRange.start > 0 ? _cmcRange.start : null;
    double? finalMax = _cmcRange.end < 10 ? _cmcRange.end : null;

    final newFilters = SearchFilters(
      setCode: _setController.text.trim().isEmpty ? null : _setController.text.trim(),
      cardType: _selectedType,
      colors: _selectedColors,
      minCmc: finalMin,
      maxCmc: finalMax,
      rarity: _selectedRarity,
    );
    Navigator.pop(context, newFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withAlpha(245),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: 16.0, left: 16.0, right: 16.0,
            bottom: MediaQuery.of(context).viewPadding.bottom + 16.0,
          ),
          child: SingleChildScrollView( // Scrollable si ça dépasse sur petits écrans
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filtres avancés', textAlign: TextAlign.center, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, height: 24),
                
                // --- Types & Sets ---
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        hint: Text('Type...', style: GoogleFonts.cinzel(color: Colors.white54)),
                        dropdownColor: const Color(0xFF2A2A2A),
                        decoration: _buildInputDecoration(hintText: '', icon: Icons.category),
                        items: _cardTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (v) => setState(() => _selectedType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _setController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(hintText: 'Code Set', icon: Icons.library_books),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Couleurs ---
                Text('Couleurs (Inclure)', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                _buildColorFilters(),
                const SizedBox(height: 16),

                // --- Rareté ---
                Text('Rareté', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _rarities.map((r) {
                    final bool isSelected = _selectedRarity == r;
                    Color rarityColor;
                    switch(r) {
                      case 'common': rarityColor = Colors.white; break;
                      case 'uncommon': rarityColor = Colors.blue.shade300; break;
                      case 'rare': rarityColor = Colors.amber; break;
                      case 'mythic': rarityColor = Colors.orange.shade800; break;
                      default: rarityColor = Colors.grey;
                    }
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRarity = isSelected ? null : r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? rarityColor.withOpacity(0.2) : Colors.black45,
                          border: Border.all(color: isSelected ? rarityColor : Colors.white24),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          r[0].toUpperCase() + r.substring(1),
                          style: TextStyle(
                            color: isSelected ? rarityColor : Colors.white54,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // --- Coût de Mana (CMC) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Coût Mana (CMC)', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14)),
                    Text(
                      '${_cmcRange.start.round()} - ${_cmcRange.end >= 10 ? "10+" : _cmcRange.end.round()}',
                      style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                RangeSlider(
                  values: _cmcRange,
                  min: 0, max: 10,
                  divisions: 10,
                  activeColor: Colors.yellow.shade800,
                  inactiveColor: Colors.white24,
                  labels: RangeLabels('${_cmcRange.start.round()}', '${_cmcRange.end.round()}'),
                  onChanged: (values) => setState(() => _cmcRange = values),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('Appliquer', style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText, required IconData icon}) {
    return InputDecoration(
      hintText: hintText, hintStyle: const TextStyle(color: Colors.white30),
      prefixIcon: Icon(icon, color: Colors.white54, size: 18),
      filled: true, fillColor: Colors.black45,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }

  Widget _buildColorFilters() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12.0,
      children: _colorSymbols.keys.map((color) {
        final bool isSelected = _selectedColors.contains(color);
        final String symbol = _colorSymbols[color]!;
        return GestureDetector(
          onTap: () => setState(() => isSelected ? _selectedColors.remove(color) : _selectedColors.add(color)),
          child: Opacity(
            opacity: isSelected ? 1.0 : 0.3,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.black,
              child: SvgPicture.network('https://svgs.scryfall.io/card-symbols/$symbol.svg', width: 16),
            ),
          ),
        );
      }).toList(),
    );
  }
}