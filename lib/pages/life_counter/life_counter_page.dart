// Fichier : lib/pages/life_counter/life_counter_page.dart
//
// "Les points de vie ne sont qu'un chiffre.
//  La volonte de vaincre, elle, est infinie."
//  — Monkey D. Luffy (probablement, s'il jouait a Magic)
//
// Note au developpeur curieux : chaque point de vie perdu
// est une aventure gagnee. Chaque partie terminee est une
// ile conquise sur le Grand Line. Continue a naviguer, Nakama.

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_history_model.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/models/profile_model.dart'; // CommanderEntry, Profile
import 'package:magic_companion/services/game_history_service.dart';
import 'package:magic_companion/services/game_session_service.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/damage_history_sheet.dart';
import 'package:magic_companion/widgets/life_counter/player_history_sheet.dart';
import '../../widgets/life_counter/zone/player_drawer.dart';
import '../../widgets/life_counter/zone/commander_damage_grid.dart';
import '../../widgets/life_counter/zone/damage_attribution_row.dart';
import '../../widgets/life_counter/zone/action_hub.dart';
import '../../widgets/life_counter/dice_roll_dialog.dart';
import '../../widgets/life_counter/game_setup_modal.dart';
import '../../widgets/life_counter/layouts/adaptive_grid.dart';
import '../../widgets/life_counter/layouts/table_layout.dart';
import '../../models/table_seat.dart';
import '../../widgets/life_counter/critical_overlay.dart';
import '../../widgets/life_counter/elimination_overlay.dart';
import '../../widgets/life_counter/death_confirmation_overlay.dart';
import '../../widgets/life_counter/draggable_player_zone.dart';
import '../../widgets/life_counter/animations/animation_service.dart';
import '../../widgets/life_counter/snapshot_writer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../router/app_router.dart';

class LifeCounterPage extends ConsumerStatefulWidget {
  /// US-LC02 : Quand true, la page est dans le shell (tab0) et ne rend pas d'AppBar.
  final bool isInShell;

  const LifeCounterPage({super.key, this.isInShell = false});

  @override
  ConsumerState<LifeCounterPage> createState() => _LifeCounterPageState();
}

class _LifeCounterPageState extends ConsumerState<LifeCounterPage> {
  GameHistoryService get _gameHistoryService => ref.read(gameHistoryServiceProvider);

  // Résolu une seule fois, dans `initState()` (voir plus bas) : `dispose()`
  // ne doit jamais toucher à `ref` (une revue précédente a relevé comme
  // point sain que dispose() en était indemne). `late final` sans
  // initialiseur inline évite qu'un premier accès tardif ne tombe justement
  // dans `dispose()` — l'affectation explicite en tête d'`initState()`
  // garantit que la résolution a lieu bien avant tout chemin de démontage.
  late final GameSessionService _sessionService;

  // --- Notifier-based state ---
  // `_controller` reste un getter : il ne fait qu'exposer le notifier, il ne
  // le détient pas. `ref.read` est utilisé ici (et non `ref.watch`, interdit
  // hors de `build()`) car ce getter est appelé depuis des callbacks
  // (`_updateLife`, `_saveSnapshot`, `_onReorderPlayers`, etc.).
  // L'abonnement qui déclenche les rebuilds est établi explicitement en
  // première ligne de `build()`.
  GameSessionNotifier get _controller =>
      ref.read(gameSessionNotifierProvider.notifier);
  GameSession? get _session => ref.read(gameSessionNotifierProvider);

  // Dernier état dérivé de la session encore détenu par la page ? Non : un
  // getter. `_session?.format` est toujours à jour (aucun champ à
  // synchroniser), y compris entre la restauration d'un snapshot et le
  // premier rebuild.
  GameFormat get _currentFormat =>
      _session?.format ?? GameFormat.builtInFormats.first; // Commander

  bool _isLoading = true;

  // Death confirmation state
  final Map<int, Timer> _deathTimers = {};
  final Set<int> _showDeathOverlay = {};
  final Set<int> _dismissedDeathOverlay = {};

  // Edit mode state
  bool _isEditMode = false;

  // Ronde de correction 2 (tâche 5) : `MediaQuery.sizeOf(context)` donne la
  // taille de l'ÉCRAN, pas celle que `AdaptiveGrid` reçoit réellement de son
  // propre `LayoutBuilder` -- un `Scaffold` porteur d'une
  // `bottomNavigationBar` (le shell de production, `AppShellScaffold`)
  // ampute cette dernière de la hauteur de la barre. Deux sources de vérité
  // sur la géométrie, la même classe de défaut que le double-pivotement du
  // lot 6 et que la ronde de correction précédente de cette tâche. Cette clé
  // permet de lire la taille RÉELLEMENT mesurée par la grille (après sa
  // disposition), au lieu de la deviner depuis l'écran.
  final GlobalKey _gridKey = GlobalKey();

  /// Taille réellement occupée par `AdaptiveGrid`, lue sur son `RenderBox`
  /// après disposition -- jamais mutée pendant un `build()`, seulement lue
  /// depuis des callbacks post-frame (gestes, feuilles modales).
  ///
  /// Retombée sur `MediaQuery.sizeOf(context)` si la grille n'a pas encore de
  /// contexte (premier appel avant le tout premier `build()`, ou test qui
  /// n'a monté que la grille sans lui laisser une frame) : c'est la taille de
  /// l'écran, donc potentiellement en excès de la hauteur d'une barre de
  /// navigation -- une approximation, pas la source de vérité, et signalée
  /// comme telle ici plutôt que silencieuse.
  Size _measuredGridSize(BuildContext context) {
    final renderObject = _gridKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return MediaQuery.sizeOf(context);
  }

  // History sheet state
  int? _historyFilterPlayerId;

  // Life point buffer system (Bug 4)
  final Map<int, int> _pendingDamage = {};
  final Map<int, Timer> _pendingTimers = {};

  // Commander damage flash (Bug 3)
  final Set<int> _commanderDamageFlash = {};

  // Commander gallery per player (from profile)
  final Map<int, List<CommanderEntry>> _playerCommanderGalleries = {};

  int? _highlightedPlayerId;
  bool _isSelectingStarter = false;

  Timer? _gameTimer;
  Duration get _gameDuration => _session?.duration ?? Duration.zero;
  bool get _isGameActive => _session?.isActive ?? false;

  // Écriture différée du snapshot : débounce, capture de la session à
  // écrire (pour que `dispose()` n'ait rien à relire via `ref`), et suivi de
  // l'écriture en vol (pour que la fin de partie puisse l'attendre avant
  // `clearSnapshot()`). Voir `snapshot_writer.dart` pour le détail de ces
  // trois garanties.
  late final SnapshotWriter _snapshotWriter;

