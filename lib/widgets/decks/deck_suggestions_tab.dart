// Fichier : lib/widgets/decks/deck_suggestions_tab.dart
// VERSION OPTIMISÉE : Suppression du goulot d'étranglement (Smart Match)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../router/app_router.dart';
import '../../services/edhrec_service.dart';
import '../../services/local_card_service.dart';
import '../../providers/service_providers.dart';

class DeckSuggestionsTab extends ConsumerStatefulWidget {
  final Deck deck;

  const DeckSuggestionsTab({
    super.key,
    required this.deck,
  });

  @override
  ConsumerState<DeckSuggestionsTab> createState() => _DeckSuggestionsTabState();
}

class _DeckSuggestionsTabState extends ConsumerState<DeckSuggestionsTab> {
  EdhrecService get _edhrecService => ref.read(edhrecServiceProvider);
  LocalCardService get _localCardService => ref.read(localCardServiceProvider);
  
  Map<String, List<ScryfallCard>> _suggestions = {};
  
  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    // On s'assure que la base est chargée
    if (!_localCardService.isLoaded) {
      _localCardService.loadLocalData();
    }
  }

  Future<void> _loadSuggestions() async {
    if (widget.deck.commanderScryfallId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Définissez d'abord un Commandant !")));
      return;
    }

    setState(() { _isLoading = true; });

    // Récupération du nom du commandant
    String commanderName = "";
    try {
      final allCards = [...widget.deck.mainboard, ...widget.deck.sideboard];
      // On essaie de trouver la carte dans le deck
      final cmdCard = allCards.firstWhere(
        (c) => c.scryfallId == widget.deck.commanderScryfallId,
        orElse: () => DeckCard(scryfallId: '', name: '', quantity: 0) // Fallback vide
      );
      
      if (cmdCard.name.isNotEmpty) {
        commanderName = cmdCard.name;
      } else {
        // Si pas trouvée dans le deck (cas rare), on cherche dans la base locale via l'ID
        final localCmd = _localCardService.getCardById(widget.deck.commanderScryfallId!);
        if (localCmd != null) commanderName = localCmd.name;
      }
    } catch (e) {
      // Ignorer
    }

    if (commanderName.isEmpty) {
       setState(() { _isLoading = false; });
       return;
    }

    // 1. Appel API EDHRec
    final resultsMap = await _edhrecService.getRecommendations(commanderName);
    
    // 2. Préparation du filtre (Cartes déjà possédées)
    final Set<String> deckCardNames = widget.deck.mainboard.map((c) => c.name.toLowerCase()).toSet();
    deckCardNames.addAll(widget.deck.sideboard.map((c) => c.name.toLowerCase()));

    // 3. Traitement Rapide (Sans Smart Match bloquant)
    Map<String, List<ScryfallCard>> enrichedMap = {};

    for (var entry in resultsMap.entries) {
      String category = entry.key;
      List<String> nameList = entry.value;
      List<ScryfallCard> cards = [];

      for (var name in nameList) {
        if (deckCardNames.contains(name.toLowerCase())) continue;

        // A. Recherche Exacte (Rapide - O(1))
        ScryfallCard? card = _localCardService.getCardByName(name);

        // NOTE : On a supprimé la Recherche Intelligente ici car elle est trop lente pour une boucle.
        // Si la carte n'est pas trouvée exactement, on passe direct au Fallback.

        // B. Fallback Virtuel
        card ??= ScryfallCard(
             id: 'edhrec_${name.hashCode}',
             oracleId: '', 
             name: name,
             imageUrl: '', // Sera géré par le widget d'affichage
             rulesText: '', 
             typeLine: 'Suggestion externe', 
             legalities: {}, 
             prices: {}, 
             lang: 'en', 
             colorIdentity: [], 
             setName: '', 
             setCode: '', 
             collectorNumber: '', 
             rarity: '', 
             purchaseUris: {}
        );
        
        cards.add(card);
      }

      if (cards.isNotEmpty) {
        enrichedMap[category] = cards;
      }
    }

    if (mounted) {
      setState(() {
        _suggestions = enrichedMap;
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deck.commanderScryfallId == null) {
      return Center(child: Text("Aucun Commandant défini.", style: GoogleFonts.cinzel(color: Colors.white70)));
    }

    if (!_hasLoaded) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _loadSuggestions,
          icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.auto_awesome),
          label: Text(_isLoading ? "Analyse EDHRec..." : "Obtenir les Suggestions", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _suggestions.keys.length,
      itemBuilder: (context, index) {
        final category = _suggestions.keys.elementAt(index);
        final cards = _suggestions[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                category, 
                style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...cards.take(10).map((card) => _buildRichSuggestionTile(card)).toList(),
            
            if (cards.length > 10)
               Padding(
                 padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                 child: Text("... et ${cards.length - 10} autres", style: const TextStyle(color: Colors.white30, fontSize: 12, fontStyle: FontStyle.italic)),
               )
          ],
        );
      },
    );
  }

  Widget _buildRichSuggestionTile(ScryfallCard card) {
    final String? imageUrl = card.smallImageUrl ?? (card.imageUrl.isNotEmpty ? card.imageUrl : null);
    final String price = card.prices['eur'] ?? '--';
    final bool isFallback = card.id.startsWith('edhrec_');

    return Card(
      color: Colors.black.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onTap: () {
           context.push(AppRoutes.cardDetail, extra: {'cardName': card.name});
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? Image.network(
                  imageUrl, 
                  width: 40, height: 56, fit: BoxFit.cover,
                  errorBuilder: (c,e,s)=> Container(width: 40, height: 56, color: Colors.grey.shade800, child: const Icon(Icons.broken_image, color: Colors.white24))
                )
              : Container(width: 40, height: 56, color: Colors.grey.shade800, child: const Icon(Icons.search, color: Colors.white24)),
        ),
        title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
        subtitle: isFallback
          ? const Text("Données locales manquantes - Cliquez pour chercher", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontStyle: FontStyle.italic))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (card.manaCost != null) _ManaDisplay(manaCost: card.manaCost!),
                    const SizedBox(width: 8),
                    Expanded(child: Text(card.typeLine, style: const TextStyle(color: Colors.white54, fontSize: 10), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (card.setCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
                        child: Text(card.setCode.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    if (!isFallback)
                      Text("$price €", style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                )
              ],
            ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
          onPressed: () {
             context.push(AppRoutes.cardDetail, extra: {'cardName': card.name});
          },
        ),
      ),
    );
  }
}

class _ManaDisplay extends StatelessWidget {
  final String manaCost;
  const _ManaDisplay({required this.manaCost});

  @override
  Widget build(BuildContext context) {
    final RegExp regex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');
    final matches = regex.allMatches(manaCost);
    if (matches.isEmpty) return const SizedBox();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: matches.map((m) {
        final symbol = m.group(1)?.replaceAll('/', '') ?? ''; 
        final cleanSymbol = symbol.toUpperCase();
        return Padding(
          padding: const EdgeInsets.only(right: 1.0),
          child: SvgPicture.network(
            'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg',
            width: 12, height: 12,
            placeholderBuilder: (_) => Text(symbol, style: const TextStyle(fontSize: 10, color: Colors.white)),
          ),
        );
      }).toList(),
    );
  }
}