// Fichier : lib/widgets/cards/versions_selector_sheet.dart
// Migre de http vers ScryfallApiService (Sprint 6)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/scryfall_api_service.dart';
import '../../providers/service_providers.dart';

class VersionsSelectorSheet extends ConsumerStatefulWidget {
  final String oracleId;
  final String currentCardId;
  final Function(ScryfallCard) onVersionSelected;

  const VersionsSelectorSheet({
    super.key,
    required this.oracleId,
    required this.currentCardId,
    required this.onVersionSelected,
  });

  @override
  ConsumerState<VersionsSelectorSheet> createState() => _VersionsSelectorSheetState();
}

class _VersionsSelectorSheetState extends ConsumerState<VersionsSelectorSheet> {
  ScryfallApiService get _apiService => ref.read(scryfallApiServiceProvider);

  List<ScryfallCard> _versions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPrints();
  }

  Future<void> _fetchPrints() async {
    if (widget.oracleId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Impossible de trouver les autres versions (Oracle ID manquant).";
      });
      return;
    }

    try {
      final data = await _apiService.searchCards(
        'oracle_id:${widget.oracleId}',
        unique: 'prints',
        order: 'released',
        dir: 'desc',
      );
      final List<dynamic> dataList = data['data'] ?? [];

      if (mounted) {
        setState(() {
          _versions = dataList.map((json) => ScryfallCard.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur réseau : $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Versions & Artworks", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // Liste des versions
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage, style: GoogleFonts.cinzel(color: Colors.red)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _versions.length,
                        itemBuilder: (context, index) {
                          final card = _versions[index];
                          final bool isCurrent = card.id == widget.currentCardId;

                          return GestureDetector(
                            onTap: () {
                              widget.onVersionSelected(card);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: isCurrent ? Border.all(color: Colors.green.shade400, width: 3) : null,
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black45,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Image
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                      child: Image.network(
                                        card.imageUrl.isNotEmpty ? card.imageUrl : (card.smallImageUrl ?? ''),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_,__,___) => const Center(child: Icon(Icons.image_not_supported, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                  // Infos
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.setName,
                                          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "#${card.collectorNumber} • ${card.lang.toUpperCase()}",
                                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                                        ),
                                        const SizedBox(height: 4),
                                        // Prix
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              card.prices['eur'] != null ? "${card.prices['eur']}€" : "--",
                                              style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            if (card.prices['eur_foil'] != null)
                                              Text(
                                                "${card.prices['eur_foil']}€",
                                                style: GoogleFonts.cinzel(color: Colors.amber.shade300, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
