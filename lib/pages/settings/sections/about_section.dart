// Fichier : lib/pages/settings/sections/about_section.dart
// "A propos & Licences" : la mention Wizards of the Coast.
//
// Bloc DEPLACE depuis `app_shell_scaffold.dart` (`_showAppAboutDialog`). Le
// texte legal n'est pas reformule : c'est une obligation d'attribution envers
// Wizards of the Coast, pas une formulation a ameliorer.
//
// Couleurs par MagicPalette : ecran neuf (contrainte globale du plan).

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../theme/app_text_styles.dart';
import '../../../theme/magic_palette.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  Future<void> _ouvrirDialogue(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    final p = MagicPalette.of(context);

    showAboutDialog(
      context: context,
      applicationName: 'Magic Companion',
      applicationVersion: 'v${info.version} (Build ${info.buildNumber})',
      applicationIcon: Image.asset(
        'assets/icone.png',
        width: 60,
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) =>
            Icon(Icons.auto_awesome, size: 48, color: p.inkMuted),
      ),
      applicationLegalese: '© 2025 - Compagnon non-officiel',
      children: [
        const SizedBox(height: 24),
        Text(
          'Développé avec Flutter et Passion.',
          style: AppTextStyles.text(color: p.inkSecondary),
        ),
        const SizedBox(height: 12),
        Text(
          "Ce projet utilise l'API Scryfall pour les données de cartes. "
          'Les informations textuelles et graphiques littérales et artistiques '
          'présentées sur ce site au sujet de Magic: The Gathering, y compris '
          'les images de cartes, le mana, et le symbole Tap sont la propriété '
          'de Wizards of the Coast, LLC.',
          style: AppTextStyles.text(color: p.inkSecondary, fontSize: 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);

    return ListTile(
      leading: Icon(Icons.info_outline, color: p.inkSecondary),
      title: Text('À propos & Licences',
          style: AppTextStyles.text(color: p.inkPrimary)),
      subtitle: Text('Mentions légales Wizards of the Coast',
          style: AppTextStyles.text(color: p.inkSecondary, fontSize: 11)),
      onTap: () => _ouvrirDialogue(context),
    );
  }
}
