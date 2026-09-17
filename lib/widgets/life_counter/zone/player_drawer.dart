// lib/widgets/life_counter/zone/player_drawer.dart
// Le tiroir du joueur (spec §2.7) : tout ce qui n'est pas les points de vie.
//
// Lot 2 — la coquille : compteurs et actions (ces dernières reprises du menu
// radial, qui perd son appui long au profit du mode ajustement, spec §2.5).
// Lot 3 — la grille de dégâts de commandant reçus (§2.7 point 2), qui
// remplace la ligne provisoire ouvrant le sélecteur plein écran.
// Lot 5, tâche 2 — les lignes de compteurs ne sont plus les trois constantes
// `_counterLabels` / `_counterIcons` (icônes Material figées, disparues) :
// elles suivent `activeCounters`, la liste ordonnée des `CounterType` actifs
// de la session, résolue par l'appelant (`life_counter_page._openPlayerDrawer`)
// à partir de `GameSession.activeCounterIds` et du catalogue (tâche 1). Rendu
// par emoji (`CounterType.emoji`), pas par `IconData` : un `IconData` ne se
// sérialise pas proprement et obligerait à un sélecteur d'icônes pour les
// compteurs personnalisés, alors que l'émoji est déjà une donnée du modèle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'commander_damage_grid.dart';
import 'counter_editor_dialog.dart';

Future<void> showPlayerDrawer({
  required BuildContext context,
  required String playerName,
  required List<CounterType> activeCounters,
  required Map<String, int> counters,
  required bool isMonarch,
  required bool isEliminated,
  required void Function(String counterId, int delta) onCounterDelta,
  required VoidCallback onToggleMonarch,
  required VoidCallback onEliminate,
  required VoidCallback onResetCounters,
  required List<CommanderDamageOpponent> commanderDamage,
  required void Function(int sourcePlayerId, int delta) onCommanderDamageDelta,
  required int lethalCommanderDamage,
  // Lot 5, tâche 4 : créer et retirer un compteur depuis le tiroir.
  //
  // `onCreateCounter` sauvegarde réellement [type] (typiquement via
  // `CounterCatalogNotifier.saveCustomType`, tâche 1) ET l'active dans la
  // partie en cours (décision 2 du rapport : un compteur créé est actif
  // immédiatement) -- ce tiroir ne fait qu'appeler ce callback et afficher
  // son résultat, jamais parler à un `Notifier` lui-même (comme pour toutes
  // les autres actions). Un `record` `{success, message}`, pas un type
  // importé de la couche providers, pour ne pas coupler ce widget de zone à
  // `CounterCatalogActionResult`.
  required Future<({bool success, String message})> Function(CounterType type)
      onCreateCounter,
  // Retire [counterId] des compteurs actifs de la partie (pas du
  // catalogue -- un intégré ne peut pas en être supprimé, mais peut être
  // retiré des actifs comme un personnalisé, voir la contrainte du lot).
  required void Function(String counterId) onRemoveCounter,
  // Revue finale (Critical 3) : le catalogue persistant (`CounterTypeService`)
  // était écrit et jamais relu -- un compteur créé n'était utilisable
  // qu'une fois, dans la partie où il avait été créé, sans aucun chemin
  // pour le réactiver ensuite (`activateCounter` n'avait qu'un seul
  // appelant, à la création). `inactiveCounters` liste les compteurs du
  // CATALOGUE (résolu par l'appelant, tâche 1) qui ne sont pas actifs dans
  // CETTE partie -- personnalisés ou intégrés retirés, mêmes principes que
  // `activeCounters` ci-dessus. Défauts par défaut vides/`null` : un
  // appelant qui n'a rien à proposer (ex. catalogue vide) n'a rien de plus
  // à fournir.
  List<CounterType> inactiveCounters = const [],
  // Réactive [type] dans la partie en cours (typiquement
  // `GameSessionNotifier.activateCounter(type.id, isCustom: !type.isBuiltIn)`)
  // et rend la valeur RÉELLE déjà portée par ce joueur pour ce compteur
  // (décision 1 du lot 4 : conservée, pas effacée, au retrait) -- pour que
  // ce tiroir déjà ouvert l'affiche immédiatement sans attendre un rebuild
  // externe.
  Future<int> Function(CounterType type)? onActivateCounter,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.greyShade800,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetCtx) => _PlayerDrawerBody(
      playerName: playerName,
      activeCounters: activeCounters,
      counters: counters,
      isMonarch: isMonarch,
      isEliminated: isEliminated,
      onCounterDelta: onCounterDelta,
      onToggleMonarch: () {
        Navigator.of(sheetCtx).pop();
        onToggleMonarch();
      },
      onEliminate: () {
        Navigator.of(sheetCtx).pop();
        onEliminate();
      },
      onResetCounters: () {
        Navigator.of(sheetCtx).pop();
        onResetCounters();
      },
      commanderDamage: commanderDamage,
      // Contrairement aux autres actions, taper ± sur la grille ne ferme
      // pas le tiroir (spec §2.7 : « filet de rattrapage » consulté à
      // chaud, éventuellement plusieurs fois).
      onCommanderDamageDelta: onCommanderDamageDelta,
      lethalCommanderDamage: lethalCommanderDamage,
      // Même logique que la grille de dégâts de commandant : créer ou
      // retirer un compteur ne ferme pas le tiroir non plus (on continue
      // souvent d'y ajuster d'autres compteurs juste après).
      onCreateCounter: onCreateCounter,
      onRemoveCounter: onRemoveCounter,
      inactiveCounters: inactiveCounters,
      onActivateCounter: onActivateCounter,
    ),
  );
}

