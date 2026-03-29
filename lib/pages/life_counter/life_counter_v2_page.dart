// Fichier : lib/pages/life_counter/life_counter_v2_page.dart
// Task 18: Integrated Life Counter v2 page using new architecture
//
// Uses: GameSessionController, LayoutResolver, QuickStartPage,
//       CriticalOverlay, EliminationOverlay, RadialMenu, GameControlBar

import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/controllers/game_session_controller.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_history_model.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/providers/game_session_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/game_session_service.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/widgets/life_counter/animations/animation_service.dart';
import 'package:magic_companion/widgets/life_counter/critical_overlay.dart';
import 'package:magic_companion/widgets/life_counter/elimination_overlay.dart';
import 'package:magic_companion/widgets/life_counter/game_control_bar.dart';
import 'package:magic_companion/widgets/life_counter/layouts/face_to_face_layout.dart';
import 'package:magic_companion/widgets/life_counter/layouts/focus_layout.dart';
import 'package:magic_companion/widgets/life_counter/layouts/grid_layout.dart';
import 'package:magic_companion/widgets/life_counter/layouts/layout_strategy.dart';
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/player_zone_compact.dart';
import 'package:magic_companion/widgets/life_counter/setup/quick_start_page.dart';
import 'package:magic_companion/widgets/life_counter/dice_roll_dialog.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Life Counter v2 page — uses GameSessionController and new layout system.
class LifeCounterV2Page extends ConsumerStatefulWidget {
  final bool isInShell;

  const LifeCounterV2Page({super.key, this.isInShell = false});

  @override
  ConsumerState<LifeCounterV2Page> createState() => _LifeCounterV2PageState();
}

class _LifeCounterV2PageState extends ConsumerState<LifeCounterV2Page> {
  GameSessionController? _controller;
  GameSession? _session;
  bool _showSetup = true;
  LayoutType? _layoutPreference;

  // Timer
  Timer? _gameTimer;
  Duration _gameDuration = Duration.zero;
  bool _isGameActive = false;

  // Player model bridge (maps session players to legacy Player objects)
  List<Player> _legacyPlayers = [];

