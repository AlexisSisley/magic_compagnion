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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/controllers/game_session_controller.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_history_model.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/models/profile_model.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../router/app_router.dart';

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

  // --- Controller-based state ---
  GameSessionController _controller = GameSessionController();
  GameSession? _session;
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

  int? _highlightedPlayerId;
  bool _isSelectingStarter = false;

  Timer? _gameTimer;
  Duration _gameDuration = Duration.zero;
  bool _isGameActive = false;

  final List<Color> _defaultColors = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900,
    Colors.brown.shade800, Colors.pink.shade900, Colors.indigo.shade900, AppColors.greyShade800
  ];

  // --- Legacy Player bridge ---
  Player _toLegacyPlayer(int index, PlayerState ps) {
    return Player(
      id: index,
      name: ps.config.name,
      life: ps.life,
      colorValue: ps.config.colorValue,
      backgroundImagePath: ps.config.avatarPath,
      commanderDamageReceived: Map<int, int>.from(ps.commanderDamageReceived),
      poison: ps.counters['poison'] ?? 0,
      energy: ps.counters['energy'] ?? 0,
      commanderCastCount: ps.counters['commander_tax'] ?? 0,
      isMonarch: ps.isMonarch,
      quarterTurns: ps.quarterTurns,
    );
  }

  List<Player> get _legacyPlayers {
    if (_session == null) return [];
    return _session!.players
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
    _loadGame();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _deathTimers.forEach((_, t) => t.cancel());
    WakelockPlus.disable();
    super.dispose();
  }

  // --- LOGIQUE TIMER ---
  void _startGame() {
    _gameTimer?.cancel();
    setState(() {
      _isGameActive = true;
      _gameDuration = Duration.zero;
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _gameDuration += const Duration(seconds: 1));
    });
  }

  void _stopGame() {
    _gameTimer?.cancel();
    setState(() => _isGameActive = false);
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

    if (await sessionService.hasActiveGame()) {
      final snapshot = await sessionService.loadSnapshot();
      if (snapshot != null) {
        _controller = GameSessionController();
        setState(() {
          _session = snapshot;
          _currentFormat = snapshot.format;
          _isLoading = false;
        });
        return;
      }
    }

    // No saved game -- start fresh with defaults
    final prefs = await SharedPreferences.getInstance();
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
    final configs = List.generate(playerCount, (index) {
      final profile = (assignedProfiles != null && index < assignedProfiles.length)
          ? assignedProfiles[index]
          : null;
      final name = profile?.name ?? 'Joueur ${index + 1}';
      final color = profile?.colorValue ?? _defaultColors[index % _defaultColors.length].toARGB32();

      return PlayerConfig(
        id: 'player_$index',
        name: name,
        type: index == 0 ? PlayerType.owner : PlayerType.guest,
        colorValue: color,
        avatarPath: profile?.commanderImageUrl,
      );
    });

    _controller = GameSessionController();
    _controller.startNewGame(format: _currentFormat, playerConfigs: configs);

    // Apply default rotations
    final session = _controller.session;
    if (session != null) {
      for (int i = 0; i < playerCount; i++) {
        _controller.updateRotation(i, _calculateDefaultRotation(i, playerCount));
      }
    }

    setState(() => _session = _controller.session);
    _saveSnapshot();
  }

  Future<void> _saveSnapshot() async {
    if (_session == null) return;
    final sessionService = ref.read(gameSessionServiceProvider);
    await sessionService.saveSnapshot(_session!);
  }

  int _calculateDefaultRotation(int id, int totalPlayers) {
    if (totalPlayers == 4) return (id % 2 == 0) ? 1 : 3;
    return (id < (totalPlayers / 2).ceil()) ? 2 : 0;
  }

  // --- DEATH CONFIRMATION ---
  void _checkDeathCondition(int playerId) {
    final player = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
    if (player == null) return;

    if (player.life <= 0 && !player.isEliminated && !_dismissedDeathOverlay.contains(playerId)) {
      if (!_deathTimers.containsKey(playerId)) {
        _deathTimers[playerId] = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          final currentPlayer = _session?.players.where((p) => p.playerId == playerId).firstOrNull;
          if (currentPlayer != null && currentPlayer.life <= 0 && !currentPlayer.isEliminated) {
            setState(() => _showDeathOverlay.add(playerId));
          }
          _deathTimers.remove(playerId);
        });
      }
    } else {
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
      _session = _controller.session;
      _showDeathOverlay.remove(playerId);
    });
    _saveSnapshot();
  }

  // --- ACTIONS JOUEURS ---
  void _resetGame({List<Profile?>? assignedProfiles}) {
    _stopGame();
    setState(() {
      _gameDuration = Duration.zero;
      _deathTimers.forEach((_, t) => t.cancel());
      _deathTimers.clear();
      _showDeathOverlay.clear();
      _dismissedDeathOverlay.clear();
    });

    final count = assignedProfiles?.length ?? _playerCount;
    _startNewGame(playerCount: count > 0 ? count : 4, assignedProfiles: assignedProfiles);
  }

  void _updateLife(int playerId, int change) {
    if (_isSelectingStarter) return;
    if (_session == null) return;
    _controller.updateLife(playerId, change, gameDuration: _gameDuration);
    setState(() => _session = _controller.session);
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
    setState(() => _session = _session!.copyWith(players: players));
    // Sync controller
    _controller = GameSessionController();
    _controller.startNewGame(format: _currentFormat, playerConfigs: _session!.players.map((p) => p.config).toList());
    _saveSnapshot();
  }

  void _updatePlayerRotation(int playerId, int rotation) {
    if (_session == null) return;
    _controller.updateRotation(playerId, rotation);
    setState(() => _session = _controller.session);
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
    setState(() => _session = _session!.copyWith(players: players));
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
        onGameStart: (life, profiles) {
          // Find matching format or use custom
          final matchingFormat = GameFormat.builtInFormats.where(
            (f) => f.startingLife == life,
          ).firstOrNull;
          if (matchingFormat != null) {
            _currentFormat = matchingFormat;
          } else {
            _currentFormat = GameFormat.builtInFormats.last.copyWith(startingLife: life);
          }
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
                      // Use addCommanderDamage with negative damage to decrement
                      _controller.addCommanderDamage(
                        targetPlayerId: opponent.id,
                        sourcePlayerId: attacker.id,
                        damage: -1,
                        gameDuration: _gameDuration,
                      );
                      // Compensate the life loss from addCommanderDamage (it subtracts damage from life)
                      _controller.updateLife(opponent.id, -1, gameDuration: _gameDuration);
                      setState(() => _session = _controller.session);
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
                    setState(() => _session = _controller.session);
                    _saveSnapshot();
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: Text('Type de victoire ?', style: AppTextStyles.cinzel()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.favorite, color: AppColors.accentRed),
                title: const Text('Points de Vie (Standard)', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _finalizeGameSave(winner, 'normal'),
              ),
              ListTile(
                leading: const Icon(Icons.shield, color: AppColors.accent),
                title: const Text('Dégâts de Commandant', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _finalizeGameSave(winner, 'commander'),
              ),
              ListTile(
                leading: const Icon(Icons.science, color: AppColors.accentGreen),
                title: const Text('Poison / Infect', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _finalizeGameSave(winner, 'poison'),
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: AppColors.textSecondary),
                title: const Text('Concession', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _finalizeGameSave(winner, 'concede'),
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _finalizeGameSave(Player winner, String method) async {
    Navigator.pop(context); // Ferme la modale de méthode

    final players = _legacyPlayers;

    // Création des snapshots des joueurs
    List<PlayerHistorySnapshot> snapshots = players.map((p) {
      // Calcul du total des dégâts de commandant reçus (tous adversaires confondus)
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

    await _gameHistoryService.addGame(newItem);
    _controller.endGame();
    _stopGame();

    // Clear saved snapshot since game is over
    final sessionService = ref.read(gameSessionServiceProvider);
    await sessionService.clearSnapshot();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Partie enregistrée dans l'historique !"), backgroundColor: AppColors.success)
      );
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));

    final players = _legacyPlayers;
    final playerZones = players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      final playerState = _session!.players[index];

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

    if (_showDeathOverlay.contains(playerState.playerId)) {
      zone = Stack(
        children: [
          zone,
          Positioned.fill(
            child: DeathConfirmationOverlay(
              playerName: player.name,
              currentLife: player.life,
              onDismiss: () => _dismissDeath(playerState.playerId),
              onConfirmElimination: () => _confirmElimination(playerState.playerId),
            ),
          ),
        ],
      );
    }

    return zone;
  }

  void _onReorderPlayers(int oldIndex, int newIndex) {
    if (_session == null) return;
    final order = List<int>.from(_session!.playerOrder);
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    _controller.reorderPlayers(order);
    setState(() => _session = _controller.session);
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
    );
  }

  Widget _buildCentralBar() {
    return Container(
      height: 60, color: AppColors.textOnPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.textSecondary), onPressed: () => _resetGame()),
          IconButton(icon: const Icon(Icons.casino, color: AppColors.textSecondary), onPressed: _showDiceSelector),
          InkWell(
            onTap: _isGameActive ? _endGame : _pickStartingPlayer,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 50, height: 50, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.textOnPrimary, border: Border.all(color: _isGameActive ? AppColors.accentRed : AppColors.primaryShade800, width: 2)),
              child: _isGameActive
                ? FittedBox(fit: BoxFit.scaleDown, child: Text(_formatDuration(_gameDuration), style: GoogleFonts.robotoMono(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)))
                : const Icon(Icons.play_arrow, color: AppColors.primary),
            ),
          ),
          IconButton(icon: const Icon(Icons.emoji_events, color: AppColors.textSecondary), onPressed: () { context.push(AppRoutes.tournament); }),
          IconButton(icon: const Icon(Icons.people, color: AppColors.textSecondary), onPressed: _showGameSetupDialog),
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
