// Fichier : lib/widgets/scans/scanner_manual_search_modal.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/scryfall_card_model.dart';
import '../../router/app_router.dart';
import '../../services/local_card_service.dart';

/// Modal bottom sheet for manual card name search within the scanner page.
class ScannerManualSearchModal extends StatefulWidget {
  final LocalCardService localCardService;
  const ScannerManualSearchModal({super.key, required this.localCardService});

  @override
  State<ScannerManualSearchModal> createState() => _ScannerManualSearchModalState();
}

class _ScannerManualSearchModalState extends State<ScannerManualSearchModal> {
  final TextEditingController _controller = TextEditingController();
  List<ScryfallCard> _results = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length >= 2) {
        final results = await widget.localCardService.searchCards(query: query);
        if (mounted) {
          setState(() {
            _results = results;
          });
        }
      } else {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: AppTextStyles.cinzel(),
                      decoration: const InputDecoration(
                        hintText: 'Nom de la carte (FR/EN)...',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            const Divider(color: AppColors.borderLight, height: 1),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.isEmpty
                            ? "Tapez le nom d'une carte"
                            : 'Aucun resultat local.',
                        style: AppTextStyles.cinzel(color: AppColors.textDisabled),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final card = _results[index];
                        return ListTile(
                          title: Text(card.name,
                              style: AppTextStyles.cinzel()),
                          subtitle: Text(card.typeLine,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.borderMedium),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.cardDetail,
                                extra: {'cardName': card.name});
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