class _PlayerDrawerBody extends StatefulWidget {
  const _PlayerDrawerBody({
    required this.playerName,
    required this.activeCounters,
    required this.counters,
    required this.isMonarch,
    required this.isEliminated,
    required this.onCounterDelta,
    required this.onToggleMonarch,
    required this.onEliminate,
    required this.onResetCounters,
    required this.commanderDamage,
    required this.onCommanderDamageDelta,
    required this.lethalCommanderDamage,
    required this.onCreateCounter,
    required this.onRemoveCounter,
    this.inactiveCounters = const [],
    this.onActivateCounter,
  });

  final String playerName;

  /// Compteurs actifs de la session, dans l'ordre d'affichage voulu
  /// (`GameSession.activeCounterIds`, résolus en `CounterType` par
  /// l'appelant) — pas l'ordre du catalogue.
  final List<CounterType> activeCounters;
  final Map<String, int> counters;
  final bool isMonarch;
  final bool isEliminated;
  final void Function(String counterId, int delta) onCounterDelta;
  final VoidCallback onToggleMonarch;
  final VoidCallback onEliminate;
  final VoidCallback onResetCounters;
  final List<CommanderDamageOpponent> commanderDamage;
  final void Function(int sourcePlayerId, int delta) onCommanderDamageDelta;
  final int lethalCommanderDamage;
  final Future<({bool success, String message})> Function(CounterType type)
      onCreateCounter;
  final void Function(String counterId) onRemoveCounter;

  /// Compteurs du catalogue non actifs dans CETTE partie (Critical 3, revue
  /// finale) -- voir le doc-comment de `showPlayerDrawer`.
  final List<CounterType> inactiveCounters;
  final Future<int> Function(CounterType type)? onActivateCounter;

  @override
  State<_PlayerDrawerBody> createState() => _PlayerDrawerBodyState();
}

class _PlayerDrawerBodyState extends State<_PlayerDrawerBody> {
  /// Copie locale : le tiroir reste ouvert pendant qu'on incrémente, et doit
  /// refléter le changement immédiatement sans attendre un rebuild de la page.
  late final Map<String, int> _values = Map<String, int>.from(widget.counters);

  /// Copie locale mutable, elle aussi (même raison) : créer ou retirer un
  /// compteur doit se refléter dans CE tiroir déjà ouvert, sans attendre un
  /// rebuild de la page qui l'a ouvert (`widget.activeCounters` reste, lui,
  /// figé à l'ouverture).
  late List<CounterType> _activeCounters =
      List<CounterType>.from(widget.activeCounters);

  /// Même raison qu'au-dessus (Critical 3, revue finale) : réactiver un
  /// compteur doit le retirer de CETTE liste locale immédiatement, sans
  /// attendre la fermeture/réouverture du tiroir.
  late List<CounterType> _inactiveCounters =
      List<CounterType>.from(widget.inactiveCounters);

  /// Même raison qu'au-dessus, pour les totaux de la grille de dégâts de
  /// commandant reçus.
  late final List<CommanderDamageOpponent> _commanderDamage =
      List<CommanderDamageOpponent>.from(widget.commanderDamage);

  /// Lot 5, tâche 5 (défaut trouvé par le test d'intégration) : plafonnait
  /// à 99 en dur, jamais à `type.maxValue` -- `GameSessionNotifier.updateCounter`
  /// (la vraie source de vérité) sature bien à la borne du compteur, mais
  /// cette copie locale d'affichage continuait de monter au-delà tant que ce
  /// tiroir restait ouvert : un compteur "Poison" (borne 10) affichait 11,
  /// 12... après saturation, avant de retomber à sa valeur réelle au
  /// prochain rebuild externe. Le joueur voyait donc un nombre qui ne
  /// correspondait à rien, dans le seul endroit où il s'attend à voir
  /// l'effet immédiat de son tap. `type` porte déjà cette borne : pas besoin
  /// d'un paramètre supplémentaire, seulement de le lire au lieu du 99 fixe.
  void _bump(CounterType type, int delta) {
    final maxValue = type.maxValue ?? 99;
    setState(() {
      _values[type.id] = ((_values[type.id] ?? 0) + delta).clamp(0, maxValue);
    });
    widget.onCounterDelta(type.id, delta);
  }

