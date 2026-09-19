// Fichier : lib/widgets/cards/versions_selector_sheet.dart
// Migre de http vers ScryfallApiService (Sprint 6)

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_print.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/scryfall_api_service.dart';
import '../../providers/service_providers.dart';
import '../../utils/price_helper.dart';

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

  /// JSON Scryfall brut de chaque version, indexe par identifiant de tirage.
  /// Conserve pour pouvoir ecrire le tirage CHOISI dans le cache
  /// `card_prints` : [ScryfallCard] a perdu en route des champs dont le cache
  /// a besoin (`printed_text` notamment). Seule la version selectionnee est
  /// mise en cache -- pas les deux cents impressions listees.
  final Map<String, Map<String, dynamic>> _rawVersions = {};

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
        _errorMessage = 'Impossible de trouver les autres versions (Oracle ID manquant).';
      });
      return;
    }

    try {
      final data = await _apiService.searchCards(
        'oracleid:${widget.oracleId}',
        unique: 'prints',
        includeMultilingual: true,
        order: 'released',
        dir: 'desc',
      );
      final List<dynamic> dataList = data['data'] ?? [];

      final rawByCardId = <String, Map<String, dynamic>>{};
      for (final json in dataList) {
        final map = json as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id != null) rawByCardId[id] = map;
      }

      if (mounted) {
        setState(() {
          _versions = dataList.map((json) => ScryfallCard.fromJson(json)).toList();
          _rawVersions
            ..clear()
            ..addAll(rawByCardId);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur réseau : $e';
        });
      }
    }
  }

  /// Ecrit le tirage choisi dans le cache, sans jamais lever ni bloquer la
  /// fermeture de la feuille.
  void _cacheSelectedPrint(String cardId) {
    final raw = _rawVersions[cardId];
    if (raw == null) return;
    final resolver = ref.read(cardResolverProvider);
    unawaited(resolver.cachePrintFromJson(raw).catchError((Object e) {
      log('Mise en cache du tirage choisi impossible ($cardId): $e',
          name: 'VersionsSelectorSheet');
      return ResolvedPrint.fromJson(raw);
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.primaryShade800, width: 2)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Versions & Artworks', style: AppTextStyles.pageTitle(fontSize: 20)),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: AppColors.borderMedium, height: 1),

          // Liste des versions
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage, style: AppTextStyles.text(color: AppColors.error)))
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
                              // La version choisie entre dans le cache
                              // `card_prints` : c'est le tirage que
                              // l'utilisateur va posseder. Sans cette
                              // ecriture, elle n'aurait jamais de ligne
                              // `card_prints` (le backfill de reprise ne
                              // s'execute qu'une fois dans la vie de l'app)
                              // et resterait invisible pour `resolveDisplay`
                              // comme pour `enqueueOwnedCardsForLanguage`.
                              // Non attendue et sans effet en cas de panne :
                              // le choix de version ne doit pas dependre de
                              // l'ecriture d'un cache.
                              _cacheSelectedPrint(card.id);
                              widget.onVersionSelected(card);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: isCurrent ? Border.all(color: Colors.green.shade400, width: 3) : null,
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.overlayMedium,
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
                                        errorBuilder: (_, _, _) => const Center(child: Icon(Icons.image_not_supported, color: AppColors.textPrimary)),
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
                                          style: AppTextStyles.bold(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '#${card.collectorNumber} • ${card.lang.toUpperCase()}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                        ),
                                        const SizedBox(height: 4),
                                        // Prix
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              PriceHelper.formatCompact(card.prices),
                                              style: AppTextStyles.bold(),
                                            ),
                                            if (PriceHelper.rawPrice(card.prices, isFoil: true) != null)
                                              Text(
                                                PriceHelper.formatCompact(card.prices, isFoil: true),
                                                style: AppTextStyles.bold(color: Colors.amber.shade300, fontSize: 11),
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
