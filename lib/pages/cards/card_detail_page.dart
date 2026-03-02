// Fichier : lib/pages/cards/card_detail_page.dart
// VERSION REFACTOREE : Logique metier extraite dans CardDetailController

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTS LOCAUX
import 'package:magic_companion/widgets/decks/deck_picker_modal.dart';
import '../../router/app_router.dart';

import '../../controllers/card_detail_controller.dart';
import '../../data/glossary_data.dart';
import '../../widgets/cards/versions_selector_sheet.dart';

class RecognitionResultPage extends ConsumerStatefulWidget {
  final String? imagePath;
  final String? cardName;
  final bool isContinuousScan;

  const RecognitionResultPage({super.key, this.imagePath, this.cardName, this.isContinuousScan = false});

  @override
  ConsumerState<RecognitionResultPage> createState() => _RecognitionResultPageState();
}

class _RecognitionResultPageState extends ConsumerState<RecognitionResultPage> {
  final TextEditingController _searchController = TextEditingController();
  final RegExp _manaSymbolRegex = RegExp(r'(\{.*?\})');

  late final CardDetailParams _params;

  @override
  void initState() {
    super.initState();
    _params = CardDetailParams(
      imagePath: widget.imagePath,
      cardName: widget.cardName,
      isContinuousScan: widget.isContinuousScan,
    );
    if (widget.cardName != null) {
      _searchController.text = widget.cardName!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardDetailControllerProvider(_params));
    final controller = ref.read(cardDetailControllerProvider(_params).notifier);

    // Calcul de l'icône Collection dynamique
    IconData collIcon = Icons.inventory_2_outlined;
    Color collColor = AppColors.textPrimary;
    if (state.collectionNormalCount > 0 || state.collectionFoilCount > 0) {
      collIcon = Icons.inventory_2;
      collColor = Colors.green.shade400;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(state.pageState == ResultPageState.selection ? 'Choisissez la carte' : 'Détail Carte', style: AppTextStyles.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.textOnPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (state.pageState == ResultPageState.success) ...[
            if (widget.isContinuousScan)
              TextButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.camera_alt, color: AppColors.primary, size: 18),
                label: const Text('Suivante', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1)),
              ),
            IconButton(icon: const Icon(Icons.style, color: AppColors.textPrimary), onPressed: () => _showVersionsModal(state, controller)),
            IconButton(
              icon: Icon(state.inWishlist ? Icons.star : Icons.star_border_outlined, color: state.inWishlist ? Colors.blue.shade400 : AppColors.textPrimary),
              onPressed: () => _openWishlistManager(controller),
            ),
            IconButton(
              icon: Icon(collIcon, color: collColor),
              onPressed: () => _openCollectionManager(state, controller),
            )
          ]
        ],
      ),
      body: _buildContent(state, controller),
      floatingActionButton: state.pageState == ResultPageState.success
          ? FloatingActionButton(onPressed: () => _showDeckPicker(state, controller), backgroundColor: AppColors.primaryShade800, child: const Icon(Icons.add_to_photos_outlined))
          : null,
    );
  }

  Widget _buildContent(CardDetailState state, CardDetailController controller) {
    final mediaQuery = MediaQuery.of(context);

    switch (state.pageState) {
      case ResultPageState.loading:
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(state.statusMessage, style: AppTextStyles.cinzel())]));

      case ResultPageState.selection:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Plusieurs correspondances trouvées.\nVeuillez sélectionner la bonne carte :',
                style: AppTextStyles.subtitle(fontSize: 16), textAlign: TextAlign.center),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: state.candidates.length,
                separatorBuilder: (_, _) => const Divider(color: AppColors.borderLight),
                itemBuilder: (context, index) {
                  final card = state.candidates[index];
                  final imgUrl = card.smallImageUrl ?? card.imageUrl;
                  return Card(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    child: ListTile(
                      leading: imgUrl.isNotEmpty
                          ? Image.network(imgUrl, width: 40, fit: BoxFit.cover)
                          : const Icon(Icons.image, color: AppColors.borderMedium),
                      title: Text(card.name, style: AppTextStyles.bold()),
                      subtitle: Text('${card.typeLine}\n${card.setName} • ${card.collectorNumber}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                      onTap: () {
                        _searchController.text = card.name;
                        controller.selectCard(card);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );

      case ResultPageState.success:
        final foundCard = state.foundCard!;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0 + mediaQuery.padding.bottom + 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: AppColors.textOnPrimary.withValues(alpha: 0.4),
                elevation: 4.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: AppColors.primaryShade800.withValues(alpha: 0.6), width: 1)),
                child: Column(children: [
                    Image.network(foundCard.imageUrl, fit: BoxFit.fitWidth, errorBuilder: (c, e, s) => const SizedBox(height: 300, child: Center(child: Icon(Icons.broken_image, size: 50, color: AppColors.textPrimary)))),
                    Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
                          _buildManaCostRow(foundCard.manaCost),
                          const SizedBox(height: 8),
                          Text(foundCard.printedName ?? foundCard.name, style: AppTextStyles.pageTitle(), textAlign: TextAlign.center),
                          Text(foundCard.typeLine, style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 16, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                          if (state.collectionNormalCount > 0 || state.collectionFoilCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'Collection : ${state.collectionNormalCount} normal${state.collectionNormalCount > 1 ? 's' : ''}${state.collectionFoilCount > 0 ? ' + ${state.collectionFoilCount} foil${state.collectionFoilCount > 1 ? 's' : ''}' : ''}',
                                  style: AppTextStyles.bold(color: Colors.green.shade300, fontSize: 12),
                                ),
                              ),
                            ),
                    ]))
                ]),
              ),
              _buildInfoCard(title: 'Texte des règles', child: _buildClickableRulesText(foundCard.rulesText, foundCard.lang, controller)),
              _buildInfoCard(title: 'Prix & Marché', child: _buildPriceInfo(foundCard.prices)),
              _buildInfoCard(title: 'Légalité', child: _buildLegalities(foundCard.legalities)),
              _buildInfoCard(title: 'Décisions de Règles', child: _buildRulingsList(state)),
            ],
          ),
        );

      case ResultPageState.error:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.statusMessage, style: AppTextStyles.cinzel(color: Colors.red.shade300), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                style: AppTextStyles.cinzel(),
                decoration: InputDecoration(hintText: 'Nom de la carte', filled: true, fillColor: AppColors.borderLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                onSubmitted: (val) => controller.searchForCandidates(val),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => controller.searchForCandidates(_searchController.text), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade800), child: Text('Rechercher', style: AppTextStyles.cinzel())),
            ],
          ),
        );
    }
  }

  // --- GESTION COLLECTION (MODALE) ---
  void _openCollectionManager(CardDetailState state, CardDetailController controller) {
    if (state.foundCard == null) return;

    int tempNormal = state.collectionNormalCount;
    int tempFoil = state.collectionFoilCount;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                height: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gérer ma Collection', style: AppTextStyles.pageTitle(fontSize: 20)),
                    const SizedBox(height: 24),
                    _buildQuantityRow(
                      'Normal',
                      tempNormal,
                      AppColors.textPrimary,
                      () { setModalState(() => tempNormal = (tempNormal - 1).clamp(0, 99)); },
                      () { setModalState(() => tempNormal++); },
                    ),
                    const SizedBox(height: 16),
                    _buildQuantityRow(
                      'Foil (Brillant)',
                      tempFoil,
                      AppColors.amber,
                      () { setModalState(() => tempFoil = (tempFoil - 1).clamp(0, 99)); },
                      () { setModalState(() => tempFoil++); },
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await controller.saveCollection(
                            normalCount: tempNormal,
                            foilCount: tempFoil,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _showFeedback('Collection mise à jour', AppColors.success);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text('ENREGISTRER', style: AppTextStyles.bold()),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- GESTION WISHLIST (MODALE) ---
  void _openWishlistManager(CardDetailController controller) async {
    final targetListId = await _showWishlistSelector(controller);
    if (targetListId == null) return;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: Text('Ajouter à la Wishlist', style: AppTextStyles.cinzel()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Version Normale', style: TextStyle(color: AppColors.textPrimary)),
              leading: const Icon(Icons.style, color: AppColors.textPrimary),
              onTap: () async {
                await controller.addToWishlist(listId: targetListId, isFoil: false);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _showFeedback('Ajouté à la Wishlist (Normal)', AppColors.accent);
              },
            ),
            ListTile(
              title: const Text('Version Foil', style: TextStyle(color: AppColors.amber)),
              leading: const Icon(Icons.star, color: AppColors.amber),
              onTap: () async {
                await controller.addToWishlist(listId: targetListId, isFoil: true);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _showFeedback('Ajouté à la Wishlist (Foil)', AppColors.accent);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityRow(String label, int value, Color color, VoidCallback onMinus, VoidCallback onPlus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(label.contains('Foil') ? Icons.star : Icons.style, color: color),
              const SizedBox(width: 12),
              Text(label, style: AppTextStyles.bold(color: color, fontSize: 16)),
            ],
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.textMuted), onPressed: onMinus),
              SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.add_circle, color: AppColors.accentGreen), onPressed: onPlus),
            ],
          )
        ],
      ),
    );
  }

  Future<String?> _showWishlistSelector(CardDetailController controller) async {
    final wishlists = await controller.wishlistService.loadWishlists();
    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(padding: const EdgeInsets.all(16.0), child: Text('Choisir une Wishlist', style: AppTextStyles.sectionTitle())),
                  ListTile(
                    leading: const Icon(Icons.add_circle, color: AppColors.accentGreen),
                    title: Text('Créer une nouvelle liste', style: AppTextStyles.cinzel()),
                    onTap: () async {
                      final name = await _showCreateWishlistDialog(controller);
                      if (name != null && mounted) {
                        final newListId = await controller.createWishlist(name);
                        if (!context.mounted) return;
                        Navigator.pop(context, newListId);
                      }
                    },
                  ),
                  const Divider(color: AppColors.borderMedium),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: wishlists.length,
                      itemBuilder: (context, index) {
                        final list = wishlists[index];
                        return ListTile(
                          leading: const Icon(Icons.bookmark_border, color: AppColors.accent),
                          title: Text(list.name, style: const TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text('${list.totalCards} cartes', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          onTap: () => Navigator.pop(context, list.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showCreateWishlistDialog(CardDetailController controller) async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Nouvelle Liste', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Nom de la liste'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.isNotEmpty) {
                await controller.wishlistService.createWishlist(textController.text);
                if (c.mounted) Navigator.pop(c, textController.text);
              }
            },
            child: const Text('Créer'),
          )
        ],
      ),
    );
  }

  // --- HELPERS UI ---
  Widget _buildPriceInfo(Map<String, dynamic> prices) {
    final String priceEur = prices['eur'] ?? 'N/A';
    final String priceEurFoil = prices['eur_foil'] ?? 'N/A';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [Text('Normal', style: AppTextStyles.cinzel(color: AppColors.textSecondary)), Text('$priceEur €', style: AppTextStyles.pageTitle(fontSize: 20))]),
        Container(width: 1, height: 30, color: AppColors.borderMedium),
        Column(children: [Text('Foil (Brillant)', style: AppTextStyles.cinzel(color: Colors.amber.shade200)), Text('$priceEurFoil €', style: AppTextStyles.pageTitle(fontSize: 20))]),
      ],
    );
  }

  Widget _buildRulingsList(CardDetailState state) {
    if (state.isLoadingRulings) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (state.rulings.isEmpty) return Text('(Aucune décision)', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontStyle: FontStyle.italic));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: state.rulings.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.date, style: AppTextStyles.bold()), Text(r.comment, style: const TextStyle(color: AppColors.textPrimary))]))).toList());
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.4), elevation: 2, margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppColors.primaryShade800.withValues(alpha: 0.6))),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.cinzel(fontSize: 20, fontWeight: FontWeight.w600)), const Divider(color: AppColors.borderMedium), const SizedBox(height: 8), child])),
    );
  }

  Widget _buildLegalities(Map<String, String> legalities) {
    const formats = ['standard', 'commander', 'modern', 'pioneer'];
    return Wrap(spacing: 12, runSpacing: 8, children: formats.map((fmt) {
       final status = legalities[fmt] ?? 'not_legal';
       Color c = status == 'legal' ? AppColors.success : (status == 'banned' ? AppColors.error : AppColors.synergyNeutral);
       return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: c)), child: Text('${fmt[0].toUpperCase()}${fmt.substring(1)}', style: AppTextStyles.bold(color: c)));
    }).toList());
  }

  Future<void> _showVersionsModal(CardDetailState state, CardDetailController controller) async {
    if (state.foundCard == null) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.transparent,
      builder: (context) => VersionsSelectorSheet(oracleId: state.foundCard!.oracleId, currentCardId: state.foundCard!.id, onVersionSelected: (v) => controller.selectCard(v)),
    );
  }

  Future<void> _showDeckPicker(CardDetailState state, CardDetailController controller) async {
    if (state.foundCard == null) return;
    showModalBottomSheet(context: context, backgroundColor: AppColors.transparent, isScrollControlled: true, builder: (c) => DeckPickerModal(cardToAdd: state.foundCard!, deckService: controller.deckService, onCardAdded: (d, c) => _showFeedback('Ajouté au deck $d', AppColors.success)));
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: AppTextStyles.bold(color: AppColors.textOnPrimary)), backgroundColor: color, duration: const Duration(seconds: 1)));
  }

  InlineSpan _buildKeywordSpans(String textChunk, CardDetailController controller) {
    final List<String> words = textChunk.split(' ');
    final List<InlineSpan> spans = [];
    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      final Keyword? keyword = controller.findKeyword(word);
      if (keyword != null) {
        spans.add(TextSpan(text: '$word ', style: AppTextStyles.bold(color: Colors.blue.shade300).copyWith(decoration: TextDecoration.underline, decorationColor: Colors.blue.shade300), recognizer: TapGestureRecognizer()..onTap = () { context.push(AppRoutes.glossaryDetail, extra: keyword); }));
      } else {
        spans.add(TextSpan(text: '$word ', style: const TextStyle(color: AppColors.textPrimary, height: 1.4)));
      }
    }
    return TextSpan(children: spans);
  }

  Widget _buildClickableRulesText(String text, String lang, CardDetailController controller) {
    if (text.isEmpty) return Text('(Pas de texte)', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontStyle: FontStyle.italic));
    final List<InlineSpan> spans = [];
    text.splitMapJoin(_manaSymbolRegex, onMatch: (Match match) {
        final String symbol = match.group(0)!;
        spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1.0), child: _getManaIcon(symbol))));
        return '';
      }, onNonMatch: (String nonMatch) { spans.add(_buildKeywordSpans(nonMatch, controller)); return ''; });
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null) return const SizedBox();
    final matches = _manaSymbolRegex.allMatches(manaCost).map((m) => m.group(0)!).toList();
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: matches.map((s) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: _getManaIcon(s))).toList());
  }

  Widget _getManaIcon(String symbol) {
     final clean = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
     return SvgPicture.network('https://svgs.scryfall.io/card-symbols/$clean.svg', width: 16, placeholderBuilder: (_) => Text(symbol, style: const TextStyle(color: AppColors.textPrimary)));
  }
}
