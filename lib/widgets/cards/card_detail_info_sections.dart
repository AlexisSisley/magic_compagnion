// Fichier : lib/widgets/cards/card_detail_info_sections.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/card_detail_controller.dart';
import '../../data/glossary_data.dart';
import '../../router/app_router.dart';
import '../../utils/price_helper.dart';

/// Reusable info card wrapper used on the card detail page.
class CardDetailInfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const CardDetailInfoCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.4),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.primaryShade800.withValues(alpha: 0.6))),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.cinzel(fontSize: 20, fontWeight: FontWeight.w600)),
                const Divider(color: AppColors.borderMedium),
                const SizedBox(height: 8),
                child
              ])),
    );
  }
}

/// Displays card prices (normal and foil).
class CardDetailPriceInfo extends StatelessWidget {
  final Map<String, dynamic> prices;

  const CardDetailPriceInfo({super.key, required this.prices});

  @override
  Widget build(BuildContext context) {
    final String priceEur = PriceHelper.format(prices);
    final String priceEurFoil = PriceHelper.format(prices, isFoil: true);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [
          Text('Normal', style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
          Text(priceEur,
              style: AppTextStyles.bold(fontSize: 20))
        ]),
        Container(width: 1, height: 30, color: AppColors.borderMedium),
        Column(children: [
          Text('Foil (Brillant)',
              style: AppTextStyles.cinzel(color: Colors.amber.shade200)),
          Text(priceEurFoil,
              style: AppTextStyles.bold(fontSize: 20))
        ]),
      ],
    );
  }
}

/// Displays legality badges for common formats.
class CardDetailLegalities extends StatelessWidget {
  final Map<String, String> legalities;

  const CardDetailLegalities({super.key, required this.legalities});

  @override
  Widget build(BuildContext context) {
    const formats = ['standard', 'commander', 'modern', 'pioneer'];
    return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: formats.map((fmt) {
          final status = legalities[fmt] ?? 'not_legal';
          Color c = status == 'legal'
              ? Colors.green
              : (status == 'banned' ? AppColors.error : AppColors.synergyNeutral);
          return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c)),
              child: Text('${fmt[0].toUpperCase()}${fmt.substring(1)}',
                  style: AppTextStyles.bold(color: c)));
        }).toList());
  }
}

/// Displays a list of rulings for the card.
class CardDetailRulingsList extends StatelessWidget {
  final CardDetailState state;

  const CardDetailRulingsList({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingRulings) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.rulings.isEmpty) {
      return Text('(Aucune decision)',
          style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontStyle: FontStyle.italic));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: state.rulings
            .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.date,
                          style: AppTextStyles.bold()),
                      Text(r.comment,
                          style: const TextStyle(color: AppColors.textPrimary))
                    ])))
            .toList());
  }
}

/// Displays the mana cost row as SVG icons.
class CardDetailManaCostRow extends StatelessWidget {
  final String? manaCost;
  static final RegExp _manaSymbolRegex = RegExp(r'(\{.*?\})');

  const CardDetailManaCostRow({super.key, required this.manaCost});

  @override
  Widget build(BuildContext context) {
    if (manaCost == null) return const SizedBox();
    final matches =
        _manaSymbolRegex.allMatches(manaCost!).map((m) => m.group(0)!).toList();
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: matches
            .map((s) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _getManaIcon(s)))
            .toList());
  }

  static Widget _getManaIcon(String symbol) {
    final clean = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    return SvgPicture.network(
        'https://svgs.scryfall.io/card-symbols/$clean.svg',
        width: 16,
        placeholderBuilder: (_) =>
            Text(symbol, style: const TextStyle(color: AppColors.textPrimary)));
  }
}

/// Displays the rules text with clickable keyword links and mana symbols.
/// US-14.5 : Converti en StatefulWidget pour dispose correct des TapGestureRecognizer.
class CardDetailClickableRulesText extends StatefulWidget {
  final String text;
  final String lang;
  final CardDetailController controller;

  const CardDetailClickableRulesText({
    super.key,
    required this.text,
    required this.lang,
    required this.controller,
  });

  @override
  State<CardDetailClickableRulesText> createState() => _CardDetailClickableRulesTextState();
}

class _CardDetailClickableRulesTextState extends State<CardDetailClickableRulesText> {
  static final RegExp _manaSymbolRegex = RegExp(r'(\{.*?\})');

  /// US-14.5 : Pool de TapGestureRecognizer pour dispose correct.
  final List<TapGestureRecognizer> _tapRecognizers = [];

  @override
  void dispose() {
    for (final recognizer in _tapRecognizers) {
      recognizer.dispose();
    }
    _tapRecognizers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return Text('(Pas de texte)',
          style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontStyle: FontStyle.italic));
    }
    // Dispose les anciens recognizers avant de reconstruire.
    for (final recognizer in _tapRecognizers) {
      recognizer.dispose();
    }
    _tapRecognizers.clear();

    final List<InlineSpan> spans = [];
    widget.text.splitMapJoin(_manaSymbolRegex, onMatch: (Match match) {
      final String symbol = match.group(0)!;
      spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: CardDetailManaCostRow._getManaIcon(symbol))));
      return '';
    }, onNonMatch: (String nonMatch) {
      spans.add(_buildKeywordSpans(nonMatch, context));
      return '';
    });
    return RichText(text: TextSpan(children: spans));
  }

  InlineSpan _buildKeywordSpans(String textChunk, BuildContext context) {
    final List<String> words = textChunk.split(' ');
    final List<InlineSpan> spans = [];
    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      final Keyword? keyword = widget.controller.findKeyword(word);
      if (keyword != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            context.push(AppRoutes.glossaryDetail, extra: keyword);
          };
        _tapRecognizers.add(recognizer);
        spans.add(TextSpan(
            text: '$word ',
            style: AppTextStyles.bold(color: Colors.blue.shade300).copyWith(decoration: TextDecoration.underline, decorationColor: Colors.blue.shade300),
            recognizer: recognizer));
      } else {
        spans.add(TextSpan(
            text: '$word ',
            style: const TextStyle(color: AppColors.textPrimary, height: 1.4)));
      }
    }
    return TextSpan(children: spans);
  }
}
