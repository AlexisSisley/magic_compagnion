// lib/widgets/life_counter/zone/player_skin_picker.dart
// Personnalisation visuelle du joueur : couleur unie, artwork (recherche
// Scryfall ou galerie de commandants sauvegardés), photo depuis la galerie
// de l'appareil, image de fond affichée derrière la zone.
//
// Extrait de PlayerZone (tâche 6, ronde 1 de revue) : ~320 lignes qui
// n'avaient rien à voir avec la logique de vie/compteurs de la zone — la
// frontière est ici la responsabilité (« à quoi ressemble le joueur »), pas
// une taille de fichier arbitraire.

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/services/local_card_service.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import '../../cards/versions_selector_sheet.dart';

/// Palette de couleurs unies proposée par [showPlayerSkinPicker]. Pas de
/// `const` : `AppColors.greyShade800` est un getter, pas une constante (voir
/// la même note dans `conditional_handle.dart`).
final List<Color> playerSkinColorOptions = [
  Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
  AppColors.greyShade800, Colors.purple.shade900, Colors.orange.shade900,
  Colors.teal.shade900, Colors.pink.shade900, Colors.brown.shade800,
  Colors.indigo.shade900, Colors.blueGrey.shade800, Colors.black
];

/// Construit l'image (ou la paire d'images, en split-screen) affichée en
/// fond de la zone, d'après `player.backgroundImagePath` /
/// `secondaryBackgroundImagePath`. Retombe sur une couleur unie si aucune
/// image n'est définie.
Widget buildPlayerBackground(Player player) {
  if (player.backgroundImagePath != null && player.secondaryBackgroundImagePath != null) {
    return Row(
      children: [
        Expanded(child: _buildImage(player.backgroundImagePath!)),
        Expanded(child: _buildImage(player.secondaryBackgroundImagePath!)),
      ],
    );
  } else if (player.backgroundImagePath != null) {
    return _buildImage(player.backgroundImagePath!);
  }
  return Container(color: Color(player.colorValue));
}

Widget _buildImage(String path) {
  if (path.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: path,
      httpHeaders: const {'User-Agent': 'MagicCompanion/1.0', 'Accept': '*/*'},
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(color: AppColors.greyShade900),
      errorWidget: (context, url, error) => Container(
        color: AppColors.greyShade900,
        child: const Center(child: Icon(Icons.image_not_supported, color: AppColors.borderMedium)),
      ),
    );
  }
  return Image(image: FileImage(File(path)), fit: BoxFit.cover,
    errorBuilder: (c, e, s) => Container(
      color: AppColors.greyShade900,
      child: const Center(child: Icon(Icons.image_not_supported, color: AppColors.borderMedium)),
    ),
  );
}

Future<void> _pickImage(
  BuildContext dialogCtx, {
  required ValueChanged<String?>? onSkinChanged,
}) async {
  final ImagePicker picker = ImagePicker();
  try {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && onSkinChanged != null) {
      onSkinChanged(image.path);
      if (!dialogCtx.mounted) return;
      Navigator.of(dialogCtx).pop();
    }
  } catch (e) {
    debugPrint('Erreur image picker: $e');
  }
}

void _openArtworkSearch(
  BuildContext context,
  BuildContext dialogCtx, {
  required LocalCardService localCardService,
  required ValueChanged<String?>? onSkinChanged,
}) {
  // Close the color picker dialog using the dialog's own context
  Navigator.of(dialogCtx).pop();

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.scaffoldBackground,
    isScrollControlled: true,
    builder: (sheetCtx) => _ArtworkSearchModal(
      localCardService: localCardService,
      onCardSelected: (ScryfallCard card) {
        final String artUrl = card.artCropUrl ?? card.imageUrl;
        onSkinChanged?.call(artUrl);
      },
    ),
  );
}

