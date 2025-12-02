// Fichier : lib/widgets/decks/deck_suggestions_tab.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../services/edhrec_service.dart';
import '../../pages/cards/card_detail_page.dart';

class DeckSuggestionsTab extends StatefulWidget {
  final Deck deck;

  const DeckSuggestionsTab({
    super.key,
    required this.deck,
  });

  @override
  State<DeckSuggestionsTab> createState() => _DeckSuggestionsTabState();
}

class _DeckSuggestionsTabState extends State<DeckSuggestionsTab> {
  final EdhrecService _edhrecService = EdhrecService();
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  Future<void> _loadSuggestions() async {
    if (widget.deck.commanderScryfallId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Définissez d'abord un Commandant !")));
      return;
    }

    setState(() => _isLoading = true);

    String commanderName = "";
    try {
      final cmdCard = widget.deck.mainboard.firstWhere((c) => c.scryfallId == widget.deck.commanderScryfallId);
      commanderName = cmdCard.name;
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commandant introuvable dans le deck.")));
      return;
    }

    final results = await _edhrecService.getRecommendations(commanderName);
    
    final Set<String> deckCardNames = widget.deck.mainboard.map((c) => c.name.toLowerCase()).toSet();
    final filtered = results.where((name) => !deckCardNames.contains(name.toLowerCase())).toList();

    if (mounted) {
      setState(() {
        _suggestions = filtered.take(50).toList(); 
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deck.commanderScryfallId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text("Aucun Commandant défini.", style: GoogleFonts.cinzel(color: Colors.white70)),
          ],
        ),
      );
    }

    if (!_hasLoaded) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _loadSuggestions,
          icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Icon(Icons.auto_awesome),
          label: Text(_isLoading ? "Analyse en cours..." : "Suggestions (EDHRec)", style: GoogleFonts.cinzel()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(child: Text("Aucune suggestion trouvée.", style: GoogleFonts.cinzel(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final cardName = _suggestions[index];
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.lightbulb_outline, color: Colors.yellow),
            title: Text(cardName, style: GoogleFonts.cinzel(color: Colors.white)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: cardName)));
            },
          ),
        );
      },
    );
  }
}