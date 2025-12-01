// Fichier : lib/widgets/collection/quick_add_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/local_card_service.dart';

class QuickAddView extends StatefulWidget {
  final String query;
  final List<DeckCard> collection;
  final Function(ScryfallCard) onAdd;
  final Function(ScryfallCard) onRemove;

  const QuickAddView({
    super.key,
    required this.query,
    required this.collection,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<QuickAddView> createState() => _QuickAddViewState();
}

class _QuickAddViewState extends State<QuickAddView> {
  final LocalCardService _localService = LocalCardService();
  List<ScryfallCard> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void didUpdateWidget(QuickAddView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _onSearchChanged();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search());
  }

  Future<void> _search() async {
    if (widget.query.length < 3) return;
    setState(() => _isLoading = true);
    
    try {
      final res = await _localService.searchCards(query: widget.query);
      if (mounted) setState(() { _results = res.take(20).toList(); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty && widget.query.length >= 3) return const Center(child: Text("Aucun résultat", style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final card = _results[index];
        final existing = widget.collection.firstWhere(
          (c) => c.scryfallId == card.id, 
          orElse: () => DeckCard(scryfallId: '', name: '', quantity: 0)
        );

        return Card(
          color: Colors.black45,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Image.network(card.smallImageUrl ?? '', width: 30, errorBuilder: (_,__,___)=>const Icon(Icons.image)),
            title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white)),
            subtitle: Text(card.setCode.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () { widget.onRemove(card); setState((){}); }, // Force rebuild pour update count visual
                ),
                Text("${existing.quantity}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () { widget.onAdd(card); setState((){}); },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}