  final List<Color> _defaultColors = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900,
    Colors.brown.shade800, Colors.pink.shade900,
  ];

  @override
  void initState() {
    super.initState();
    _checkCrashRecovery();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _checkCrashRecovery() async {
    final service = GameSessionService();
    if (await service.hasActiveGame()) {
      final snapshot = await service.loadSnapshot();
      if (snapshot != null && mounted) {
        _startFromSession(snapshot);
        return;
      }
    }
    // No crash recovery — show setup
    setState(() => _showSetup = true);
  }

  void _startFromSession(GameSession session) {
    final controller = GameSessionController();
    controller.startNewGame(
      format: session.format,
      playerConfigs: session.players.map((p) => p.config).toList(),
    );

    setState(() {
      _controller = controller;
      _session = controller.session;
      _showSetup = false;
      _buildLegacyPlayers();
    });
    _startTimer();
    _saveSnapshot();
  }

  void _startGame(GameFormat format, int playerCount) {
    final configs = List.generate(playerCount, (i) => PlayerConfig(
      id: 'player_$i',
      name: 'Player ${i + 1}',
      type: i == 0 ? PlayerType.owner : PlayerType.guest,
      colorValue: _defaultColors[i % _defaultColors.length].toARGB32(),
    ));

    final controller = GameSessionController();
    controller.startNewGame(format: format, playerConfigs: configs);

    setState(() {
      _controller = controller;
      _session = controller.session;
      _showSetup = false;
      _buildLegacyPlayers();
    });
    _startTimer();
    _saveSnapshot();
  }

  void _buildLegacyPlayers() {
    if (_session == null) return;
    _legacyPlayers = _session!.players.asMap().entries.map((entry) {
      final i = entry.key;
      final ps = entry.value;
      return Player(
        id: i,
        name: ps.config.name,
        life: ps.life,
        colorValue: ps.config.colorValue,
        poison: ps.counters['poison'] ?? 0,
        energy: ps.counters['energy'] ?? 0,
        commanderCastCount: ps.counters['commander_tax'] ?? 0,
        isMonarch: ps.isMonarch,
        commanderDamageReceived: {},
      );
    }).toList();
  }

  // Timer
  void _startTimer() {
    _gameTimer?.cancel();
    setState(() {
      _isGameActive = true;
      _gameDuration = Duration.zero;
    });
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _gameDuration += const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _gameTimer?.cancel();
    setState(() => _isGameActive = false);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$m' : '$m:$s';
  }

  // Actions
  void _updateLife(int playerIndex, int delta) {
    _controller?.updateLife(playerIndex, delta, gameDuration: _gameDuration);
    setState(() {
      _session = _controller?.session;
      _buildLegacyPlayers();
    });
    _saveSnapshot();
  }

  void _toggleMonarch(int playerIndex) {
    _controller?.toggleMonarch(playerIndex);
    setState(() {
      _session = _controller?.session;
      _buildLegacyPlayers();
    });
    _saveSnapshot();
  }

  void _eliminatePlayer(int playerIndex) {
    _controller?.eliminatePlayer(playerIndex, atDuration: _gameDuration);
    setState(() {
      _session = _controller?.session;
      _buildLegacyPlayers();
    });
    _saveSnapshot();
  }

  void _switchLayout() {
    final current = _layoutPreference ?? LayoutResolver.resolve(
      _session?.players.length ?? 2,
    );
    setState(() {
      _layoutPreference = current == LayoutType.grid
          ? LayoutType.focus
          : LayoutType.grid;
    });
  }

  void _endGame() {
    if (_session == null) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: Text('Qui a gagné ?', style: AppTextStyles.cinzel()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _session!.players.asMap().entries
                .where((e) => !e.value.isEliminated)
                .map((e) {
              return ListTile(
                leading: Icon(Icons.emoji_events,
                    color: Color(e.value.config.colorValue)),
                title: Text(e.value.config.name,
                    style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _finalizeGame(e.key);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _finalizeGame(int winnerIndex) async {
    _stopTimer();
    final session = _session!;
    final winner = session.players[winnerIndex];

    // Build enriched snapshots
    final snapshots = session.players.map((ps) {
      return PlayerHistorySnapshot(
        name: ps.config.name,
        imageUrl: null,
        life: ps.life,
        poison: ps.counters['poison'] ?? 0,
        commanderDamageTaken: ps.commanderDamageReceived.values
            .fold(0, (sum, val) => sum + val),
        type: ps.config.type == PlayerType.owner ? 'owner' : 'guest',
        deckName: ps.config.linkedDeckId,
        commanderNames: ps.config.commanders.map((c) => c.name).toList(),
        energy: ps.counters['energy'] ?? 0,
        commanderTax: ps.counters['commander_tax'] ?? 0,
        isEliminated: ps.isEliminated,
      );
    }).toList();

    final item = GameHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      durationSeconds: _gameDuration.inSeconds,
      winnerName: winner.config.name,
      format: session.format.name,
      winMethod: 'normal',
      playerStates: snapshots,
    );

    await ref.read(gameHistoryServiceProvider).addGame(item);
    await GameSessionService().clearSnapshot();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Partie enregistrée !"),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _showSetup = true);
    }
  }

  Future<void> _saveSnapshot() async {
    if (_session != null) {
      await GameSessionService().saveSnapshot(_session!);
    }
  }

  void _rollDice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      builder: (context) {
        final dice = [2, 4, 6, 8, 10, 12, 20, 100];
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lancer un dé', style: AppTextStyles.cinzel(fontSize: 22)),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: dice.length,
                itemBuilder: (context, i) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.borderLight,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showDiceResult(dice[i]);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.casino, color: AppColors.textSecondary),
                      Text('D${dice[i]}', style: AppTextStyles.label()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDiceResult(int sides) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => DiceRollAnimationDialog(
        sides: sides,
        finalResult: Random().nextInt(sides) + 1,
        onReroll: () {
          Navigator.pop(c);
          _showDiceResult(sides);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSetup) {
      return QuickStartPage(
        onStart: _startGame,
      );
    }

    final session = _session!;
    final playerCount = session.players.length;
    final layout = LayoutResolver.resolve(
      playerCount,
      preference: _layoutPreference,
    );

    return Stack(
      children: [
        _buildLayout(layout, session),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: GameControlBar(
              onDiceRoll: _rollDice,
              onTimerToggle: _isGameActive ? _stopTimer : _startTimer,
              timerText: _isGameActive ? _formatDuration(_gameDuration) : null,
              onSwitchLayout:
                  playerCount >= 3 ? _switchLayout : null,
              onEndGame: _endGame,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLayout(LayoutType layout, GameSession session) {
    final zones = session.players.asMap().entries.map((entry) {
      return _buildPlayerZoneWithOverlays(entry.key, entry.value);
    }).toList();

    switch (layout) {
      case LayoutType.faceToFace:
        return FaceToFaceLayout(
          topPlayer: zones[0],
          bottomPlayer: zones.length > 1 ? zones[1] : const SizedBox(),
        );
      case LayoutType.grid:
        return GridLayout(playerZones: zones);
      case LayoutType.focus:
        return FocusLayout(
          ownerZone: zones.first,
          adversaryZones: zones.length > 1
              ? zones.sublist(1).map((z) {
                  final idx = zones.indexOf(z);
                  final ps = session.players[idx];
                  return PlayerZoneCompact(
                    playerName: ps.config.name,
                    lifeTotal: ps.life,
                    playerColor: Color(ps.config.colorValue),
                    isEliminated: ps.isEliminated,
                  );
                }).toList()
              : [],
        );
    }
  }

  Widget _buildPlayerZoneWithOverlays(int index, PlayerState playerState) {
    final criticalLevel = AnimationService.getCriticalLevel(
      currentLife: playerState.life,
      startingLife: _session!.format.startingLife,
    );

    return CriticalOverlay(
      level: criticalLevel,
      child: EliminationOverlay(
        isEliminated: playerState.isEliminated,
        child: _buildPlayerZone(index, playerState),
      ),
    );
  }

  Widget _buildPlayerZone(int index, PlayerState playerState) {
    // Bridge to legacy PlayerZone
    final player = _legacyPlayers.length > index
        ? _legacyPlayers[index]
        : Player(
            id: index,
            name: playerState.config.name,
            life: playerState.life,
            colorValue: playerState.config.colorValue,
            commanderDamageReceived: {},
          );

    return PlayerZone(
      player: player,
      isCommander: _session!.format.maxCommanders > 0,
      onLifeChanged: (val) => _updateLife(index, val),
      onShowCommanderDamage: () {},
      onColorChanged: (_) {},
    );
  }
}
