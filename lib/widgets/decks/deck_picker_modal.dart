// Fichier : lib/widgets/decks/deck_picker_modal.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/deck_service.dart';

class DeckPickerModal extends StatefulWidget {
  final DeckService deckService;
  final ScryfallCard cardToAdd;
  final Function(String deckName, String cardName) onCardAdded;

  const DeckPickerModal({
    super.key,
    required this.deckService,
    required this.cardToAdd,
    required this.onCardAdded,
  });

  @override
  State<DeckPickerModal> createState() => _DeckPickerModalState();
}

class _DeckPickerModalState extends State<DeckPickerModal> {
  late TextEditingController _newDeckController;
  List<Deck> _decks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _newDeckController = TextEditingController();
    _loadDecks();
  }

  @override
  void dispose() {
    _newDeckController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    setState(() { _isLoading = true; });
    final decks = await widget.deckService.loadDecks();
    if (mounted) {
      setState(() {
        _decks = decks;
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewDeck() async {
    final String deckName = _newDeckController.text.trim();
    if (deckName.isNotEmpty) {
      await widget.deckService.createNewDeck(deckName);
      
      // Sécurité pour le contexte après un await
      if (!mounted) return;
      
      _newDeckController.clear();
      FocusScope.of(context).unfocus();
      _loadDecks();
    }
  }

  Future<void> _addCardToDeck(Deck deck) async {
    // CORRECTION : On utilise la nouvelle méthode générique
    await widget.deckService.upsertCardInDeck(
      deckId: deck.id,
      scryfallId: widget.cardToAdd.id,
      cardName: widget.cardToAdd.name,
      quantityToAdd: 1,
      board: DeckBoard.main, // Ajout par défaut dans le Mainboard
    );

    // Sécurité contextuelle
    if (mounted) {
      Navigator.pop(context);
      widget.onCardAdded(deck.name, widget.cardToAdd.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withAlpha((0.95 * 255).round()),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajouter à un Deck',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newDeckController,
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: '...ou créer un nouveau deck',
                  hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.yellow),
                    onPressed: _createNewDeck,
                  ),
                  filled: true,
                  fillColor: Colors.black.withAlpha((0.5 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) => _createNewDeck(),
              ),
              const Divider(color: Colors.white24, height: 32),
              Flexible(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _decks.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun deck. Créez-en un ci-dessus.',
                              style: GoogleFonts.cinzel(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _decks.length,
                            itemBuilder: (context, index) {
                              final deck = _decks[index];
                              return ListTile(
                                leading: const Icon(Icons.style_outlined, color: Colors.white70),
                                title: Text(
                                  deck.name,
                                  style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18),
                                ),
                                onTap: () => _addCardToDeck(deck),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}