  final List<Color> _defaultColors = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900,
    Colors.brown.shade800, Colors.pink.shade900, Colors.indigo.shade900, AppColors.greyShade800
  ];

  // --- Legacy Player bridge ---
  Player _toLegacyPlayer(int index, PlayerState ps) {
    // Include pending (buffered) damage in displayed life
    final pending = _pendingDamage[ps.playerId] ?? 0;
    return Player(
      // Use the real playerId (not the display index) so callbacks target the correct PlayerState
      id: ps.playerId,
      name: ps.config.name,
      life: ps.life + pending,
      colorValue: ps.config.colorValue,
      backgroundImagePath: ps.config.avatarPath,
      commanderDamageReceived: Map<int, int>.from(ps.commanderDamageReceived),
      poison: ps.counters['poison'] ?? 0,
      energy: ps.counters['energy'] ?? 0,
      commanderCastCount: ps.counters['commander_tax'] ?? 0,
      isMonarch: ps.isMonarch,
      quarterTurns: ps.quarterTurns,
      commanderGallery: _playerCommanderGalleries[ps.playerId] ?? [],
    );
  }

  /// Ordre d'affichage des zones. `_session.players` garde l'ordre canonique
  /// (players[i].playerId == i) ; `playerOrder` porte seul la disposition
  /// choisie par le joueur en mode édition.
  List<PlayerState> get _orderedPlayers {
    final session = _session;
    if (session == null) return const [];
    final order = session.playerOrder;
    if (order.length != session.players.length) return session.players;
    final byId = {for (final p in session.players) p.playerId: p};
    final ordered = <PlayerState>[];
    for (final id in order) {
      final p = byId[id];
      if (p == null) return session.players; // ordre corrompu : repli sûr
      ordered.add(p);
    }
    return ordered;
  }

  List<Player> get _legacyPlayers {
    if (_session == null) return [];
    return _orderedPlayers
        .asMap()
        .entries
        .map((e) => _toLegacyPlayer(e.key, e.value))
        .toList();
  }

  /// Vue "legacy" des joueurs en ordre canonique (`playerId` croissant), pour
  /// les lectures métier qui ont besoin des champs du modèle `Player` (ex.
  /// sauvegarde de l'historique) mais ne doivent pas dépendre de l'ordre
  /// d'affichage — contrairement à `_legacyPlayers`, qui suit `_orderedPlayers`
  /// et est réservé au rendu des zones.
  List<Player> get _legacyPlayersCanonical {
    final session = _session;
    if (session == null) return [];
    return session.players
        .asMap()
        .entries
        .map((e) => _toLegacyPlayer(e.key, e.value))
        .toList();
  }

  int get _playerCount => _session?.players.length ?? 0;
  int get _startingLife => _currentFormat.startingLife;

  @override
  void initState() {
    super.initState();
    // Résolution précoce et unique : garantit que `dispose()` n'a jamais à
    // évaluer ce champ lui-même (voir sa déclaration plus haut).
    _sessionService = ref.read(gameSessionServiceProvider);
    _snapshotWriter = SnapshotWriter(_sessionService);
    _loadGame();
    WakelockPlus.enable();
    // Immersive fullscreen — hide status bar + navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _deathTimers.forEach((_, t) => t.cancel());
    _pendingTimers.forEach((_, t) => t.cancel());

    // Flush du débounce de snapshot : écrit une dernière fois la session
    // capturée au dernier `schedule()`, s'il y en a une. Synchrone, et ne
    // touche à aucun provider (voir `SnapshotWriter.disposeAndFlush`).
    _snapshotWriter.disposeAndFlush();

    // Restore system UI when leaving the page
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  // --- LOGIQUE TIMER ---

  // I-4 (cas b) : nombre de tick() (secondes) écoulés depuis la dernière
  // persistance périodique du chrono actif — voir `_startTickTimer`.
  int _ticksSincePeriodicSnapshot = 0;

  // I-4 (cas b) : une partie mise en pause (chrono actif, aucun PV modifié)
  // puis tuée perd tout ce qui s'est écoulé depuis le dernier `_saveSnapshot()`
  // explicite. On borne cette perte en persistant toutes les 30 s de chrono
  // actif, plutôt qu'à chaque `tick()` (1/s) — ce qui rétablirait l'I/O par
  // seconde que le débounce de `_saveSnapshot` (voir plus bas) vient de
  // supprimer. 30 s reste un compromis : la fenêtre de perte résiduelle
  // maximale (cas b) passe de « toute la pause » à « 30 s », sans écriture
  // fréquente.
  static const _periodicSnapshotEveryTicks = 30;

  /// Démarre (ou relance, à la reprise) le `Timer.periodic` local qui pousse
  /// des `tick()` vers le notifier, et programme la persistance périodique
  /// du cas (b) ci-dessus. Utilisé par `_startGame()` et par la reprise d'une
  /// session active dans `_loadGame()`.
  void _startTickTimer() {
    _gameTimer?.cancel();
    _ticksSincePeriodicSnapshot = 0;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _controller.tick();
      _ticksSincePeriodicSnapshot++;
      if (_ticksSincePeriodicSnapshot >= _periodicSnapshotEveryTicks) {
        _ticksSincePeriodicSnapshot = 0;
        _saveSnapshot();
      }
    });
  }

  void _startGame() {
    _controller.startTimer();
    _startTickTimer();
    setState(() {});
    // I-4 (cas a) : sans cette écriture, un crash survenant juste après le
    // lancement du chrono (avant toute modification de PV) restaure une
    // session `isActive: false` — le chrono ne reprend pas au chargement.
    _saveSnapshot();
  }

  void _stopGame() {
    _gameTimer?.cancel();
    _controller.stopTimer();
    setState(() {});
    // I-4 : symétrique du fix de `_startGame()` — persiste l'arrêt du chrono.
    _saveSnapshot();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$minutes' : '$minutes:$seconds';
  }

  // --- SAUVEGARDE & CHARGEMENT ---
  Future<void> _loadGame() async {
    final sessionService = ref.read(gameSessionServiceProvider);

    final hasActiveGame = await sessionService.hasActiveGame();
    // Garde après chaque `await` : si la page a été démontée pendant l'attente,
    // tout accès à `ref` (via _controller/_session) ou tout setState planterait.
    if (!mounted) return;
    if (hasActiveGame) {
      final snapshot = await sessionService.loadSnapshot();
      if (!mounted) return;
      if (snapshot != null) {
        _controller.restoreSession(snapshot);
        // `_currentFormat` (getter dérivé de `_session?.format`) reflète déjà
        // `snapshot.format` : `restoreSession` a mis à jour le state du
        // notifier de façon synchrone, avant même ce `setState`.
        setState(() {
          _isLoading = false;
        });
        if (snapshot.isActive) {
          _startTickTimer();
        }
        return;
      }
    }

    // No saved game -- start fresh with defaults
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final playerCount = prefs.getInt('playerCount') ?? 4;
    final formatId = prefs.getString('formatId') ?? 'commander';
    final format = GameFormat.builtInFormats.firstWhere(
      (f) => f.id == formatId,
      orElse: () => GameFormat.builtInFormats.first,
    );

    // Passé explicitement : au moment de cet appel, `_currentFormat` (getter
    // dérivé de `_session?.format`) ne reflète pas encore ce format-là — il
    // n'y a pas encore de session, ou c'est celle d'une partie précédente.
    _startNewGame(playerCount: playerCount, format: format);
    setState(() => _isLoading = false);
  }

  /// [format] permet d'imposer le format de la nouvelle session lorsque
  /// `_currentFormat` (dérivé de `_session?.format`) ne désigne pas encore le
  /// format voulu à cet instant — la restauration des préférences par défaut
  /// dans `_loadGame()`, ou le format choisi dans `GameSetupModal`. Sans
  /// argument, la partie garde le format de la session actuelle (simple
  /// reset).
  void _startNewGame({
    required int playerCount,
    List<Profile?>? assignedProfiles,
    GameFormat? format,
  }) {
    final effectiveFormat = format ?? _currentFormat;
    // Store commander galleries from profiles for quick artwork switching
    _playerCommanderGalleries.clear();
    final configs = List.generate(playerCount, (index) {
      final profile = (assignedProfiles != null && index < assignedProfiles.length)
          ? assignedProfiles[index]
          : null;
      final name = profile?.name ?? 'Joueur ${index + 1}';
      final color = profile?.colorValue ?? _defaultColors[index % _defaultColors.length].toARGB32();

      if (profile != null && profile.commanderGallery.isNotEmpty) {
        _playerCommanderGalleries[index] = List.from(profile.commanderGallery);
      }

      return PlayerConfig(
        id: 'player_$index',
        name: name,
        type: index == 0 ? PlayerType.owner : PlayerType.guest,
        colorValue: color,
        avatarPath: profile?.commanderImageUrl,
      );
    });

    _controller.startNewGame(format: effectiveFormat, playerConfigs: configs);

    // Dette du lot 3 (revue) : `PlayerZoneNotifier` n'est pas `autoDispose`,
    // son état (mode ajustement, accumulateurs, nombres flottants en cours)
    // traverse donc le cycle de vie des parties. Sans ce reset, une zone
    // pouvait rouvrir une nouvelle partie déjà en mode ajustement, sans que
    // l'utilisateur ait rien fait. Les identifiants de joueur d'une partie
    // sont toujours 0..playerCount-1 (voir GameSession.newGame).
    for (var i = 0; i < playerCount; i++) {
      ref.read(playerZoneNotifierProvider(i).notifier).reset();
    }

    setState(() {});
    _saveSnapshot();

    // Persist defaults for next launch
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('playerCount', playerCount);
      prefs.setString('formatId', effectiveFormat.id);
    });
  }

  /// Point d'entrée de test pour déclencher `_saveSnapshot()` directement,
  /// sans passer par un des 12 sites d'appel (taps, reorder, etc.).
  @visibleForTesting
  void saveSnapshotForTest() => _saveSnapshot();

  /// Point d'entrée de test pour lancer le chrono (I-4) sans passer par le
  /// dialogue de tirage du premier joueur (`_pickStartingPlayer`), dont
  /// l'animation aléatoire rendrait le test fragile.
  @visibleForTesting
  void startGameForTest() => _startGame();

  /// Écriture différée : les mutations arrivent par rafales (un tap = une
  /// mutation), et sérialiser toute la session à chaque fois coûte une I/O
  /// par tap. La session à écrire est capturée ici (où `ref` est valide),
  /// via `_session`, avant d'être remise à `_snapshotWriter` — qui n'a plus
  /// besoin de rien lire via `ref` pour programmer, différer ou flusher
  /// l'écriture (voir `snapshot_writer.dart`).
  void _saveSnapshot() {
    final session = _session;
    if (session == null) return;
    _snapshotWriter.schedule(session);
  }

  // --- DEATH CONFIRMATION ---
  /// Returns a death reason string if the player meets any loss condition, or null.
  String? _getDeathReason(PlayerState player) {
    if (player.isEliminated) return null;

    // Life at 0 check
    if (_currentFormat.lethalAtZeroLife && player.life <= 0) {
      return 'life';
    }
    // Poison check
    final poison = player.counters['poison'] ?? 0;
    if (_currentFormat.maxPoison > 0 && poison >= _currentFormat.maxPoison) {
      return 'poison';
    }
    // Commander damage check (any single source)
    if (_currentFormat.maxCommanderDamage > 0) {
      for (final dmg in player.commanderDamageReceived.values) {
        if (dmg >= _currentFormat.maxCommanderDamage) {
          return 'commander';
        }
      }
    }
    return null;
  }

  // Tracks the death reason per player for overlay message
  final Map<int, String> _deathReasons = {};

  void _checkDeathCondition(int playerId) {
    final player = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
    if (player == null) return;

    final reason = _getDeathReason(player);
    if (reason != null && !_dismissedDeathOverlay.contains(playerId)) {
      _deathReasons[playerId] = reason;
      if (!_deathTimers.containsKey(playerId)) {
        _deathTimers[playerId] = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          final currentPlayer = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
          if (currentPlayer != null && _getDeathReason(currentPlayer) != null) {
            setState(() => _showDeathOverlay.add(playerId));
          }
          _deathTimers.remove(playerId);
        });
      }
    } else {
      _deathReasons.remove(playerId);
      _deathTimers[playerId]?.cancel();
      _deathTimers.remove(playerId);
      setState(() => _showDeathOverlay.remove(playerId));
    }
  }

  void _dismissDeath(int playerId) {
    setState(() {
      _showDeathOverlay.remove(playerId);
      _dismissedDeathOverlay.add(playerId);
    });
  }

  void _confirmElimination(int playerId) {
    _controller.eliminatePlayer(playerId, atDuration: _gameDuration);
    setState(() {
      _showDeathOverlay.remove(playerId);
    });
    _saveSnapshot();
    _checkLastSurvivor();
  }

  /// If only one non-eliminated player remains, auto-end the game with that player as winner.
  void _checkLastSurvivor() {
    if (_session == null) return;
    final alive = _session!.players.where((p) => !p.isEliminated).toList();
    if (alive.length != 1) return;
    // Only 2+ player games can end by elimination
    if (_session!.players.length < 2) return;

    final winner = _toLegacyPlayer(
      _session!.players.indexOf(alive.first),
      alive.first,
    );

    // Short delay so the elimination animation plays before the victory dialog
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      // Double-check state hasn't changed (e.g. undo during delay)
      final currentAlive = _session?.players.where((p) => !p.isEliminated).toList();
      if (currentAlive == null || currentAlive.length != 1) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: Center(
            child: Text('Victoire !', style: AppTextStyles.cinzel(color: AppColors.primary)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 60, color: Color(winner.colorValue)),
              const SizedBox(height: 16),
              Text(
                winner.name,
                style: AppTextStyles.pageTitle(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Dernier survivant !',
                style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _finalizeGameSave(winner, 'elimination');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color(winner.colorValue)),
              child: const Text('Enregistrer la partie', style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
      );
    });
  }

  // --- COMMANDER DAMAGE FLASH (Bug 3) ---
  void _triggerCommanderDamageFlash(int playerId) {
    setState(() => _commanderDamageFlash.add(playerId));
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _commanderDamageFlash.remove(playerId));
    });
  }

  // --- ACTIONS JOUEURS ---
  void _resetGame({List<Profile?>? assignedProfiles, GameFormat? format}) {
    _stopGame();
    setState(() {
      _deathTimers.forEach((_, t) => t.cancel());
      _deathTimers.clear();
      _pendingTimers.forEach((_, t) => t.cancel());
      _pendingTimers.clear();
      _pendingDamage.clear();
      _showDeathOverlay.clear();
      _dismissedDeathOverlay.clear();
    });

    final count = assignedProfiles?.length ?? _playerCount;
    _startNewGame(
      playerCount: count > 0 ? count : 4,
      assignedProfiles: assignedProfiles,
      format: format,
    );
  }

  void _updateLife(int playerId, int change) {
    if (_isSelectingStarter) return;
    if (_session == null) return;

    // Buffer system: accumulate changes and apply after 2s inactivity
    _pendingDamage[playerId] = (_pendingDamage[playerId] ?? 0) + change;
    _pendingTimers[playerId]?.cancel();
    _pendingTimers[playerId] = Timer(const Duration(seconds: 2), () {
      _applyPendingDamage(playerId);
    });
    setState(() {}); // Refresh to show pending delta overlay
  }

  void _applyPendingDamage(int playerId) {
    final pending = _pendingDamage[playerId];
    if (pending == null || pending == 0) {
      _pendingDamage.remove(playerId);
      _pendingTimers.remove(playerId);
      setState(() {});
      return;
    }
    _controller.updateLife(playerId, pending, gameDuration: _gameDuration);
    _pendingDamage.remove(playerId);
    _pendingTimers.remove(playerId);
    setState(() {});
    _saveSnapshot();
    _checkDeathCondition(playerId);
  }

  /// Adversaires proposes par la rangee d'attribution (spec S2.6) pour le
  /// joueur [playerId] dont le buffer tourne : tous les autres joueurs de
  /// la session, sans le total qu'ils ont deja infligé (contrairement à
  /// `CommanderDamageOpponent` de la grille du tiroir — voir le type
  /// `DamageAttributionOpponent`, qui n'en a pas besoin).
  List<DamageAttributionOpponent> _attributionOpponents(int playerId) {
    final session = _session;
    if (session == null) return const [];
    return session.players
        .where((other) => other.playerId != playerId)
        .map((other) => (
              playerId: other.playerId,
              name: other.config.name,
              colorValue: other.config.colorValue,
            ))
        .toList();
  }

  /// Attribution a la volee (spec S2.6) : CONSOMME le degat en attente de
  /// [targetPlayerId], il ne s'en ajoute pas un second. Annule le minuteur
  /// en attente, retire l'entree de `_pendingDamage`, puis applique le
  /// montant absolu via `addCommanderDamage` — seul chemin d'ecriture des
  /// degats de commandant, qui ajuste déjà la vie lui-même (plancher à 0
  /// inclus, voir GameSessionNotifier.addCommanderDamage).
  ///
  /// Piège du signe : `pending` est negatif pour un degat (buffer alimenté
  /// par des taps -1), alors que `addCommanderDamage` attend un `damage`
  /// positif et retire les PV lui-même — `.abs()` est donc indispensable
  /// ici, pas optionnel.
  ///
  /// Ronde de correction 1 (Critical) : `pending >= 0` sort tot, en plus du
  /// garde d'affichage de `_buildPlayerZoneWithOverlays` — ceinture et
  /// bretelles, puisque `onAttribute` est capturee dans une closure qui peut
  /// survivre une frame au changement de signe (ex. un +1 arrive entre le
  /// build qui a affiche la rangee et le tap qui l'attribue). Sans ce garde,
  /// un buffer positif (lifelink) deviendrait un degat de commandant en plus
  /// d'une perte de vie generique — l'inverse total de l'intention du
  /// joueur.
  void _attributeCommanderDamage(int targetPlayerId, int sourcePlayerId) {
    final pending = _pendingDamage[targetPlayerId];
    if (pending == null || pending >= 0) return;
    _pendingTimers[targetPlayerId]?.cancel();
    _pendingTimers.remove(targetPlayerId);
    _pendingDamage.remove(targetPlayerId);
    _controller.addCommanderDamage(
      targetPlayerId: targetPlayerId,
      sourcePlayerId: sourcePlayerId,
      damage: pending.abs(),
      gameDuration: _gameDuration,
    );
    setState(() {});
    _saveSnapshot();
    // Important #3 (ronde de correction 1) : meme signal visuel que
    // `_onDrawerCommanderDamage` pour le meme evenement — l'attribution a la
    // volee est precisement le geste ou l'utilisateur a besoin de la
    // confirmation que son tap a ete compris comme du commander damage.
    _triggerCommanderDamageFlash(targetPlayerId);
    _checkDeathCondition(targetPlayerId);
  }

  void _updatePlayerColor(int playerId, Color color) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(config: p.config.copyWith(colorValue: color.toARGB32()));
      }
      return p;
    }).toList();
    _controller.restoreSession(_session!.copyWith(players: players));
    setState(() {});
    _saveSnapshot();
  }

  void _updatePlayerRotation(int playerId, int rotation) {
    if (_session == null) return;
    _controller.updateRotation(playerId, rotation);
    setState(() {});
    _saveSnapshot();
  }

  void _updatePlayerSkin(int playerId, String? path) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(config: p.config.copyWith(avatarPath: path));
      }
      return p;
    }).toList();
    _controller.restoreSession(_session!.copyWith(players: players));
    setState(() {});
    _saveSnapshot();
  }

  Future<void> _pickStartingPlayer() async {
    if (_isSelectingStarter) return;
    final players = _legacyPlayers;
    if (players.isEmpty) return;
    // I-2 : `orderedPlayers[idx].playerId` — jamais `idx` lui-même — pour
    // que `_highlightedPlayerId` (comparé à `p.id` dans `_buildPlayerZone`)
    // et le gagnant annoncé dans le dialogue désignent toujours le même
    // joueur, y compris après un reorder (où index d'affichage != playerId).
    final orderedPlayers = _orderedPlayers;
    setState(() => _isSelectingStarter = true);
    int turns = 20; int currentIdx = Random().nextInt(_playerCount); int delay = 50;
    for (int i = 0; i < turns; i++) {
      setState(() => _highlightedPlayerId =
          orderedPlayers[currentIdx % _playerCount].playerId);
      await Future.delayed(Duration(milliseconds: delay));
      delay += (i * 2); currentIdx++;
    }
    final winnerPlayerId =
        orderedPlayers[(currentIdx - 1) % _playerCount].playerId;
    final winner = players.firstWhere((p) => p.id == winnerPlayerId);
    if (mounted) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: Center(child: Text('Le Destin a choisi !', style: AppTextStyles.cinzel(color: AppColors.textSecondary))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 50, color: Color(winner.colorValue)),
              const SizedBox(height: 16),
              Text(winner.name, style: AppTextStyles.pageTitle(fontSize: 32), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(context); setState(() { _highlightedPlayerId = null; _isSelectingStarter = false; }); _startGame(); },
              style: ElevatedButton.styleFrom(backgroundColor: Color(winner.colorValue)),
              child: const Text("C'est parti !", style: TextStyle(color: AppColors.textPrimary))
            )
          ]
        ),
      );
    }
  }

  /// Point d'entrée de test pour `_pickStartingPlayer()` (I-2) — le tirage
  /// réel est piloté par une boucle de délais aléatoires croissants, dont
  /// le fake clock du test peut traverser d'un coup via `tester.pump`.
  @visibleForTesting
  Future<void> pickStartingPlayerForTest() => _pickStartingPlayer();

  /// Point d'entrée de test : expose `_highlightedPlayerId` (I-2), inutile
  /// hors des tests puisqu'il ne sert qu'au rendu de `PlayerZone`.
  @visibleForTesting
  int? get highlightedPlayerIdForTest => _highlightedPlayerId;

  void _showGameSetupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldBackground,
      builder: (ctx) => GameSetupModal(
        initialLife: _startingLife,
        onGameStart: (format, profiles) {
          _resetGame(assignedProfiles: profiles, format: format);
        },
      )
    );
  }

  void _endGame() {
    final players = _legacyPlayers;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: Text('Qui a gagné ?', style: AppTextStyles.cinzel()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: players.map((p) {
              return ListTile(
                leading: Icon(Icons.emoji_events, color: Color(p.colorValue)),
                title: Text(p.name, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showWinMethodDialog(p);
                },
              );
            }).toList(),
          ),
        );
      }
    );
  }

  void _showWinMethodDialog(Player winner) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: Text('Type de victoire ?', style: AppTextStyles.cinzel()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.favorite, color: AppColors.accentRed),
                title: const Text('Points de Vie (Standard)', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () { Navigator.of(dialogCtx).pop(); _finalizeGameSave(winner, 'normal'); },
              ),
              ListTile(
                leading: const Icon(Icons.shield, color: AppColors.accent),
                title: const Text('Dégâts de Commandant', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () { Navigator.of(dialogCtx).pop(); _finalizeGameSave(winner, 'commander'); },
              ),
              ListTile(
                leading: const Icon(Icons.science, color: AppColors.accentGreen),
                title: const Text('Poison / Infect', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () { Navigator.of(dialogCtx).pop(); _finalizeGameSave(winner, 'poison'); },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: AppColors.textSecondary),
                title: const Text('Concession', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () { Navigator.of(dialogCtx).pop(); _finalizeGameSave(winner, 'concede'); },
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _finalizeGameSave(Player winner, String method) async {
    // Bug 5 fix: Dialog is already closed by caller using dialog's own context
    if (!mounted) return;

    // Lecture métier (sauvegarde de l'historique de fin de partie) : ordre
    // canonique, pas l'ordre d'affichage — `game_history_page.dart` et
    // `game_history_detail_page.dart` restituent `playerStates` dans l'ordre
    // où il a été sauvegardé.
    final players = _legacyPlayersCanonical;

    // Création des snapshots des joueurs
    List<PlayerHistorySnapshot> snapshots = players.map((p) {
      int totalCmdDmgTaken = p.commanderDamageReceived.values.fold(0, (sum, val) => sum + val);
      return PlayerHistorySnapshot(
        name: p.name,
        imageUrl: p.backgroundImagePath,
        life: p.life,
        poison: p.poison,
        commanderDamageTaken: totalCmdDmgTaken,
      );
    }).toList();

    final newItem = GameHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      durationSeconds: _gameDuration.inSeconds,
      winnerName: winner.name,
      format: _currentFormat.name,
      winMethod: method,
      playerStates: snapshots,
    );

    // End game state immediately (no UI blocking)
    _controller.endGame();
    _stopGame();
    setState(() {});

    // La partie est terminée : toute écriture différée en attente doit être
    // annulée avant `clearSnapshot()`, sans quoi un flush retardataire
    // réécrirait le snapshot d'une partie déjà terminée juste après sa
    // suppression. `cancelPending()` annule ce qui n'est pas encore parti
    // *synchroniquement*, dès cet appel — avant toute suspension plus bas —
    // et ne fait qu'attendre, elle, une écriture déjà en vol (que l'annulation
    // ne peut plus rattraper) : sans cette attente, une telle écriture
    // pourrait se terminer après le clear et ressusciter la partie qu'on
    // vient de terminer.
    final snapshotCancelled = _snapshotWriter.cancelPending();

    // Bug 6 fix: Fire DB writes asynchronously without blocking UI
    Future.microtask(() async {
      await _gameHistoryService.addGame(newItem);
      await snapshotCancelled;
      await _sessionService.clearSnapshot();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Partie enregistrée dans l'historique !"), backgroundColor: AppColors.success),
      );
    }
  }

  /// Point d'entrée de test pour déclencher la sauvegarde de fin de partie
  /// sans naviguer la chaîne de dialogues (`_endGame` → `_showWinMethodDialog`).
  /// Résout le gagnant par `playerId` (identité métier), pas par position
  /// d'affichage.
  @visibleForTesting
  Future<void> finalizeGameSaveForTest(int winnerId, String method) {
    final winner = _legacyPlayersCanonical.firstWhere((p) => p.id == winnerId);
    return _finalizeGameSave(winner, method);
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    // Établit l'abonnement Riverpod : sans ce watch explicite, le getter
    // `_session` (qui utilise `ref.read`) ne déclencherait aucun rebuild
    // quand le notifier change d'état.
    //
    // ⚠️ AVERTISSEMENT AU PROCHAIN ÉDITEUR : toute la réactivité de cette
    // page tient à cette ligne étant la TOUTE PREMIÈRE instruction de
    // `build()`. N'ajoute jamais de `return` (garde, early-exit, etc.)
    // au-dessus d'elle : ça casserait silencieusement la réactivité de
    // toute la page — aucune erreur, juste un écran qui ne se met plus à
    // jour.
    ref.watch(gameSessionNotifierProvider);
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));

    final players = _legacyPlayers;
    final orderedPlayers = _orderedPlayers;
    final playerZones = players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      // `orderedPlayers` porte le même ordre que `players` (les deux dérivent
      // de `_orderedPlayers`) : indexer par `index` reste correct après un
      // reorder, contrairement à `_session!.players[index]` qui suit l'ordre
      // canonique.
      final playerState = orderedPlayers[index];

      Widget zone = _buildPlayerZoneWithOverlays(player, playerState, index);

      if (_isEditMode) {
        zone = DraggablePlayerZone(
          index: index,
          onReorder: _onReorderPlayers,
          child: zone,
        );
      }

      // Clé d'identité stable par joueur CANONIQUE (playerState.playerId),
      // pas par position d'affichage : depuis la tâche 4, AdaptiveGrid place
      // les zones selon `tableLayoutFor`/`seatsFor`, dont l'ordre dans
      // l'arbre ne suit ni l'ordre d'affichage ni l'ordre canonique de façon
      // fixe (colonnes latérales, sous-grille 8 joueurs...). Un test qui a
      // besoin de retrouver LE joueur 0, quel que soit l'endroit où il est
      // rendu, doit pouvoir le faire sans reposer sur `.first`/`.at(n)` —
      // c'est tout l'objet de cette clé.
      return KeyedSubtree(
        key: ValueKey('player_zone_${playerState.playerId}'),
        child: zone,
      );
    }).toList();

    return AdaptiveGrid(
      key: _gridKey,
      playerZones: playerZones,
      centralBar: _buildCentralBar(),
      actionHub: ActionHub(actions: _gameActions),
    );
  }

  Widget _buildPlayerZoneWithOverlays(Player player, PlayerState playerState, int index) {
    final criticalLevel = AnimationService.getCriticalLevel(
      currentLife: player.life,
      startingLife: _currentFormat.startingLife,
    );

    Widget zone = _buildPlayerZone(player, playerState);
    zone = CriticalOverlay(level: criticalLevel, child: zone);
    zone = EliminationOverlay(
      isEliminated: playerState.isEliminated,
      child: zone,
    );

    final pending = _pendingDamage[playerState.playerId] ?? 0;
    final pendingText = pending > 0 ? '+$pending' : '$pending';
    final pendingColor =
        pending > 0 ? AppColors.accentGreen : AppColors.accentRed;

    // Ronde de correction 4 de la tache 7 -- CAUSE RACINE d'un defaut de
    // geste, pas un nettoyage cosmetique. Ces trois surcouches
    // (flash de degats de commandant, badge de buffer, overlay de mort)
    // ETAIENT trois `if` qui ENVELOPPAIENT `zone` dans un `Stack`
    // supplementaire. Envelopper, c'est INSERER UN NIVEAU dans l'arbre :
    // a la frame ou `pending` passe de 0 a -1 (le tout premier pas de
    // molette d'un geste d'ajustement), l'enfant de `KeyedSubtree` change
    // de type (`EliminationOverlay` -> `Stack`). Flutter ne peut plus
    // apparier l'Element, detruit tout le sous-arbre et le reconstruit :
    // le `State` de `LifeDial` est recree EN PLEIN GESTE (`_trackedPointer`
    // remis a `null`, veille d'appui long perdue, `_wheelSumSinceAdjust`
    // perdu). Le doigt continuait de bouger, plus rien ne l'ecoutait, et le
    // relachement n'appliquait meme pas le palier. Mesure : `initState` /
    // `dispose` de `_LifeDialState` instrumentes -- deux recreations par
    // geste, la premiere avec `tracked=1` (pointeur encore pose).
    //
    // Le `Stack` est donc desormais INCONDITIONNEL : sa profondeur ne
    // depend plus d'aucun etat de la page, seuls ses enfants apparaissent
    // et disparaissent. Chaque enfant porte une `ValueKey` pour que
    // l'appariement du premier (la zone elle-meme, qui porte le cadran)
    // ne depende pas non plus de son index parmi ses freres.
    return Stack(
      children: [
        KeyedSubtree(key: const ValueKey('zone_body'), child: zone),

        // Commander damage flash overlay (Bug 3)
        if (_commanderDamageFlash.contains(playerState.playerId))
          Positioned.fill(
            key: const ValueKey('zone_commander_damage_flash'),
            child: AnimatedOpacity(
              opacity: 0.5,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withAlpha(100),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.shield, color: AppColors.textPrimary, size: 40),
              ),
            ),
          ),

        // Pending damage buffer indicator (Bug 4)
        if (pending != 0)
          Positioned(
            key: const ValueKey('zone_pending_badge'),
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: pendingColor.withAlpha(180),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                pendingText,
                style: AppTextStyles.bold(color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
          ),

        // Rangee d'attribution a la volee (spec S2.6) : voir `_buildPlayerZone`,
        // qui calcule sa visibilite et la passe a `PlayerZone` en donnees.
        //
        // Ronde de correction finale (Critical/Important #2) : elle ne vit plus
        // ici, empilee PAR-DESSUS la zone -- ce Stack est hors du `RotatedBox`
        // de `quarterTurns` de `PlayerZone`, donc la rangee ne pivotait jamais
        // avec la zone (90deg/270deg). Deplacee DANS `PlayerZone` pour pivoter
        // avec le reste.

        if (_showDeathOverlay.contains(playerState.playerId))
          Positioned.fill(
            key: const ValueKey('zone_death_overlay'),
            child: DeathConfirmationOverlay(
              playerName: player.name,
              currentLife: player.life,
              deathReason: _deathReasons[playerState.playerId],
              onDismiss: () => _dismissDeath(playerState.playerId),
              onConfirmElimination: () => _confirmElimination(playerState.playerId),
            ),
          ),
      ],
    );
  }

  void _onReorderPlayers(int oldIndex, int newIndex) {
    final session = _session;
    if (session == null) return;
    // On ne permute plus la liste canonique : seul l'ordre d'affichage change,
    // ce qui préserve l'invariant players[i].playerId == i.
    final order = session.playerOrder.isEmpty
        ? List<int>.generate(session.players.length, (i) => i)
        : List<int>.from(session.playerOrder);
    if (oldIndex >= order.length || newIndex >= order.length) return;
    final temp = order[oldIndex];
    order[oldIndex] = order[newIndex];
    order[newIndex] = temp;
    _controller.reorderPlayers(order);
    // Une zone DÉPLACÉE prend l'orientation par défaut de son nouveau siège
    // (décision utilisateur). Seules les deux zones permutées changent de
    // siège : les reposer TOUTES détruisait l'orientation des joueurs que
    // personne n'avait touchés — un « Même sens » sautait au premier
    // glisser-déposer sans rapport.
    //
    // Ronde de correction 1 (tâche 5) : `seatsFor(order.length)` appelé en
    // direct ignorait le repli face-à-face que `tableLayoutFor` applique
    // quand l'écran ne peut pas payer de colonne latérale (téléphone en
    // portrait, §3.3) — deux sources de vérité sur la géométrie qui
    // divergeaient, la même classe de défaut que le double-pivotement du lot
    // 6. Il faut lire les sièges dans la MÊME disposition que celle que
    // `AdaptiveGrid` a réellement rendue, donc via `tableLayoutFor`.
    //
    // Ronde de correction 2 : `MediaQuery.sizeOf(context)` donnait la taille
    // de l'ÉCRAN, encore une source différente de celle qu'`AdaptiveGrid`
    // mesure réellement (voir `_measuredGridSize`) — remplacé taille de la
    // grille mesurée via `_gridKey`.
    final seats =
        tableLayoutFor(_measuredGridSize(context), order.length).seats;
    for (final displayIndex in {oldIndex, newIndex}) {
      _controller.updateRotation(
          order[displayIndex], seats[displayIndex].quarterTurns);
    }
    setState(() {});
    _saveSnapshot();
  }

  Widget _buildPlayerZone(Player p, PlayerState ps) {
    // Rangee d'attribution a la volee (spec S2.6) : visible seulement sur un
    // buffer NEGATIF (un degat, jamais un gain de vie -- Critical #1 de la
    // ronde de correction 1) en format Commander (ou equivalent), ET
    // seulement hors mode ajustement (Critical #1 de la ronde de correction
    // finale) -- `LifeDial._stepRow()` (paliers ±5/±10) est ancree au meme
    // 30px du bas de la zone ; les deux se recouvraient sans ce dernier
    // garde, et la rangee gagnait le hit-test, ajoutee apres dans le Stack.
    final pending = _pendingDamage[ps.playerId] ?? 0;
    final isAdjusting =
        ref.watch(playerZoneNotifierProvider(ps.playerId)).isAdjusting;
    final showAttribution =
        pending < 0 && _currentFormat.maxCommanderDamage > 0 && !isAdjusting;

    return PlayerZone(
      player: p, isHighlighted: _highlightedPlayerId == p.id,
      onLifeChanged: (val) => _updateLife(p.id, val),
      onColorChanged: (c) => _updatePlayerColor(p.id, c),
      onRotationChanged: (r) => _updatePlayerRotation(p.id, r),
      onSkinChanged: (path) => _updatePlayerSkin(p.id, path),
      onNameTap: () => _showPlayerHistory(p.id),
      onOpenDrawer: (onRotate, onShowColorPicker) =>
          _openPlayerDrawer(ps, onRotate, onShowColorPicker),
      attributionOpponents:
          showAttribution ? _attributionOpponents(ps.playerId) : null,
      onAttributeDamage: (sourcePlayerId) =>
          _attributeCommanderDamage(ps.playerId, sourcePlayerId),
    );
  }

  /// Ouvre le tiroir du joueur (spec §2.7) — remplace l'ancien menu radial
  /// (retiré en tâche 5) comme seul point d'accès à ces actions : compteurs,
  /// monarque, élimination volontaire / son annulation, reset des compteurs,
  /// et la grille de dégâts de commandant reçus (remplace en tâche 2 le
  /// sélecteur plein écran, orienté à l'envers — voir _onDrawerCommanderDamage).
  void _openPlayerDrawer(
    PlayerState ps,
    VoidCallback onRotate,
    VoidCallback onShowColorPicker,
  ) {
    final session = _session;
    final opponents = session == null
        ? const <CommanderDamageOpponent>[]
        : session.players
            .where((other) => other.playerId != ps.playerId)
            .map((other) => CommanderDamageOpponent(
                  playerId: other.playerId,
                  name: other.config.name,
                  colorValue: other.config.colorValue,
                  damage: ps.commanderDamageReceived[other.playerId] ?? 0,
                ))
            .toList();

    showPlayerDrawer(
      context: context,
      playerName: ps.config.name,
      counters: {
        'poison': ps.counters['poison'] ?? 0,
        'energy': ps.counters['energy'] ?? 0,
        'commander_tax': ps.counters['commander_tax'] ?? 0,
      },
      isMonarch: ps.isMonarch,
      isEliminated: ps.isEliminated,
      onCounterDelta: (counterId, delta) =>
          _onDrawerCounterDelta(ps.playerId, counterId, delta),
      onToggleMonarch: () => _toggleMonarch(ps.playerId),
      onEliminate: () => _onDrawerEliminate(ps.playerId),
      onResetCounters: () => _resetPlayerCounters(ps.playerId),
      commanderDamage: opponents,
      lethalCommanderDamage: _currentFormat.maxCommanderDamage,
      onCommanderDamageDelta: (sourcePlayerId, delta) =>
          _onDrawerCommanderDamage(ps.playerId, sourcePlayerId, delta),
      onRotate: onRotate,
      onShowColorPicker: onShowColorPicker,
      // Revue finale (IMPORTANT #1) : second point d'entrée de l'historique
      // PAR JOUEUR, garanti à tous les crans de densité. `onNameTap` sur
      // `PlayerHeader` reste le premier, mais l'en-tête disparaît au cran
      // `minimal` (7-8 joueurs sur téléphone) et la fonction devenait alors
      // injoignable pour toute la partie.
      onShowHistory: () => _showPlayerHistory(ps.playerId),
    );
  }

  /// Câblage volontairement dans CE sens (dette D2 du plan) : `targetPlayerId`
  /// est le joueur DONT LE TIROIR EST OUVERT (`drawerPlayerId`), et
  /// `sourcePlayerId` la ligne tapée dans la grille. L'ancien sélecteur
  /// (`_showCommanderDamageSelector`, supprimé ici) faisait l'inverse : il
  /// listait les adversaires comme CIBLES et leur infligeait des dégâts
  /// DEPUIS le joueur du tiroir — alors que la poignée de ce même joueur
  /// affiche les dégâts qu'il a REÇUS. Une inversion ici laisserait la
  /// poignée afficher un chiffre que ce tiroir ne peut plus corriger.
  void _onDrawerCommanderDamage(
      int drawerPlayerId, int sourcePlayerId, int delta) {
    final target = _session?.players
        .where((p) => p.playerId == drawerPlayerId)
        .firstOrNull;
    if (target == null) return;
    // Le plancher à 0 (et l'ajustement de vie qui n'en découle que du delta
    // réellement appliqué) vivent dans le notifier, pas ici : voir
    // GameSessionNotifier.addCommanderDamage, seul chemin d'écriture, comme
    // updateCounter l'est déjà pour les compteurs.
    _controller.addCommanderDamage(
      targetPlayerId: drawerPlayerId,
      sourcePlayerId: sourcePlayerId,
      damage: delta,
      gameDuration: _gameDuration,
    );
    setState(() {});
    _saveSnapshot();
    if (delta > 0) {
      _triggerCommanderDamageFlash(drawerPlayerId);
      _checkDeathCondition(drawerPlayerId);
    }
  }

  void _onDrawerCounterDelta(int playerId, String counterId, int delta) {
    final player = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
    if (player == null) return;

    final currentVal = player.counters[counterId] ?? 0;
    _controller.updateCounter(playerId, counterId, currentVal + delta);
    setState(() {});
    _saveSnapshot();
    // Check death for poison threshold
    if (counterId == 'poison') {
      _checkDeathCondition(playerId);
    }
  }

  /// DETTE (1/4) — `toggleMonarch` n'avait plus aucun appelant depuis le
  /// retrait du menu radial (tâche 5) : le monarque était injoignable.
  void _toggleMonarch(int playerId) {
    _controller.toggleMonarch(playerId);
    setState(() {});
    _saveSnapshot();
  }

  /// DETTE (2/4 et 3/4) — bascule entre l'élimination volontaire
  /// (`_confirmElimination`, dont le seul appelant restant était la détection
  /// automatique de mort via `DeathConfirmationOverlay`) et son annulation
  /// (`_undoElimination`, supprimée avec le menu radial et recréée ici).
  void _onDrawerEliminate(int playerId) {
    final player = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
    if (player == null) return;
    if (player.isEliminated) {
      _undoElimination(playerId);
    } else {
      _confirmElimination(playerId);
    }
  }

  void _undoElimination(int playerId) {
    final session = _session;
    if (session == null) return;
    final players = session.players.map((p) {
      if (p.playerId == playerId) return p.copyWith(isEliminated: false);
      return p;
    }).toList();
    final eliminationOrder = List<int>.from(session.eliminationOrder)
      ..remove(playerId);
    _controller.restoreSession(
      session.copyWith(players: players, eliminationOrder: eliminationOrder),
    );
    setState(() {});
    _saveSnapshot();
  }

  /// DETTE (4/4) — l'ancien item du menu radial remettait à la fois la vie
  /// et les trois compteurs à zéro dans une closure inline. Décision prise
  /// pour la V4 (voir le rapport de tâche) : `onResetCounters` ne touche
  /// plus qu'aux compteurs — la vie reste hors de portée de cette action.
  void _resetPlayerCounters(int playerId) {
    for (final counterId in const ['poison', 'energy', 'commander_tax']) {
      _controller.updateCounter(playerId, counterId, 0);
    }
    setState(() {});
    _saveSnapshot();
  }

  /// Les neuf actions de partie, dans l'ordre où la bande affichait déjà les
  /// huit premières.
  ///
  /// Source UNIQUE, consommée à la fois par `_buildCentralBar` (la bande,
  /// grand écran) et par `ActionHub` (le hub, petit écran) : deux listes qui
  /// divergeraient rendraient une action joignable dans une forme et pas dans
  /// l'autre — précisément le défaut que la tâche 6 existe pour éliminer.
  ///
  /// Ronde de correction 1 : les infos de partie (`_showGameInfoSheet`)
  /// n'avaient qu'un appui long caché sur le bouton d'orientation comme seul
  /// chemin d'accès -- invisible, et absent du hub puisque `GameAction` ne
  /// porte pas de champ `onLongPress`. Elles sont désormais une neuvième
  /// action à part entière, joignable par un tap ordinaire depuis la bande
  /// ET depuis le hub. L'appui long reste en plus sur le bouton
  /// d'orientation (un raccourci supplémentaire ne gêne personne), mais il
  /// n'est plus le seul chemin.
  List<GameAction> get _gameActions => [
        GameAction(
          id: 'orientation-presets',
          icon: Icons.screen_rotation_alt,
          label: 'Orientation',
          onPressed: _showOrientationPresets,
        ),
        GameAction(
          // `restart-game`, pas `reset` : le tiroir du joueur porte déjà une
          // `ValueKey('action-reset')` (réinitialiser SES compteurs), et deux
          // widgets montés en même temps sous la même clé rendent tout
          // repérage ambigu.
          id: 'restart-game',
          icon: Icons.refresh,
          label: 'Recommencer',
          onPressed: () => _resetGame(),
        ),
        GameAction(
          id: 'dice',
          icon: Icons.casino,
          label: 'Dé',
          onPressed: _showDiceSelector,
        ),
        GameAction(
          id: 'timer',
          icon: _isGameActive ? Icons.stop : Icons.play_arrow,
          label: _isGameActive
              ? 'Terminer la partie'
              : 'Désigner le premier joueur',
          onPressed: _isGameActive ? _endGame : _pickStartingPlayer,
        ),
        GameAction(
          id: 'history',
          icon: Icons.history,
          label: 'Historique',
          onPressed: _showDamageHistory,
        ),
        GameAction(
          id: 'table-view',
          icon: Icons.table_chart_outlined,
          label: 'Vue table',
          onPressed: _showTableView,
        ),
        GameAction(
          id: 'edit-mode',
          icon: Icons.build,
          label: _isEditMode ? 'Terminer l\'édition' : 'Réorganiser les joueurs',
          onPressed: () => setState(() => _isEditMode = !_isEditMode),
        ),
        GameAction(
          id: 'game-setup',
          icon: Icons.people,
          label: 'Joueurs',
          onPressed: _showGameSetupDialog,
        ),
        GameAction(
          id: 'game-info',
          icon: Icons.info_outline,
          label: 'Infos de partie',
          onPressed: _showGameInfoSheet,
        ),
      ];

  /// La bande d'actions (grand écran).
  ///
  /// Revue finale (IMPORTANT #3) : construite par ITÉRATION sur
  /// `_gameActions`, jamais plus à l'index. La version précédente câblait neuf
  /// boutons en dur (`actions[0]` … `actions[8]`) tandis que le hub itérait :
  /// une dixième action aurait été affichée par le hub, ignorée par la bande,
  /// et sous-estimée par `kBandNeed` — les deux mécaniques exactes du défaut
  /// d'origine (une action joignable dans une forme et pas dans l'autre, une
  /// largeur calculée sur un compte faux), réarmées.
  ///
  /// Les trois rendus bespoke qui subsistent sont sélectionnés par l'`id` de
  /// l'action, pas par sa position : ajouter, retirer ou réordonner une
  /// action ne peut plus en déplacer un sur la mauvaise.
  Widget _buildCentralBar() {
    final actions = _gameActions;
    // La bande n'est plus rendue que lorsque `tableLayoutFor` a vérifié
    // qu'elle tient (voir `TableLayout.barKind`, `kBandNeed`) : un
    // `SingleChildScrollView` qui masquerait silencieusement des actions est
    // interdit par la spec, donc plus de scroll ici -- sous ce seuil,
    // `AdaptiveGrid` monte le hub à la place.
    return Container(
      height: 60,
      color: AppColors.textOnPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final action in actions) _bandButton(action),
        ],
      ),
    );
  }

  /// Le bouton de bande d'une action. Le cas général est un `IconButton`
  /// Material nu — celui dont `kActionWidth` mesure la taille (ruling 16).
  Widget _bandButton(GameAction action) {
    final key = ValueKey('action-${action.id}');
    switch (action.id) {
      // Raccourci en plus : appui long pour les infos de partie -- mais ce
      // n'est plus leur seul chemin, voir l'action `game-info`.
      case 'orientation-presets':
        return GestureDetector(
          onLongPress: _showGameInfoSheet,
          child: IconButton(
            key: key,
            icon: Icon(action.icon, color: AppColors.textSecondary),
            onPressed: action.onPressed,
          ),
        );

      // Chrono : style bespoke (cercle de 50x50, minuterie en Roboto Mono),
      // reporté par la revue finale. Il reste ici une branche de ce switch,
      // donc toujours UN élément de la bande par action, ni plus ni moins.
      case 'timer':
        return InkWell(
          key: key,
          onTap: action.onPressed,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 50, height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textOnPrimary,
              border: Border.all(
                color: _isGameActive ? AppColors.accentRed : AppColors.primaryShade800,
                width: 2,
              ),
            ),
            child: _isGameActive
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatDuration(_gameDuration),
                      style: GoogleFonts.robotoMono(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Icon(action.icon, color: AppColors.primary),
          ),
        );

      // Surlignage du mode édition : également bespoke, également reporté.
      case 'edit-mode':
        return IconButton(
          key: key,
          icon: Icon(
            action.icon,
            color: _isEditMode ? AppColors.primary : AppColors.textSecondary,
          ),
          style: _isEditMode
              ? IconButton.styleFrom(backgroundColor: AppColors.primary.withAlpha(40))
              : null,
          onPressed: action.onPressed,
        );

      default:
        return IconButton(
          key: key,
          icon: Icon(action.icon, color: AppColors.textSecondary),
          onPressed: action.onPressed,
        );
    }
  }

  void _showOrientationPresets() {
    final count = _playerCount;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      builder: (sheetCtx) {
        final presets = _getOrientationPresets(count);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Orientation des zones', style: AppTextStyles.cinzel(fontSize: 18)),
              const SizedBox(height: 4),
              Text('$count joueurs', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: presets.map((preset) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _applyOrientationPreset(preset.rotations);
                    },
                    child: Container(
                      width: 100, height: 110,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderMedium),
                      ),
                      child: Column(
                        children: [
                          Expanded(child: _buildOrientationPreview(preset.rotations, count)),
                          const SizedBox(height: 4),
                          Text(preset.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Presets d'orientation, TOUS dérivés de la géométrie (revue finale,
  /// ruling 20).
  ///
  /// Ce qui existait avant : des listes en dur de 2 à 6 joueurs, écrites pour
  /// une disposition qui n'existe plus. Mesuré à `Size(900, 700)` / 4
  /// joueurs — l'écran exact des tests de presets — la disposition rendue est
  /// `[top, right, bottom, left]`, soit `[2, 3, 0, 1]`, colonnes latérales
  /// actives ; « Face à face » posait `[2, 2, 0, 0]` et AUCUN des cinq presets
  /// ne produisait l'orientation juste. L'aperçu, lui, dessinait honnêtement
  /// le résultat faux : libellé et aperçu se contredisaient à l'écran.
  ///
  /// Depuis, il n'y a plus qu'une source de géométrie —
  /// `tableLayoutFor(_measuredGridSize(context), count)` — et aucune liste en
  /// dur ne peut plus diverger d'elle.
  ///
  /// Les trois libellés supprimés — « Côtés », « Triangle », « Cercle » — ne
  /// décrivaient aucune disposition de sièges : ils ne peuvent pas être
  /// exprimés honnêtement une fois la géométrie dérivée, et prétendaient
  /// placer des joueurs là où la grille ne les met pas.
  List<_OrientationPreset> _getOrientationPresets(int count) {
    // La disposition RÉELLEMENT rendue, colonnes latérales comprises.
    // `TableSeat.quarterTurns` porte déjà la rotation juste pour un siège
    // donné : rien à recalculer, aucune compensation.
    final tableRotations = [
      for (final seat in tableLayoutFor(_measuredGridSize(context), count).seats)
        seat.quarterTurns,
    ];

    // Le repli face-à-face, c'est-à-dire la même géométrie privée de ses
    // colonnes latérales — et non une liste écrite à la main.
    final faceToFaceRotations = [
      for (final seat in seatsFor(count, allowSideColumns: false))
        seat.quarterTurns,
    ];

    return [
      _OrientationPreset('Table', tableRotations),
      // Proposé seulement là où il DIFFÈRE de « Table » : sur un écran (ou un
      // effectif) où la grille ne pose déjà pas de colonnes latérales, les
      // deux presets sont le même, et offrir deux boutons identiques sous
      // deux noms ment sur ce qu'ils font.
      if (!listEquals(faceToFaceRotations, tableRotations))
        _OrientationPreset('Face à face', faceToFaceRotations),
      _OrientationPreset('Même sens', List.filled(count, 0)),
      // Seul preset qui ne décrive pas des SIÈGES : deux joueurs côte à côte
      // du même bord de l'appareil, chacun tourné d'un quart de tour vers
      // l'autre. Il n'a de sens qu'à deux, et n'a pas d'équivalent
      // géométrique à dériver — `seatsFor` ne modélise pas ce placement.
      if (count == 2) const _OrientationPreset('Côte à côte', [1, 3]),
    ];
  }

  void _applyOrientationPreset(List<int> rotations) {
    if (_session == null) return;
    // Les presets décrivent une position visuelle (haut/bas/côtés de la
    // grille) : il faut donc les appliquer dans l'ordre d'affichage, pas
    // dans l'ordre canonique, sous peine de tourner le mauvais joueur après
    // un reorder.
    //
    // Depuis la tâche 4, `AdaptiveGrid` ne pivote plus jamais rien lui-même
    // (voir adaptive_grid.dart) : les `quarterTurns` d'un preset sont donc
    // déjà la rotation finale à poser, sans aucune compensation. Le retrait
    // de deux quarts de tour qui vivait ici avant cette correction
    // supposait encore l'ancienne grille, qui pivotait la moitié haute de
    // 180° elle-même — 180° − 180° = 0°, le défaut symétrique de celui que
    // la tâche 4 interdit (180° + 180° = 360°).
    final players = _orderedPlayers;
    for (int i = 0; i < players.length && i < rotations.length; i++) {
      _controller.updateRotation(players[i].playerId, rotations[i]);
    }
    setState(() {});
    _saveSnapshot();
    HapticFeedback.mediumImpact();
  }

  Widget _buildOrientationPreview(List<int> rotations, int count) {
    // Aligné sur la vraie géométrie (tâche 4, ronde de correction 1) :
    // `tableLayoutFor` décide seule des côtés, `AdaptiveGrid` ne fait qu'y
    // obéir. Un topCount supposé (moitié haute / moitié basse) est faux dès
    // que des colonnes latérales entrent en jeu : à 4 joueurs, les index 1
    // et 3 finissent à droite et à gauche, pas en bas.
    //
    // Ronde de correction 2 (tâche 5) : taille RÉELLE de la grille, pas celle
    // de l'écran (voir `_measuredGridSize`).
    final seats = tableLayoutFor(_measuredGridSize(context), count).seats;

    List<int> indicesOn(TableSide side) {
      final indices = <int>[];
      for (int i = 0; i < seats.length && i < count; i++) {
        if (seats[i].side == side) indices.add(i);
      }
      indices.sort((a, b) => seats[a].slot.compareTo(seats[b].slot));
      return indices;
    }

    Widget cellFor(int i) {
      final arrow = _arrowForRotation(rotations[i]);
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.primaryShade800.withAlpha(60),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.borderMedium, width: 0.5),
        ),
        child: Center(
          child: Text(arrow, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
        ),
      );
    }

    Widget rowOf(List<int> indices) => indices.isEmpty
        ? const SizedBox.shrink()
        : Row(children: [for (final i in indices) Expanded(child: cellFor(i))]);
    Widget columnOf(List<int> indices) => indices.isEmpty
        ? const SizedBox.shrink()
        : Column(children: [for (final i in indices) Expanded(child: cellFor(i))]);

    final top = indicesOn(TableSide.top);
    final bottom = indicesOn(TableSide.bottom);
    final left = indicesOn(TableSide.left);
    final right = indicesOn(TableSide.right);

    final centre = Column(
      children: [
        Expanded(child: rowOf(top)),
        Expanded(child: rowOf(bottom)),
      ],
    );

    if (left.isEmpty && right.isEmpty) return centre;

    return Row(
      children: [
        if (left.isNotEmpty) Expanded(child: columnOf(left)),
        Expanded(flex: 2, child: centre),
        if (right.isNotEmpty) Expanded(child: columnOf(right)),
      ],
    );
  }

  String _arrowForRotation(int quarterTurns) {
    switch (quarterTurns % 4) {
      case 0: return '↑';
      case 1: return '→';
      case 2: return '↓';
      case 3: return '←';
      default: return '↑';
    }
  }

  void _showGameInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      // Ronde de correction 1 (tâche 6) : cette feuille n'était atteignable
      // que par l'appui long sur le bouton d'orientation, jamais testée sur
      // petit écran. Devenue joignable depuis le hub (écran étroit), son
      // contenu (jusqu'à 9 lignes) dépasse la hauteur d'un petit écran sans
      // `isScrollControlled` + défilement -- même remède qu'`ActionHub._open`.
      isScrollControlled: true,
      builder: (ctx) {
        final alivePlayers = _session?.players.where((p) => !p.isEliminated).length ?? 0;
        final totalPlayers = _playerCount;
        final monarchName = _session?.players
            .where((p) => p.isMonarch)
            .map((p) => p.config.name)
            .firstOrNull;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text('Infos Partie', style: AppTextStyles.cinzel(fontSize: 22))),
                  const SizedBox(height: 16),
                  _infoRow(Icons.category, 'Format', _currentFormat.name),
                  _infoRow(Icons.favorite, 'Vie de départ', '${_currentFormat.startingLife}'),
                  _infoRow(Icons.people, 'Joueurs', '$alivePlayers / $totalPlayers en vie'),
                  _infoRow(Icons.timer, 'Durée', _formatDuration(_gameDuration)),
                  _infoRow(Icons.science, 'Poison létal',
                    _currentFormat.maxPoison > 0 ? '${_currentFormat.maxPoison} compteurs' : 'Désactivé'),
                  _infoRow(Icons.shield, 'Cmd létal',
                    _currentFormat.maxCommanderDamage > 0 ? '${_currentFormat.maxCommanderDamage} dégâts' : 'Désactivé'),
                  _infoRow(Icons.favorite_border, 'PV à 0 = mort',
                    _currentFormat.lethalAtZeroLife ? 'Oui' : 'Non'),
                  if (monarchName != null)
                    _infoRow(Icons.star, 'Monarque', monarchName),
                  if (_session?.tag != null && _session!.tag!.isNotEmpty)
                    _infoRow(Icons.label, 'Tag', _session!.tag!),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Text('$label : ', style: AppTextStyles.bold(color: AppColors.textMuted, fontSize: 14)),
          Expanded(child: Text(value, style: AppTextStyles.label(fontSize: 14))),
        ],
      ),
    );
  }

  /// Ouvre la vue table (tache 4, ronde de correction 1) : une route
  /// GoRouter declarative (`AppRoutes.tableView`, enregistree dans
  /// `life_counter_routes.dart`), comme toutes les autres pages plein-ecran
  /// poussees par-dessus le shell (`/game-history`, etc.) -- pas un
  /// `Navigator.push`/`MaterialPageRoute` isole, qui aurait ete le seul de
  /// tout `lib/` et aurait rendu la vue introuvable dans `app_router.dart`.
  /// Elle lit `gameSessionNotifierProvider` elle-meme (ConsumerWidget), donc
  /// aucun etat n'a besoin d'etre passe en parametre.
  void _showTableView() {
    context.push(AppRoutes.tableView);
  }

  void _showDiceSelector() {
    showModalBottomSheet(context: context, backgroundColor: AppColors.scaffoldBackground, builder: (context) {
        final dice = [2, 4, 6, 8, 10, 12, 20, 100];
        return Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Lancer un dé', style: AppTextStyles.cinzel(fontSize: 22)),
            const SizedBox(height: 24),
            GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: dice.length, itemBuilder: (context, i) => ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.borderLight, padding: EdgeInsets.zero),
                onPressed: () { Navigator.pop(context); _rollDice(dice[i]); },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.casino, color: AppColors.textSecondary), Text('D${dice[i]}', style: AppTextStyles.label())]),
            ))
        ]));
    });
  }

  void _showDamageHistory() {
    if (_session == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (ctx) => DamageHistorySheet(
        session: _session!,
        filterPlayerId: _historyFilterPlayerId,
        onFilterChanged: (id) {
          setState(() => _historyFilterPlayerId = id);
          Navigator.pop(ctx);
          _showDamageHistory(); // Reopen with new filter
        },
      ),
    );
  }

  void _showPlayerHistory(int playerId) {
    if (_session == null) return;
    final playerState = _session!.players.where((p) => p.playerId == playerId).firstOrNull;
    if (playerState == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (ctx) => PlayerHistorySheet(
        playerState: playerState,
        startingLife: _currentFormat.startingLife,
      ),
    );
  }

  void _rollDice(int sides) {
    showDialog(context: context, barrierDismissible: false, builder: (c) => DiceRollAnimationDialog(sides: sides, finalResult: Random().nextInt(sides) + 1, onReroll: () { Navigator.pop(c); _rollDice(sides); }));
  }
}

/// Data class for an orientation preset.
class _OrientationPreset {
  final String label;
  final List<int> rotations; // quarterTurns per player index
  const _OrientationPreset(this.label, this.rotations);
}
