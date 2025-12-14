// Fichier : lib/widgets/decks/deck_card_title.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';

// ==========================================
// 1. VUE LISTE CLASSIQUE (Ligne horizontale)
// ==========================================
class DeckCardTile extends StatelessWidget {
  final DeckCard card;
  final ScryfallCard? scryfallCard;
  final bool isCommander;
  final bool isInCollection;
  final VoidCallback? onTap;
  final VoidCallback? onMore; // <--- REMPLACE onPlus/onMinus

  const DeckCardTile({
    super.key,
    required this.card,
    required this.scryfallCard,
    this.isCommander = false,
    required this.isInCollection,
    this.onTap,
    required this.onMore, // Requis maintenant
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = scryfallCard?.smallImageUrl;
    final price = scryfallCard?.prices['eur'];

    return Card(
      color: Colors.black.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
        onTap: onTap,
        onLongPress: onMore, // Long press ouvre aussi le menu par confort
        // Miniature à gauche
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: (imageUrl != null)
                  ? Image.network(imageUrl, width: 40, height: 56, fit: BoxFit.cover,
                      errorBuilder: (ctx, e, s) => const Icon(Icons.image_not_supported, size: 40))
                  : Container(width: 40, height: 56, color: Colors.grey.shade800,
                      child: const Icon(Icons.image_not_supported, color: Colors.white30)),
            ),
            if (isInCollection)
              Positioned(bottom: 0, right: 0, child: Container(decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.green, size: 16))),
            if (card.isFoil)
              Positioned(top: 0, right: 0, child: Container(decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: const Icon(Icons.star, color: Colors.amber, size: 12))),
          ],
        ),
        // Nom et Quantité
        title: Row(
          children: [
            Text('${card.quantity}x', style: GoogleFonts.cinzel(color: card.isFoil ? Colors.amber : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(child: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 15), overflow: TextOverflow.ellipsis)),
            
            // --- INDICATEUR PROXY ---
            if (card.proxyQuantity > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade700,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white38)
                ),
                child: Text(
                  'P:${card.proxyQuantity}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            
            if (isCommander) const Padding(padding: EdgeInsets.only(left: 4.0), child: Icon(Icons.shield, color: Colors.yellow, size: 16)),
          ],
        ),
        // Coût de mana, Prix, Tags
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ManaHelper.buildManaCostRow(scryfallCard?.manaCost),
                const SizedBox(width: 8),
                if (price != null) Text('$price €', style: TextStyle(color: Colors.yellow.shade700, fontSize: 12)),
              ],
            ),
            if (card.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Wrap(
                  spacing: 4,
                  children: card.tags.take(3).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                    child: Text(t, style: const TextStyle(fontSize: 8, color: Colors.blueAccent)),
                  )).toList(),
                ),
              )
          ],
        ),
        // NOUVEAU : Menu "3 petits points"
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          onPressed: onMore,
        ),
      ),
    );
  }
}

// ==========================================
// 2. VUE GRILLE (Grande image, contrôles bas)
// ==========================================
class DeckCardGridTile extends StatelessWidget {
  final DeckCard card;
  final ScryfallCard? scryfallCard;
  final bool isCommander;
  final bool isInCollection;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DeckCardGridTile({
    super.key,
    required this.card,
    required this.scryfallCard,
    this.isCommander = false,
    required this.isInCollection,
    required this.onPlus,
    required this.onMinus,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = scryfallCard?.imageUrl ?? scryfallCard?.smallImageUrl;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isCommander ? Colors.yellow.shade700 : (card.isFoil ? Colors.amber.withOpacity(0.5) : Colors.white12),
            width: isCommander ? 2 : 1,
          ),
        ),
        color: Colors.black.withOpacity(0.6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- 1. Image de fond ---
            (imageUrl != null)
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter, 
                    errorBuilder: (ctx, e, s) => Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white24))),
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: Center(child: Text(card.name, textAlign: TextAlign.center, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12))),
                  ),
            
            // Foil Effect
            if (card.isFoil)
              Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight))),

            // Gradient noir en bas
            Positioned(
              bottom: 0, left: 0, right: 0, height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.95), Colors.transparent],
                  ),
                ),
              ),
            ),

            // --- INDICATEUR PROXY ---
            if (card.proxyQuantity > 0)
              Positioned(
                top: 30, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade800, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                  child: Text(
                    'P',
                    style: GoogleFonts.cinzel(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // --- 2. Coût de Mana ---
            if (scryfallCard?.manaCost != null)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
                  child: ManaHelper.buildManaCostRow(scryfallCard!.manaCost),
                ),
              ),

            // --- 3. Indicateur Collection ---
            if (isInCollection)
              Positioned(
                top: 4, left: 4,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                ),
              ),

            // --- 4. Contrôles (Bas) ---
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InkWell(onTap: onMinus, child: const Icon(Icons.remove, color: Colors.white70, size: 20)),
                    Text('${card.quantity}', style: GoogleFonts.cinzel(color: card.isFoil ? Colors.amber : Colors.yellow.shade700, fontSize: 18, fontWeight: FontWeight.bold)),
                    InkWell(onTap: onPlus, child: const Icon(Icons.add, color: Colors.white70, size: 20)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManaHelper {
  static Widget buildManaCostRow(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) return const SizedBox.shrink();
    final RegExp manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');
    final List<String> symbols = manaPipRegex.allMatches(manaCost).map((match) => match.group(0)!).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: symbols.map((symbol) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0),
        child: _getManaIcon(symbol),
      )).toList(),
    );
  }

  static Widget _getManaIcon(String symbol) {
    final String cleanSymbol = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    final String svgUrl = 'https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg';
    return SvgPicture.network(
      svgUrl, height: 14, width: 14,
      placeholderBuilder: (context) => Text(symbol, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12)),
    );
  }
}