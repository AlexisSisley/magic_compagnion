// Fichier : lib/widgets/collection/collection_sets_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_set_model.dart';
import '../../services/set_service.dart';
import '../../services/local_card_service.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../pages/collections/set_detail_page.dart';

class CollectionSetsTab extends StatefulWidget {
  final List<DeckCard> collection;
  const CollectionSetsTab({super.key, required this.collection});

  @override
  State<CollectionSetsTab> createState() => _CollectionSetsTabState();
}

class _CollectionSetsTabState extends State<CollectionSetsTab> {
  final SetService _setService = SetService();
  final LocalCardService _localCardService = LocalCardService();
  
  List<ScryfallSet> _sets = [];
  Map<String, int> _ownedCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // On recharge quand la collection change (via didUpdateWidget)
  @override
  void didUpdateWidget(CollectionSetsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.length != widget.collection.length) {
      _calculate();
    }
  }

  Future<void> _load() async {
    final sets = await _setService.getAllSets();
    final validSets = sets.where((s) => s.cardCount > 0).toList();
    validSets.sort((a, b) => (b.releaseDate ?? DateTime(1900)).compareTo(a.releaseDate ?? DateTime(1900)));
    
    if (mounted) {
      setState(() { _sets = validSets; _isLoading = false; });
      _calculate();
    }
  }

  void _calculate() {
    Map<String, int> counts = {};
    // Nécessite accès aux données locales pour mapper ID -> SetCode
    for (var card in widget.collection) {
      final local = _localCardService.getCardById(card.scryfallId);
      if (local != null) {
        counts[local.setCode] = (counts[local.setCode] ?? 0) + 1;
      }
    }
    setState(() => _ownedCounts = counts);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: _sets.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final set = _sets[index];
        final int owned = _ownedCounts[set.code] ?? 0;
        final int total = set.cardCount;
        final double progress = total > 0 ? (owned / total) : 0.0;

        return Card(
          color: Colors.white.withOpacity(0.05),
          child: InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => SetDetailPage(
                  set: set, 
                  collectionService: CollectionService(), 
                  wishlistService: WishlistService()
                )
              ));
            },
            child: Column(
              children: [
                ListTile(
                  leading: SizedBox(width: 40, child: SvgPicture.network(set.iconSvgUri ?? '', colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                  title: Text(set.name, style: GoogleFonts.cinzel(color: Colors.white)),
                  subtitle: Text("${owned}/${total}", style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.black,
                    color: progress == 1.0 ? Colors.green : Colors.amber,
                    minHeight: 4,
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}