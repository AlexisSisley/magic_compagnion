// Fichier : lib/widgets/cards/scryfall_image.dart
// Widget réutilisable pour afficher des images Scryfall avec cache, placeholder et gestion d'erreur.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Headers requis par l'API Scryfall (User-Agent obligatoire, sinon 400).
/// Les images CDN (cards.scryfall.io) n'en ont pas besoin, mais les URLs
/// redirect (api.scryfall.com/cards/{id}?format=image) oui.
const Map<String, String> _scryfallHeaders = {
  'User-Agent': 'MagicCompanion/1.0',
  'Accept': '*/*',
};

/// Widget générique pour afficher une image Scryfall avec :
/// - Cache disque automatique (cached_network_image)
/// - Placeholder pendant le chargement
/// - Icône de fallback en cas d'erreur (400, 404, réseau...)
/// - Headers User-Agent pour éviter les 400 sur api.scryfall.com
class ScryfallImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ScryfallImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildError();
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      httpHeaders: _scryfallHeaders,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildError(),
      fadeInDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade900,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white24, size: 24),
      ),
    );
  }
}

/// Variante circulaire pour les avatars (profils, commandants).
class ScryfallAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;

  const ScryfallAvatarImage({
    super.key,
    required this.imageUrl,
    this.radius = 40,
    this.backgroundColor = const Color(0xFF424242),
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: const Icon(Icons.person, color: Colors.white54),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      httpHeaders: _scryfallHeaders,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: const Icon(Icons.person, color: Colors.white54),
      ),
    );
  }
}