  /// Ouvre `CounterEditorDialog`, puis -- si l'utilisateur n'a pas annulé --
  /// délègue la sauvegarde réelle à `widget.onCreateCounter` (typiquement
  /// `CounterCatalogNotifier.saveCustomType` + activation immédiate dans la
  /// partie en cours, décision 2 du rapport de tâche).
  ///
  /// Le refus n'est jamais silencieux (contrainte du lot) : `result.message`
  /// est toujours affiché, succès ou échec -- un nom usurpant un intégré
  /// revient en échec avec un message exploitable (voir
  /// `CounterCatalogNotifier.saveCustomType`), et l'utilisateur reste dans
  /// le tiroir pour corriger, exactement comme une annulation.
  Future<void> _openCreateCounterDialog() async {
    final type = await CounterEditorDialog.show(context);
    if (type == null) return; // annulé : rien à créer.
    final result = await widget.onCreateCounter(type);
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _activeCounters = [..._activeCounters, type];
        _values[type.id] = 0;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  /// Réactive [type] (Critical 3, revue finale) : délègue à
  /// `widget.onActivateCounter` (typiquement
  /// `GameSessionNotifier.activateCounter(type.id, isCustom: !type.isBuiltIn)`),
  /// qui rend la valeur RÉELLE déjà portée par ce joueur pour ce compteur --
  /// pas un 0 arbitraire, sans quoi une réactivation dans la même partie où
  /// le compteur a été retiré (décision 1 du lot 4 : la valeur est
  /// conservée, pas effacée) réapparaîtrait à zéro dans CE tiroir jusqu'à sa
  /// fermeture/réouverture. Ne ferme pas le tiroir, même principe que la
  /// création et le retrait : on continue souvent d'y ajuster d'autres
  /// compteurs juste après.
  Future<void> _reactivateCounter(CounterType type) async {
    final onActivate = widget.onActivateCounter;
    if (onActivate == null) return;
    final value = await onActivate(type);
    if (!mounted) return;
    setState(() {
      _inactiveCounters = _inactiveCounters.where((t) => t.id != type.id).toList();
      _activeCounters = [..._activeCounters, type];
      _values[type.id] = value;
    });
  }

  /// Retire [id] des compteurs actifs affichés par CE tiroir, et transmet
  /// le retrait à `widget.onRemoveCounter` (qui désactive [id] dans la
  /// session -- `GameSessionNotifier.deactivateCounter`). Ne ferme pas le
  /// tiroir, sur le même principe que la grille de dégâts de commandant :
  /// on continue souvent d'y ajuster d'autres compteurs juste après.
  void _removeCounter(String id) {
    setState(() {
      final removed = _activeCounters.where((t) => t.id == id).toList();
      _activeCounters = _activeCounters.where((t) => t.id != id).toList();
      // Bascule symetrique de `_reactivateCounter` : sans elle, un joueur qui
      // tape le retrait par erreur ne voit rien lui proposer d'annuler, et doit
      // deviner qu'il faut refermer puis rouvrir le tiroir pour que la ligne
      // « Reactiver » apparaisse. Le retour est offert la ou l'erreur vient
      // d'etre commise.
      if (removed.isNotEmpty && widget.onActivateCounter != null) {
        _inactiveCounters = [..._inactiveCounters, ...removed];
      }
    });
    widget.onRemoveCounter(id);
  }

  void _bumpCommanderDamage(int sourcePlayerId, int delta) {
    setState(() {
      final index = _commanderDamage.indexWhere(
        (o) => o.playerId == sourcePlayerId,
      );
      if (index != -1) {
        final current = _commanderDamage[index];
        _commanderDamage[index] = CommanderDamageOpponent(
          playerId: current.playerId,
          name: current.name,
          colorValue: current.colorValue,
          damage: (current.damage + delta).clamp(0, 999),
        );
      }
    });
    widget.onCommanderDamageDelta(sourcePlayerId, delta);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        // La grille de dégâts de commandant reçus (lot 3) ajoute une ligne
        // par adversaire : à 8 joueurs, compteurs + grille + actions ne
        // tiennent plus dans un tiroir non scrollable. `SingleChildScrollView`
        // laisse le contenu déborder proprement plutôt que de le tronquer.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(widget.playerName, style: AppTextStyles.cardTitle()),
              const SizedBox(height: 14),
              for (final type in _activeCounters) _counterRow(type),
              _action(
                key: const ValueKey('action-create-counter'),
                icon: Icons.add_circle_outline,
                label: 'Nouveau compteur',
                color: AppColors.primary,
                // Ne ferme pas le tiroir (voir le doc-comment de
                // `_openCreateCounterDialog`) : appelé directement, pas via
                // le `Navigator.of(sheetCtx).pop()` des autres actions.
                onTap: _openCreateCounterDialog,
              ),
              // Critical 3 (revue finale) : les compteurs du catalogue non
              // actifs dans CETTE partie -- sans cette liste, un compteur
              // personnalisé créé ailleurs (ou un intégré retiré) restait
              // écrit dans `custom_counter_types` sans jamais être relu par
              // personne.
              for (final type in _inactiveCounters) _reactivateRow(type),
              // Ronde de correction 1 (Important, "seconde porte") : la
              // grille n'etait conditionnee par rien -- ni le seuil letal,
              // ni les compteurs actives par le format -- et s'affichait
              // donc meme en Standard. `lethalCommanderDamage <= 0` (0 =
              // desactive, voir GameFormat.maxCommanderDamage) est le meme
              // garde que celui qui protege deja la rangee d'attribution du
              // cadran cote page.
              if (widget.lethalCommanderDamage > 0) ...[
                const Divider(height: 26),
                CommanderDamageGrid(
                  opponents: _commanderDamage,
                  lethalThreshold: widget.lethalCommanderDamage,
                  onDelta: _bumpCommanderDamage,
                ),
              ],
              const Divider(height: 26),
              _action(
                key: const ValueKey('action-monarch'),
                icon: Icons.star,
                label: widget.isMonarch ? 'Retirer le monarque' : 'Monarque',
                color: AppColors.amber,
                onTap: widget.onToggleMonarch,
              ),
              _action(
                key: const ValueKey('action-eliminate'),
                icon: widget.isEliminated ? Icons.undo : Icons.person_off,
                label: widget.isEliminated
                    ? 'Annuler l\'élimination'
                    : 'Éliminer',
                color: AppColors.accentRed,
                onTap: widget.onEliminate,
              ),
              _action(
                key: const ValueKey('action-reset'),
                icon: Icons.restart_alt,
                label: 'Réinitialiser les compteurs',
                color: AppColors.textSecondary,
                onTap: widget.onResetCounters,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterRow(CounterType type) {
    final id = type.id;
    // Clé posée sur la ligne entière (pas seulement les boutons) : c'est
    // elle que les tests ciblent pour vérifier QUEL compteur a bougé,
    // conformément au brief (ValueKey('counter_row_<id>')) — le même motif
    // que le bug du lot 4 sur le bouton "−" (bon nombre de lignes, mauvais
    // joueur) mais appliqué aux compteurs plutôt qu'aux joueurs.
    return Padding(
      key: ValueKey('counter_row_$id'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(type.name, style: AppTextStyles.body()),
          ),
          IconButton(
            key: ValueKey('counter_row_${id}_minus'),
            icon: const Icon(Icons.remove),
            color: AppColors.textSecondary,
            onPressed: () => _bump(type, -1),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${_values[id] ?? 0}',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle(),
            ),
          ),
          IconButton(
            key: ValueKey('counter_row_${id}_plus'),
            icon: const Icon(Icons.add),
            color: AppColors.textSecondary,
            onPressed: () => _bump(type, 1),
          ),
          // Retrait des compteurs ACTIFS de la partie (lot 5, tâche 4) --
          // pas une suppression du catalogue : un compteur intégré ne peut
          // pas en être retiré, mais peut être retiré des actifs comme un
          // personnalisé, ligne comprise (contrainte du lot). La valeur du
          // joueur pour ce compteur est conservée (décision 1 du rapport,
          // voir GameSessionNotifier.deactivateCounter) : elle réapparaît
          // intacte si le compteur est réactivé plus tard.
          IconButton(
            key: ValueKey('counter_row_${id}_remove'),
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textMuted,
            tooltip: 'Retirer ce compteur de la partie',
            onPressed: () => _removeCounter(id),
          ),
        ],
      ),
    );
  }

  /// Ligne de réactivation d'un compteur du catalogue non actif dans cette
  /// partie (Critical 3, revue finale) -- voir `_reactivateCounter`. Clé
  /// publique du brief pour les tests (`counter_reactivate_<id>`), même
  /// convention que `counter_row_<id>`.
  Widget _reactivateRow(CounterType type) {
    return _action(
      key: ValueKey('counter_reactivate_${type.id}'),
      icon: Icons.replay,
      label: 'Réactiver ${type.emoji} ${type.name}',
      color: AppColors.textSecondary,
      onTap: () => _reactivateCounter(type),
    );
  }

  Widget _action({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTextStyles.body()),
      onTap: onTap,
    );
  }
}
