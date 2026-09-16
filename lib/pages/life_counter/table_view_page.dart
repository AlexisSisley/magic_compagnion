// Fichier : lib/pages/life_counter/table_view_page.dart
//
// Vue table (spec S2.3, amendee -- voir le plan, tache 4) : une liste
// compacte, une ligne par joueur, pour lire l'etat de toute la table d'un
// coup avant d'attaquer. PV, compteurs non nuls, monarque, elimination.
//
// La spec prevoyait a l'origine un geste global a deux doigts pour ouvrir
// cette vue. Abandonne par decision explicite : un detecteur multi-pointeurs
// entrerait en concurrence avec la surface de gestes de LifeDial, qui a deja
// coute trois rondes de correction et quatre constats Critical (lot 2), et
// dont l'equilibre tient a une seule decision architecturale (l'appui long
// vit hors de l'arene de gestes). L'ouverture se fait donc par un bouton de
// la barre centrale (voir life_counter_page.dart, _buildCentralBar) -- cette
// page elle-meme n'ajoute, et ne doit jamais ajouter, aucun detecteur de
// geste sur une zone joueur.
//
// Choix de forme (documente dans le rapport de tache) : une route poussee
// (Navigator.push + MaterialPageRoute), pas un tiroir ni une feuille modale.
// La vue table est un ecran de LECTURE -- on la consulte, on ne declenche
// aucune action depuis elle -- alors que tous les tiroirs/feuilles de
// life_counter_page.dart portent des actions ponctuelles sur un joueur
// (showModalBottomSheet, showDialog). Une route pleine page lui donne un
// bouton retour standard et une entree d'historique de navigation propre,
// sans reutiliser la semantique "action rapide" des feuilles modales.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/widgets/life_counter/elimination_overlay.dart';

class TableViewPage extends ConsumerWidget {
  const TableViewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionNotifierProvider);
    final players = _orderedPlayers(session);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBackground,
        title: Text('Vue table', style: AppTextStyles.appBarTitle()),
      ),
      body: players.isEmpty
          ? Center(
              child: Text(
                'Aucune partie en cours',
                style: AppTextStyles.body(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: players.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.borderFaint, height: 24),
              itemBuilder: (context, index) => _PlayerRow(player: players[index]),
            ),
    );
  }

  /// Ordre d'affichage des joueurs : reproduit `playerOrder` (disposition
  /// choisie par le joueur), comme la grille de zones -- la vue table doit
  /// lister la table dans le meme ordre que ce que l'oeil voit dessus. Repli
  /// sur l'ordre canonique si `playerOrder` est absent ou corrompu (meme
  /// garde que `_orderedPlayers` de life_counter_page.dart).
  List<PlayerState> _orderedPlayers(GameSession? session) {
    if (session == null) return const [];
    final order = session.playerOrder;
    if (order.length != session.players.length) return session.players;
    final byId = {for (final p in session.players) p.playerId: p};
    final ordered = <PlayerState>[];
    for (final id in order) {
      final p = byId[id];
      if (p == null) return session.players;
      ordered.add(p);
    }
    return ordered;
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});

  final PlayerState player;

  static CounterType? _counterTypeFor(String id) {
    for (final type in CounterType.builtInCounters) {
      if (type.id == id) return type;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final eliminated = player.isEliminated;
    final textColor = eliminated ? AppColors.textMuted : AppColors.textPrimary;
    // Coeur de la spec §2.3 : les compteurs a zero sont bruit, pas
    // information -- une vue "toute la table d'un coup d'oeil" qui les
    // affiche tous redevient aussi dense qu'un tiroir par joueur.
    final nonZeroCounters =
        player.counters.entries.where((e) => e.value != 0).toList();

    return Opacity(
      key: ValueKey('table-view-row-${player.playerId}'),
      opacity: eliminated ? 0.55 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(player.config.colorValue),
              ),
              if (eliminated)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    key: ValueKey('table-view-eliminated-${player.playerId}'),
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.accentRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      EliminationOverlay.eliminationIcon,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.config.name,
                        style: AppTextStyles.cardTitle(color: textColor).copyWith(
                          decoration:
                              eliminated ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (player.isMonarch) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.emoji_events,
                        key: ValueKey('table-view-monarch-${player.playerId}'),
                        color: AppColors.amber,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                if (nonZeroCounters.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final entry in nonZeroCounters)
                        _counterChip(entry.key, entry.value),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${player.life}',
            key: ValueKey('table-view-life-${player.playerId}'),
            style: AppTextStyles.cardTitle(color: textColor, fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _counterChip(String counterId, int value) {
    final type = _counterTypeFor(counterId);
    final glyph = type?.emoji ?? counterId;
    final color = type != null ? Color(type.color) : AppColors.textSecondary;
    return Text(
      '$glyph $value',
      key: ValueKey('table-view-counter-${player.playerId}-$counterId'),
      style: AppTextStyles.lifeHandleChip(color: color),
    );
  }
}
