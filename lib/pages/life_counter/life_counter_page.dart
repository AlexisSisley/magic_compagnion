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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
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
import '../../widgets/life_counter/dice_roll_dialog.dart';
import '../../widgets/life_counter/game_setup_modal.dart';
import '../../widgets/life_counter/layouts/adaptive_grid.dart';
import '../../widgets/life_counter/critical_overlay.dart';
import '../../widgets/life_counter/elimination_overlay.dart';
import '../../widgets/life_counter/death_confirmation_overlay.dart';
import '../../widgets/life_counter/draggable_player_zone.dart';
import '../../widgets/life_counter/radial_menu.dart';
import '../../widgets/life_counter/animations/animation_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  GameFormat _currentFormat = GameFormat.builtInFormats.first; // Commander

  bool _isLoading = true;

  // Death confirmation state
  final Map<int, Timer> _deathTimers = {};
  final Set<int> _showDeathOverlay = {};
  final Set<int> _dismissedDeathOverlay = {};

  // Edit mode state
  bool _isEditMode = false;

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

  // Débounce de l'écriture du snapshot (voir `_saveSnapshot` plus bas).
  // `_pendingSnapshotSession` capture la session à écrire au moment de
  // l'appel (où `ref` est valide) : `dispose()` n'a ainsi besoin de relire
  // ni `_session` (getter basé sur `ref.read`) ni le provider pour effectuer
  // le flush final.
  Timer? _snapshotDebounce;
  GameSession? _pendingSnapshotSession;

  // Écriture de snapshot en vol (voir `_flushSnapshot`). `_snapshotDebounce
  // ?.cancel()` n'a aucun effet sur un `Timer` déjà déclenché : si le flush
  // est déjà parti quand `_finalizeGameSave` s'exécute, ce champ est le seul
  // moyen de faire attendre `clearSnapshot()` la fin de cette écriture, pour
  // que le clear ait toujours le dernier mot (sinon l'écriture en vol
  // pourrait se terminer après le clear et ressusciter la partie terminée).
  Future<void>? _inFlightSnapshotWrite;

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

    // Flush du débounce de snapshot : on annule le Timer en attente et on
    // écrit une dernière fois si une session avait été capturée. Ni `ref` ni
    // le getter `_session` (qui l'utilise) ne sont touchés ici — seuls
    // `_sessionService` et `_pendingSnapshotSession`, déjà résolus avant ce
    // chemin de démontage, sont lus.
    _snapshotDebounce?.cancel();
    final pendingSession = _pendingSnapshotSession;
    _pendingSnapshotSession = null;
    if (pendingSession != null) {
      // Pas d'await : dispose est synchrone. L'écriture part quand même.
      _sessionService.saveSnapshot(pendingSession);
    }

    // Restore system UI when leaving the page
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  // --- LOGIQUE TIMER ---
  void _startGame() {
    _gameTimer?.cancel();
    _controller.startTimer();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _controller.tick();
    });
    setState(() {});
  }

  void _stopGame() {
    _gameTimer?.cancel();
    _controller.stopTimer();
    setState(() {});
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
        setState(() {
          _currentFormat = snapshot.format;
          _isLoading = false;
        });
        if (snapshot.isActive) {
          _gameTimer?.cancel();
          _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) return;
            _controller.tick();
          });
        }
        return;
      }
    }

    // No saved game -- start fresh with defaults
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final playerCount = prefs.getInt('playerCount') ?? 4;
    final formatId = prefs.getString('formatId') ?? 'commander';
    _currentFormat = GameFormat.builtInFormats.firstWhere(
      (f) => f.id == formatId,
      orElse: () => GameFormat.builtInFormats.first,
    );

    _startNewGame(playerCount: playerCount);
    setState(() => _isLoading = false);
  }

  void _startNewGame({required int playerCount, List<Profile?>? assignedProfiles}) {
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

    _controller.startNewGame(format: _currentFormat, playerConfigs: configs);

    // Apply default rotations
    if (_session != null) {
      for (int i = 0; i < playerCount; i++) {
        _controller.updateRotation(i, _calculateDefaultRotation(i, playerCount));
      }
    }

    setState(() {});
    _saveSnapshot();

    // Persist defaults for next launch
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('playerCount', playerCount);
      prefs.setString('formatId', _currentFormat.id);
    });
  }

  /// Point d'entrée de test pour déclencher `_saveSnapshot()` directement,
  /// sans passer par un des 12 sites d'appel (taps, reorder, etc.).
  @visibleForTesting
  void saveSnapshotForTest() => _saveSnapshot();

  /// Écriture différée : les mutations arrivent par rafales (un tap = une
  /// mutation), et sérialiser toute la session à chaque fois coûte une I/O
  /// par tap. On ne garde que la dernière écriture d'une rafale. La session
  /// à écrire est capturée ici (où `ref` est valide), pas au moment du
  /// flush, afin que le flush lui-même n'ait besoin de rien lire via `ref`.
  static const _snapshotDebounceDelay = Duration(milliseconds: 500);

  Future<void> _saveSnapshot() async {
    final session = _session;
    if (session == null) return;
    _pendingSnapshotSession = session;
    _snapshotDebounce?.cancel();
    _snapshotDebounce = Timer(_snapshotDebounceDelay, _flushSnapshot);
  }

  Future<void> _flushSnapshot() async {
    _snapshotDebounce?.cancel();
    _snapshotDebounce = null;
    final session = _pendingSnapshotSession;
    _pendingSnapshotSession = null;
    if (session == null) return;
    // Suivi de l'écriture en vol : `_finalizeGameSave` peut avoir besoin
    // d'attendre qu'elle se termine avant d'appeler `clearSnapshot()` (voir
    // le champ `_inFlightSnapshotWrite`).
    final write = _sessionService.saveSnapshot(session);
    _inFlightSnapshotWrite = write;
    try {
      await write;
    } finally {
      // Ne nettoie que si personne d'autre n'a déjà remplacé la référence
      // (pas de cas concret aujourd'hui, un seul flush à la fois, mais évite
      // d'effacer par erreur l'écriture d'un flush plus récent).
      if (_inFlightSnapshotWrite == write) {
        _inFlightSnapshotWrite = null;
      }
    }
  }

  int _calculateDefaultRotation(int id, int totalPlayers) {
    // AdaptiveGrid already applies RotatedBox(quarterTurns: 2) to the top half,
    // so top-row zones need quarterTurns: 0 to appear upright (grid 180° + zone 0° = 180° visual).
    // Bottom-row zones have no grid rotation, so quarterTurns: 0 = normal upright.
    // Default: all zones at 0° (top row appears face-down thanks to grid, bottom row normal).
    return 0;
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
  void _resetGame({List<Profile?>? assignedProfiles}) {
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
    _startNewGame(playerCount: count > 0 ? count : 4, assignedProfiles: assignedProfiles);
  }

  /// Point d'entrée de test pour piloter le buffer de dégâts sans simuler de tap
  /// (les zones sont pivotées par AdaptiveGrid, ce qui rend le tap fragile en test).
  @visibleForTesting
  void updateLifeForTest(int playerId, int change) => _updateLife(playerId, change);

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
    setState(() => _isSelectingStarter = true);
    int turns = 20; int currentIdx = Random().nextInt(_playerCount); int delay = 50;
    for (int i = 0; i < turns; i++) {
      setState(() => _highlightedPlayerId = currentIdx % _playerCount);
      await Future.delayed(Duration(milliseconds: delay));
      delay += (i * 2); currentIdx++;
    }
    int winnerId = (currentIdx - 1) % _playerCount;
    if (mounted) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: Center(child: Text('Le Destin a choisi !', style: AppTextStyles.cinzel(color: AppColors.textSecondary))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 50, color: Color(players[winnerId].colorValue)),
              const SizedBox(height: 16),
              Text(players[winnerId].name, style: AppTextStyles.pageTitle(fontSize: 32), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(context); setState(() { _highlightedPlayerId = null; _isSelectingStarter = false; }); _startGame(); },
              style: ElevatedButton.styleFrom(backgroundColor: Color(players[winnerId].colorValue)),
              child: const Text("C'est parti !", style: TextStyle(color: AppColors.textPrimary))
            )
          ]
        ),
      );
    }
  }

  void _showGameSetupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldBackground,
      builder: (ctx) => GameSetupModal(
        initialLife: _startingLife,
        onGameStart: (format, profiles) {
          _currentFormat = format;
          _resetGame(assignedProfiles: profiles);
        },
      )
    );
  }

  void _showCommanderDamageSelector(Player attacker) {
    final players = _legacyPlayers;
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: AppColors.scaffoldBackground.withValues(alpha: 0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
        child: Wrap(
          children: [
            ListTile(title: Text('Dégâts de Commandant', style: AppTextStyles.bold()), subtitle: Text('Attaquant : ${attacker.name}', style: AppTextStyles.cinzel(color: AppColors.textSecondary))),
            ...players.where((opp) => opp.id != attacker.id).map((opponent) {
              final damage = opponent.commanderDamageReceived[attacker.id] ?? 0;
              return ListTile(
                leading: Icon(Icons.shield, color: Color(opponent.colorValue)),
                title: Text(opponent.name, style: const TextStyle(color: AppColors.textPrimary)),
                trailing: SizedBox(width: 150, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(icon: const Icon(Icons.remove, color: AppColors.textSecondary), onPressed: () {
                    if (damage > 0) {
                      // addCommanderDamage already adjusts life internally — no need for a separate updateLife call
                      _controller.addCommanderDamage(
                        targetPlayerId: opponent.id,
                        sourcePlayerId: attacker.id,
                        damage: -1,
                        gameDuration: _gameDuration,
                      );
                      setState(() {});
                      _saveSnapshot();
                    }
                    Navigator.pop(context);
                    _showCommanderDamageSelector(attacker);
                  }),
                  Text('$damage', style: AppTextStyles.pageTitle()),
                  IconButton(icon: const Icon(Icons.add, color: AppColors.textSecondary), onPressed: () {
                    _controller.addCommanderDamage(
                      targetPlayerId: opponent.id,
                      sourcePlayerId: attacker.id,
                      damage: 1,
                      gameDuration: _gameDuration,
                    );
                    setState(() {});
                    _saveSnapshot();
                    _triggerCommanderDamageFlash(opponent.id);
                    _checkDeathCondition(opponent.id);
                    Navigator.pop(context);
                    _showCommanderDamageSelector(attacker);
                  }),
                ])),
              );
            })
          ],
        ),
      ),
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
    // annulée avant `clearSnapshot()`, sans quoi un flush retardataire (le
    // Timer de `_saveSnapshot`) réécrirait le snapshot d'une partie déjà
    // terminée juste après sa suppression. `cancel()` n'a cependant aucun
    // effet sur un flush déjà déclenché (Timer déjà consommé) : on capture
    // aussi son écriture en vol, pour l'attendre avant `clearSnapshot()` —
    // sans quoi cette écriture pourrait se terminer après le clear et
    // ressusciter la partie qu'on vient de terminer.
    _snapshotDebounce?.cancel();
    _snapshotDebounce = null;
    _pendingSnapshotSession = null;
    final pendingWrite = _inFlightSnapshotWrite;

    // Bug 6 fix: Fire DB writes asynchronously without blocking UI
    Future.microtask(() async {
      await _gameHistoryService.addGame(newItem);
      if (pendingWrite != null) {
        await pendingWrite;
      }
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

      return zone;
    }).toList();

    return AdaptiveGrid(
      playerZones: playerZones,
      centralBar: _buildCentralBar(),
    );
  }

  Widget _buildPlayerZoneWithOverlays(Player player, PlayerState playerState, int index) {
    final criticalLevel = AnimationService.getCriticalLevel(
      currentLife: player.life,
      startingLife: _currentFormat.startingLife,
    );

    Widget zone = _buildPlayerZone(player);
    zone = CriticalOverlay(level: criticalLevel, child: zone);
    zone = EliminationOverlay(
      isEliminated: playerState.isEliminated,
      child: zone,
    );

    // Long press for radial menu (6.2) — only when NOT in edit mode
    if (!_isEditMode) {
      zone = GestureDetector(
        onLongPressStart: (details) => _showRadialMenuForPlayer(
          details.globalPosition,
          playerState,
        ),
        child: zone,
      );
    }

    // Commander damage flash overlay (Bug 3)
    if (_commanderDamageFlash.contains(playerState.playerId)) {
      zone = Stack(
        children: [
          zone,
          Positioned.fill(
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
        ],
      );
    }

    // Pending damage buffer indicator (Bug 4)
    final pending = _pendingDamage[playerState.playerId] ?? 0;
    if (pending != 0) {
      final pendingText = pending > 0 ? '+$pending' : '$pending';
      final pendingColor = pending > 0 ? AppColors.accentGreen : AppColors.accentRed;
      zone = Stack(
        children: [
          zone,
          Positioned(
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
        ],
      );
    }

    if (_showDeathOverlay.contains(playerState.playerId)) {
      zone = Stack(
        children: [
          zone,
          Positioned.fill(
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

    return zone;
  }

  /// Radial menu (spec 6.2) — Monarch / Éliminer (or Undo) / Reset compteurs
  void _showRadialMenuForPlayer(Offset globalPosition, PlayerState playerState) {
    final items = <RadialMenuItem>[];

    // Monarch toggle
    items.add(RadialMenuItem(
      icon: Icons.star,
      label: playerState.isMonarch ? 'Retirer' : 'Monarch',
      color: AppColors.amber,
      onTap: () {
        _controller.toggleMonarch(playerState.playerId);
        setState(() {});
        _saveSnapshot();
      },
    ));

    if (playerState.isEliminated) {
      // Undo elimination
      items.add(RadialMenuItem(
        icon: Icons.undo,
        label: 'Annuler',
        color: AppColors.accentGreen,
        onTap: () => _undoElimination(playerState.playerId),
      ));
    } else {
      // Eliminate
      items.add(RadialMenuItem(
        icon: Icons.person_off,
        label: 'Éliminer',
        color: AppColors.accentRed,
        onTap: () => _confirmElimination(playerState.playerId),
      ));
    }

    // Reset this player's counters
    items.add(RadialMenuItem(
      icon: Icons.refresh,
      label: 'Reset',
      color: AppColors.textSecondary,
      onTap: () {
        // Reset life to starting, clear counters
        if (_session == null) return;
        final delta = _currentFormat.startingLife - playerState.life;
        if (delta != 0) {
          _controller.updateLife(playerState.playerId, delta, gameDuration: _gameDuration);
        }
        _controller.updateCounter(playerState.playerId, 'poison', 0);
        _controller.updateCounter(playerState.playerId, 'energy', 0);
        _controller.updateCounter(playerState.playerId, 'commander_tax', 0);
        setState(() {});
        _saveSnapshot();
      },
    ));

    showRadialMenu(
      context: context,
      anchor: globalPosition,
      items: items,
    );
  }

  void _undoElimination(int playerId) {
    if (_session == null) return;
    // Update both the session AND the controller to keep them in sync (Bug 2 fix)
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(isEliminated: false);
      }
      return p;
    }).toList();
    final newOrder = List<int>.from(_session!.eliminationOrder)..remove(playerId);
    _controller.restoreSession(
      _session!.copyWith(players: players, eliminationOrder: newOrder),
    );
    setState(() {});
    _saveSnapshot();
  }

  /// Point d'entrée de test pour piloter un reorder sans simuler de drag
  /// (les zones sont pivotées par AdaptiveGrid, ce qui rend le drag fragile
  /// en test). Consommé aussi par la tâche 4b.
  @visibleForTesting
  void reorderForTest(int oldIndex, int newIndex) =>
      _onReorderPlayers(oldIndex, newIndex);

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
    setState(() {});
    _saveSnapshot();
  }

  Widget _buildPlayerZone(Player p) {
    return PlayerZone(
      player: p, isCommander: _currentFormat.maxCommanders > 0, isHighlighted: _highlightedPlayerId == p.id,
      onLifeChanged: (val) => _updateLife(p.id, val),
      onShowCommanderDamage: () => _showCommanderDamageSelector(p),
      onColorChanged: (c) => _updatePlayerColor(p.id, c),
      onRotationChanged: (r) => _updatePlayerRotation(p.id, r),
      onSkinChanged: (path) => _updatePlayerSkin(p.id, path),
      onNameTap: () => _showPlayerHistory(p.id),
      onStatChanged: (type, val) => _onStatChanged(p.id, type, val),
    );
  }

  void _onStatChanged(int playerId, String type, int val) {
    // Sync counter changes from PlayerZone back to the controller
    final counterKey = type.replaceAll('CounterMode.', '');
    final player = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
    if (player == null) return;

    final currentVal = player.counters[counterKey] ?? 0;
    _controller.updateCounter(playerId, counterKey, currentVal + val);
    setState(() {});
    _saveSnapshot();
    // Check death for poison threshold
    if (counterKey == 'poison') {
      _checkDeathCondition(playerId);
    }
  }

  Widget _buildCentralBar() {
    return Container(
      height: 60,
      color: AppColors.textOnPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Quick orientation presets (tap) / Game info (long press)
          GestureDetector(
            onLongPress: _showGameInfoSheet,
            child: IconButton(
              icon: const Icon(Icons.screen_rotation_alt, color: AppColors.textSecondary),
              onPressed: _showOrientationPresets,
            ),
          ),
          // Reset
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => _resetGame(),
          ),
          // Dice
          IconButton(
            icon: const Icon(Icons.casino, color: AppColors.textSecondary),
            onPressed: _showDiceSelector,
          ),
          // Timer / Pick starter / End game
          InkWell(
            onTap: _isGameActive ? _endGame : _pickStartingPlayer,
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
                  : const Icon(Icons.play_arrow, color: AppColors.primary),
            ),
          ),
          // History (NEW)
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.textSecondary),
            onPressed: _showDamageHistory,
          ),
          // Edit mode toggle (NEW)
          IconButton(
            icon: Icon(
              Icons.build,
              color: _isEditMode ? AppColors.primary : AppColors.textSecondary,
            ),
            style: _isEditMode
                ? IconButton.styleFrom(backgroundColor: AppColors.primary.withAlpha(40))
                : null,
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
          ),
          // Game setup
          IconButton(
            icon: const Icon(Icons.people, color: AppColors.textSecondary),
            onPressed: _showGameSetupDialog,
          ),
        ],
      ),
    );
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

  List<_OrientationPreset> _getOrientationPresets(int count) {
    if (count == 2) {
      return [
        _OrientationPreset('Face à face', [2, 0]),
        _OrientationPreset('Même sens', [0, 0]),
        _OrientationPreset('Côte à côte', [1, 3]),
      ];
    }
    if (count == 3) {
      // Layout: 1 top (index 0), 2 bottom (indices 1, 2)
      return [
        _OrientationPreset('Face à face', [2, 0, 0]),
        _OrientationPreset('Même sens', [0, 0, 0]),
        _OrientationPreset('Triangle', [2, 1, 3]),
      ];
    }
    if (count == 4) {
      return [
        _OrientationPreset('Face à face', [2, 2, 0, 0]),
        _OrientationPreset('Côtés', [1, 3, 1, 3]),
        _OrientationPreset('Table', [1, 3, 0, 2]),
        _OrientationPreset('Cercle', [2, 2, 1, 3]),
        _OrientationPreset('Même sens', [0, 0, 0, 0]),
      ];
    }
    if (count == 5) {
      // Layout: 2 top (indices 0-1), 3 bottom (indices 2-4)
      return [
        _OrientationPreset('Face à face', [2, 2, 0, 0, 0]),
        _OrientationPreset('Même sens', [0, 0, 0, 0, 0]),
      ];
    }
    if (count == 6) {
      return [
        _OrientationPreset('Face à face', [2, 2, 2, 0, 0, 0]),
        _OrientationPreset('Côtés', [1, 2, 3, 1, 0, 3]),
        _OrientationPreset('Même sens', [0, 0, 0, 0, 0, 0]),
      ];
    }
    // Fallback for any count — top half = floor(count/2) to match AdaptiveGrid
    final halfUp = List.generate(count, (i) => i < count ~/ 2 ? 2 : 0);
    final allSame = List.filled(count, 0);
    return [
      _OrientationPreset('Face à face', halfUp),
      _OrientationPreset('Même sens', allSame),
    ];
  }

  void _applyOrientationPreset(List<int> rotations) {
    if (_session == null) return;
    // Les presets décrivent une position visuelle (haut/bas de la grille) :
    // il faut donc les appliquer dans l'ordre d'affichage, pas dans l'ordre
    // canonique, sous peine de tourner le mauvais joueur après un reorder.
    final players = _orderedPlayers;
    final topCount = players.length ~/ 2;
    for (int i = 0; i < players.length && i < rotations.length; i++) {
      // AdaptiveGrid wraps the top half in RotatedBox(quarterTurns: 2),
      // so we must compensate: subtract 2 quarter turns for top-row zones
      // to get the intended visual orientation.
      int effectiveRotation = rotations[i];
      if (i < topCount) {
        effectiveRotation = (rotations[i] - 2) % 4;
        if (effectiveRotation < 0) effectiveRotation += 4;
      }
      _controller.updateRotation(players[i].playerId, effectiveRotation);
    }
    setState(() {});
    _saveSnapshot();
    HapticFeedback.mediumImpact();
  }

  Widget _buildOrientationPreview(List<int> rotations, int count) {
    // Mirror the AdaptiveGrid layout: topCount = floor(count/2), bottomCount = count - topCount
    final topCount = count ~/ 2;
    final bottomCount = count - topCount;
    final rows = topCount == 0 ? 1 : 2;
    final maxCols = topCount > bottomCount ? topCount : bottomCount;

    return LayoutBuilder(builder: (ctx, constraints) {
      final cellW = constraints.maxWidth / maxCols;
      final cellH = constraints.maxHeight / rows;
      return Stack(
        children: List.generate(count, (i) {
          final bool isTop = i < topCount;
          final int row = isTop ? 0 : (rows - 1);
          final int col = isTop ? i : (i - topCount);
          final int rowCols = isTop ? topCount : bottomCount;
          // Center the row if it has fewer items than maxCols
          final double offsetX = (maxCols - rowCols) * cellW / 2;
          final rotation = rotations[i];
          final arrow = _arrowForRotation(rotation);
          return Positioned(
            left: offsetX + col * cellW,
            top: row * cellH,
            width: cellW,
            height: cellH,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.primaryShade800.withAlpha(60),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderMedium, width: 0.5),
              ),
              child: Center(
                child: Text(arrow, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
              ),
            ),
          );
        }),
      );
    });
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
      builder: (ctx) {
        final alivePlayers = _session?.players.where((p) => !p.isEliminated).length ?? 0;
        final totalPlayers = _playerCount;
        final monarchName = _session?.players
            .where((p) => p.isMonarch)
            .map((p) => p.config.name)
            .firstOrNull;

        return Container(
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
