// Fichier : lib/widgets/decks/deck_detail_share_sheet.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/deck_detail_controller.dart';
import '../../models/deck_model.dart';
import '../../services/deck_format_service.dart';
import '../../services/legality_service.dart';
import 'deck_visual_share_list.dart';
import 'deck_legality_tab.dart';
import 'deck_financial_sheet.dart';

/// Encapsulates all share/export actions for the deck detail page.
/// This is a utility class (not a widget) that holds methods
/// previously inlined in the page state.
class DeckDetailShareActions {
  final BuildContext Function() contextGetter;
  final DeckDetailController Function() ctrlGetter;
  final DeckDetailState Function() stateGetter;
  final Deck Function() deckGetter;
  final GlobalKey shareKey;
  final bool Function() mountedChecker;

  DeckDetailShareActions({
    required this.contextGetter,
    required this.ctrlGetter,
    required this.stateGetter,
    required this.deckGetter,
    required this.shareKey,
    required this.mountedChecker,
  });

  BuildContext get _context => contextGetter();
  DeckDetailController get _ctrl => ctrlGetter();
  DeckDetailState get _state => stateGetter();
  Deck get _deck => deckGetter();

  Future<void> captureAndShare() async {
    final captureState = _state;
    if (captureState.fullCardData.isEmpty) {
      ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(content: Text('Donnees des cartes non chargees. Veuillez patienter.')));
      return;
    }

    await showDialog(
      context: _context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(16),
          title: Column(
            children: [
              Text('Apercu avant partage', style: AppTextStyles.cinzel()),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Generation du poster en cours...',
                  style: TextStyle(
                      color: Colors.orangeAccent.shade100,
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(_context).size.height * 0.7,
            child: SingleChildScrollView(
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: shareKey,
                  child: DeckVisualShareList(
                    deck: captureState.currentDeck,
                    fullCardData: captureState.fullCardData,
                    totalPrice: captureState.totalDeckPrice,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share, color: AppColors.textOnPrimary),
              label: const Text("Partager l'image",
                  style: TextStyle(color: AppColors.textOnPrimary, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
              onPressed: () async {
                showDialog(
                  context: dialogContext,
                  barrierDismissible: false,
                  builder: (c) =>
                      const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
                );

                try {
                  await Future.delayed(const Duration(milliseconds: 500));

                  RenderRepaintBoundary boundary =
                      shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                  ui.Image image = await boundary.toImage(pixelRatio: 1.5);

                  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  Uint8List pngBytes = byteData!.buffer.asUint8List();

                  final tempDir = await getTemporaryDirectory();
                  final fileName = 'deck_share_${DateTime.now().millisecondsSinceEpoch}.png';
                  final file = await File('${tempDir.path}/$fileName').create();
                  await file.writeAsBytes(pngBytes);

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);

                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(file.path)],
                      text: 'Mon deck Commander : ${_deck.name}',
                    ),
                  );
                } catch (e) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  debugPrint('Erreur capture: $e');
                  if (!mountedChecker() || !_context.mounted) return;
                  ScaffoldMessenger.of(_context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de la generation.')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void shareFullDeck() {
    final text = _ctrl.generateFullDeckText();
    SharePlus.instance.share(ShareParams(text: text, subject: 'Decklist : ${_deck.name}'));
  }

  void shareConsidering() {
    final text = _ctrl.generateConsideringText();
    if (text == null) {
      ScaffoldMessenger.of(_context)
          .showSnackBar(const SnackBar(content: Text('La liste Considering est vide.')));
      return;
    }
    SharePlus.instance.share(ShareParams(text: text, subject: 'Considering : ${_deck.name}'));
  }

  void shareWishlist() {
    final text = _ctrl.generateWishlistText();
    if (text == null) {
      ScaffoldMessenger.of(_context)
          .showSnackBar(const SnackBar(content: Text('La Wishlist du deck est vide.')));
      return;
    }
    SharePlus.instance.share(ShareParams(text: text, subject: 'Wishlist : ${_deck.name}'));
  }

  Future<void> exportAsTxt() async {
    final txt = DeckFormatService.exportToTxt(_deck);
    final dir = await getTemporaryDirectory();
    final safeName = _deck.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final file = File('${dir.path}/$safeName.txt');
    await file.writeAsString(txt);
    await SharePlus.instance
        .share(ShareParams(files: [XFile(file.path)], subject: 'Decklist: ${_deck.name}'));
  }

  Future<void> exportAsCsv() async {
    final csv = DeckFormatService.exportToCsv(_deck);
    final dir = await getTemporaryDirectory();
    final safeName = _deck.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final file = File('${dir.path}/$safeName.csv');
    await file.writeAsString(csv);
    await SharePlus.instance
        .share(ShareParams(files: [XFile(file.path)], subject: 'Decklist: ${_deck.name}'));
  }

  void exportToClipboard() {
    final txt = DeckFormatService.exportToTxt(_deck);
    Clipboard.setData(ClipboardData(text: txt));
    if (mountedChecker()) {
      ScaffoldMessenger.of(_context).showSnackBar(
        const SnackBar(content: Text('Decklist copiee !'), duration: Duration(seconds: 2)),
      );
    }
  }

  void showValidationResults() {
    final report = LegalityService.generateReport(
      deck: _deck,
      fullCardData: _state.fullCardData,
    );
    showModalBottomSheet(
      context: _context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: DeckLegalityTab(report: report),
        ),
      ),
    );
  }

  void showFinancialAnalysis() {
    final finState = _state;
    showModalBottomSheet(
      context: _context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => DeckFinancialSheet(
        deck: finState.currentDeck,
        fullCardData: finState.fullCardData,
        collection: finState.myCollection,
      ),
    );
  }

  Future<void> handleExportDeckWishlistToGlobal() async {
    final currentDeckState = _state;
    if (currentDeckState.currentDeck.wishlist.isEmpty) {
      ScaffoldMessenger.of(_context)
          .showSnackBar(const SnackBar(content: Text('La Wishlist du deck est vide.')));
      return;
    }

    final textController =
        TextEditingController(text: 'Achats: ${currentDeckState.currentDeck.name}');
    final name = await showDialog<String>(
      context: _context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Creer une Wishlist Globale', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Cela va creer une nouvelle liste dans l'onglet Wishlist de l'application avec ces cartes.",
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
                controller: textController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Nom de la liste')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, textController.text),
              child: const Text('Creer')),
        ],
      ),
    );

    if (name != null) {
      final result = await _ctrl.exportDeckWishlistToGlobal(name);
      if (result != null && mountedChecker() && _context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: AppColors.success),
        );
      }
    }
  }
}