/// Ouvre le dialogue de personnalisation visuelle : artwork (recherche
/// Scryfall), photo depuis la galerie de l'appareil, ou couleur unie.
/// Remplace l'ancien `PlayerZone._showColorPicker`.
void showPlayerSkinPicker({
  required BuildContext context,
  required Player player,
  required ValueChanged<Color> onColorChanged,
  required ValueChanged<String?>? onSkinChanged,
  required LocalCardService localCardService,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.scaffoldBackground,
      title: Text('Personnalisation J${player.id + 1}', style: AppTextStyles.cinzel()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () => _openArtworkSearch(
              context,
              dialogCtx,
              localCardService: localCardService,
              onSkinChanged: onSkinChanged,
            ),
            icon: const Icon(Icons.palette, color: AppColors.textOnPrimary),
            label: Text('Choisir un Artwork', style: AppTextStyles.bold()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade800, foregroundColor: AppColors.textOnPrimary),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickImage(dialogCtx, onSkinChanged: onSkinChanged),
            icon: const Icon(Icons.photo_library),
            label: const Text('Depuis la galerie'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.borderMedium)),
          ),
          if (player.backgroundImagePath != null)
             TextButton(
               onPressed: () {
                 onSkinChanged?.call(null);
                 Navigator.of(dialogCtx).pop();
               },
               child: const Text("Supprimer l'image", style: TextStyle(color: AppColors.accentRed))
             ),
          const Divider(color: AppColors.borderMedium),
          const Text('Couleur unie :', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12, runSpacing: 12,
            alignment: WrapAlignment.center,
            children: playerSkinColorOptions.map((c) => GestureDetector(
              onTap: () { onColorChanged(c); Navigator.of(dialogCtx).pop(); },
              child: Container(
                width: 45, height: 45,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textMuted, width: 2),
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    )
  );
}

/// Ouvre la galerie des commandants sauvegardés du joueur (bascule rapide
/// d'artwork). Remplace l'ancien `PlayerZone._showCommanderGallery`.
void showCommanderGallery({
  required BuildContext context,
  required Player player,
  required ValueChanged<String?>? onSkinChanged,
}) {
  final gallery = player.commanderGallery;
  if (gallery.isEmpty) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.scaffoldBackground,
    builder: (sheetCtx) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Commanders', style: AppTextStyles.cinzel(fontSize: 18)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: gallery.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final entry = gallery[i];
                final isActive = player.backgroundImagePath == entry.imageUrl;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (onSkinChanged != null) {
                      onSkinChanged(entry.imageUrl);
                      HapticFeedback.selectionClick();
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? AppColors.primary : AppColors.borderMedium,
                            width: isActive ? 3 : 1,
                          ),
                          boxShadow: isActive ? [
                            BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 8),
                          ] : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: entry.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: entry.imageUrl!,
                                httpHeaders: const {'User-Agent': 'MagicCompanion/1.0', 'Accept': '*/*'},
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: AppColors.surfaceDarkest,
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.surfaceDarkest,
                                  child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceDarkest,
                                child: const Icon(Icons.image, color: AppColors.textMuted),
                              ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 80,
                        child: Text(
                          entry.name,
                          style: AppTextStyles.label(fontSize: 10),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// --- SOUS-WIDGET : MODALE DE RECHERCHE D'ARTWORK ---
class _ArtworkSearchModal extends StatefulWidget {
  final LocalCardService localCardService;
  final Function(ScryfallCard) onCardSelected;

  const _ArtworkSearchModal({required this.localCardService, required this.onCardSelected});

  @override
  State<_ArtworkSearchModal> createState() => _ArtworkSearchModalState();
}

class _ArtworkSearchModalState extends State<_ArtworkSearchModal> {
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
            _results = results.take(20).toList();
          });
        }
      } else {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  void _openVersionSelector(ScryfallCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => VersionsSelectorSheet(
        oracleId: card.oracleId,
        currentCardId: card.id,
        onVersionSelected: (version) {
           widget.onCardSelected(version);
           Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Text('Choisir un Artwork', style: AppTextStyles.cinzel(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: AppTextStyles.cinzel(),
              decoration: const InputDecoration(
                hintText: 'Nom de la carte...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.overlayMedium,
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _results.isEmpty
                  ? Center(child: Text("Tapez le nom d'une carte", style: AppTextStyles.cinzel(color: AppColors.textDisabled)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final card = _results[index];
                        final imgUrl = card.smallImageUrl ?? '';

                        return GestureDetector(
                          onTap: () => _openVersionSelector(card),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, _, _)=>Container(color: AppColors.greyShade800)),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    color: AppColors.overlayDark,
                                    child: const Icon(Icons.grid_view, size: 12, color: AppColors.textSecondary),
                                  ),
                                )
                              ],
                            ),
                          ),
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
