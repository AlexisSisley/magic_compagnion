// Fichier : lib/pages/home/home_page.dart
// L'Accueil : ce que l'app montre hors partie, et la porte d'entree du mode
// Jeu.
//
// Remplace le compteur de vie a la racine. Environ 70% des ecrans de l'app
// servent hors partie : ouvrir sur un compteur faisait payer a tout le monde
// le cas d'usage d'une minorite de sessions.
//
// Le tableau de bord n'est pas reecrit : il est pose ici en mode embarque,
// sans son Scaffold ni son AppBar.
//
// Couleurs par MagicPalette : ecran neuf (contrainte globale du plan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/active_game_provider.dart';
import '../../router/app_routes.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/magic_palette.dart';
import '../dashboard/dashboard_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MagicPalette.of(context);
    final partieEnCours = ref.watch(activeGameProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Accueil',
                        style: AppTextStyles.pageTitle(color: p.inkPrimary)),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: p.inkSecondary),
                    tooltip: 'Reglages',
                    onPressed: () => context.push(AppRoutes.settings),
                  ),
                ],
              ),
              const Expanded(child: DashboardPage(isEmbedded: true)),
              const SizedBox(height: 8),
              const _RangeeOutils(),
              const SizedBox(height: 8),
              _BoutonPartie(partieEnCours: partieEnCours),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton principal : reprendre la partie en cours, ou en lancer une.
///
/// Un seul des deux est rendu. Pendant que le snapshot se lit, on affiche le
/// lancement plutot qu'un vide : c'est le cas de loin le plus frequent, et un
/// bouton qui apparaitrait apres coup sous le pouce est pire qu'un libelle
/// qui change.
class _BoutonPartie extends StatelessWidget {
  const _BoutonPartie({required this.partieEnCours});

  final AsyncValue<Object?> partieEnCours;

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final aUnePartie = partieEnCours.maybeWhen(
      data: (session) => session != null,
      orElse: () => false,
    );

    return FilledButton.icon(
      onPressed: () => context.go(
          aUnePartie ? AppRoutes.playCounter : AppRoutes.playSetup),
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      icon: Icon(aUnePartie ? Icons.play_arrow : Icons.sports_esports,
          color: p.onAccent),
      label: Text(
        aUnePartie ? 'Reprendre la partie' : 'Lancer une partie',
        style: AppTextStyles.buttonText(color: p.onAccent),
      ),
    );
  }
}

/// Acces direct aux outils de regles, hors partie.
///
/// Sans cette rangee, poser une question de regles exigerait de CREER ou de
/// REPRENDRE une partie : les trois outils ne vivent que sous /play, et les
/// entrees de tiroir qui y menaient ont disparu. La spec promettait des
/// entrees contextuelles (Oracle depuis une fiche carte, Probas depuis une
/// fiche deck) ; elles demandent de toucher des ecrans existants et sont
/// differees. En attendant, l'Accueil est la porte hors partie.
class _RangeeOutils extends StatelessWidget {
  const _RangeeOutils();

  static const _outils = <({String label, IconData icon, String route})>[
    (label: 'Oracle', icon: Icons.all_inclusive, route: AppRoutes.playOracle),
    (label: 'Règles', icon: Icons.menu_book, route: AppRoutes.playGlossary),
    (label: 'Probas', icon: Icons.calculate_outlined, route: AppRoutes.playOdds),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);

    return Row(
      children: [
        for (final outil in _outils)
          Expanded(
            child: TextButton.icon(
              onPressed: () => context.go(outil.route),
              style: TextButton.styleFrom(foregroundColor: p.inkSecondary),
              icon: Icon(outil.icon, size: 18, color: p.inkSecondary),
              label: Text(
                outil.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.text(color: p.inkSecondary, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}
