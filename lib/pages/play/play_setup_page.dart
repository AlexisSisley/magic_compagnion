// Fichier : lib/pages/play/play_setup_page.dart
// Mise en place d'une partie : le seuil du mode Jeu.
//
// Cet ecran ne reimplemente PAS la selection de format, de points de vie et
// de joueurs : `GameSetupModal` la porte deja, et la dupliquer ferait deriver
// deux chemins de configuration. Il l'ouvre telle quelle -- c'est d'ailleurs
// sa seule facon d'etre utilisee, puisqu'elle se termine par un
// `Navigator.pop` et ne peut donc pas etre posee a plat dans une page.
//
// Il porte en revanche ce que le modal ne sait pas faire : proposer la
// reprise d'une partie deja en cours, et ecrire le snapshot que
// `LifeCounterPage` relira au montage.
//
// Couleurs par MagicPalette : ecran neuf, donc aucun AppColors de surface,
// d'encre ou de semantique (contrainte globale du plan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/game_format.dart';
import '../../models/game_session.dart';
import '../../models/player_config.dart';
import '../../models/profile_model.dart';
import '../../providers/active_game_provider.dart';
import '../../providers/service_providers.dart';
import '../../router/app_routes.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/magic_palette.dart';
import '../../widgets/life_counter/game_setup_modal.dart';

class PlaySetupPage extends ConsumerStatefulWidget {
  const PlaySetupPage({super.key});

  @override
  ConsumerState<PlaySetupPage> createState() => _PlaySetupPageState();
}

class _PlaySetupPageState extends ConsumerState<PlaySetupPage> {
  @override
  void initState() {
    super.initState();
    // La feuille s'ouvre d'elle-meme SEULEMENT s'il n'y a pas de partie en
    // cours.
    //
    // Sans partie, l'ecran serait creux : il annoncerait "choisissez un
    // format, les points de vie et les joueurs" sans offrir aucun moyen de le
    // faire. Avec une partie, il porte deja "Reprendre la partie en cours" et
    // n'est donc pas creux -- et surtout, on y arrive en SORTANT d'une partie
    // par le bouton Fin : ouvrir alors "configurer une nouvelle partie" est
    // l'inverse exact du geste demande.
    //
    // Apres la premiere frame, parce que showModalBottomSheet a besoin d'un
    // Navigator installe.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final partie = await ref.read(activeGameProvider.future);
      if (!mounted || partie != null) return;
      _ouvrirConfiguration(context, ref);
    });
  }

  /// Couleurs de repli quand un joueur n'a pas de profil, alignees sur celles
  /// de `LifeCounterPage`.
  static const _couleursParDefaut = <int>[
    0xFF2196F3,
    0xFFF44336,
    0xFF4CAF50,
    0xFF9C27B0,
  ];

  /// Ecrit la partie configuree puis ouvre le compteur.
  ///
  /// La partie n'est pas demarree ici : elle est SNAPSHOTTEE. `LifeCounterPage`
  /// la relit dans son `_loadGame()` au montage, exactement comme elle relit
  /// une partie interrompue. Un seul chemin de restauration, donc, au lieu
  /// d'un second chemin de creation qui divergerait du sien.
  Future<void> _demarrer(
    BuildContext context,
    WidgetRef ref,
    GameFormat format,
    List<Profile?> profils,
  ) async {
    final configs = <PlayerConfig>[
      for (var i = 0; i < profils.length; i++)
        PlayerConfig(
          id: 'player_$i',
          name: profils[i]?.name ?? 'Joueur ${i + 1}',
          type: i == 0 ? PlayerType.owner : PlayerType.guest,
          colorValue: profils[i]?.colorValue ??
              _couleursParDefaut[i % _couleursParDefaut.length],
          avatarPath: profils[i]?.commanderImageUrl,
        ),
    ];

    final session = GameSession.newGame(format: format, playerConfigs: configs);
    await ref.read(gameSessionServiceProvider).saveSnapshot(session);
    ref.invalidate(activeGameProvider);

    if (!context.mounted) return;
    context.go(AppRoutes.playCounter);
  }

  void _ouvrirConfiguration(BuildContext context, WidgetRef ref) {
    final p = MagicPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.overlay,
      builder: (_) => GameSetupModal(
        // 40 points de vie : la valeur de Commander, format par defaut de
        // l'app et de loin le plus joue par son public. La modale s'en sert
        // pour preselectionner un format, donc ce n'est pas qu'un nombre
        // affiche -- le changer change l'onglet ouvert.
        initialLife: 40,
        onGameStart: (format, profils) =>
            _demarrer(context, ref, format, profils),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final partieEnCours = ref.watch(activeGameProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: p.inkSecondary),
                    tooltip: 'Fermer',
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                  const SizedBox(width: 4),
                  Text('Nouvelle partie',
                      style: AppTextStyles.sectionTitle(color: p.inkPrimary)),
                ],
              ),
              const Spacer(),
              Icon(Icons.sports_esports, size: 72, color: p.inkMuted),
              const SizedBox(height: 16),
              Text(
                'Choisissez un format, les points de vie et les joueurs.',
                textAlign: TextAlign.center,
                style: AppTextStyles.text(color: p.inkSecondary, fontSize: 14),
              ),
              const Spacer(),

              // Reprise : seulement si un snapshot existe. `activeGameProvider`
              // est un FutureProvider ; pendant sa resolution on n'affiche
              // rien plutot qu'un bouton qui apparaitrait apres coup.
              partieEnCours.maybeWhen(
                data: (session) => session == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton(
                          onPressed: () => context.go(AppRoutes.playCounter),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.accent,
                            side: BorderSide(color: p.accent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text('Reprendre la partie en cours',
                              style: AppTextStyles.buttonText(color: p.accent)),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),

              // "Configurer la partie", pas "Demarrer" : le bouton ouvre
              // la feuille, il ne lance rien. Nommer l'action par son effet
              // evite de promettre un demarrage qui n'arrive qu'apres la
              // configuration.
              FilledButton(
                onPressed: () => _ouvrirConfiguration(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Configurer la partie',
                    style: AppTextStyles.buttonText(color: p.onAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
