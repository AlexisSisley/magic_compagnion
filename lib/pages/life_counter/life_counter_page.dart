// Fichier : lib/pages/life_counter/life_counter_page.dart

import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/game_history_model.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/models/profile_model.dart';
import 'package:magic_companion/pages/tournaments/tournament_page.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/life_counter/player_zone.dart';
import '../../widgets/life_counter/dice_roll_dialog.dart'; // <--- Import
import '../../widgets/life_counter/game_setup_modal.dart'; // <--- Import

class LifeCounterPage extends StatefulWidget {
  const LifeCounterPage({super.key});

  @override
  State<LifeCounterPage> createState() => _LifeCounterPageState();
}

class _LifeCounterPageState extends State<LifeCounterPage> {
  final GameHistoryService _gameHistoryService = GameHistoryService();
  
  List<Player> _players = [];
  int _startingLife = 40; 
  int _playerCount = 4;
  bool _isLoading = true;
  
  int? _highlightedPlayerId;
  bool _isSelectingStarter = false;

  Timer? _gameTimer;
  Duration _gameDuration = Duration.zero;
  bool _isGameActive = false;

  final List<Color> _defaultColors = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900,
    Colors.brown.shade800, Colors.pink.shade900, Colors.indigo.shade900, Colors.grey.shade800
  ];

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
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
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? "${d.inHours}:$minutes" : "$minutes:$seconds";
  }

  // --- SAUVEGARDE & CHARGEMENT ---
  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerCount = prefs.getInt('playerCount') ?? 4;
      _startingLife = prefs.getInt('startingLife') ?? 40;

      _players = List.generate(_playerCount, (index) {
          final life = prefs.getInt('player_${index}_life') ?? _startingLife;
          final colorVal = prefs.getInt('player_${index}_color') ?? _defaultColors[index % _defaultColors.length].value;
          final bgPath = prefs.getString('player_${index}_bg');
          final name = prefs.getString('player_${index}_name') ?? "Joueur ${index + 1}";
          
          Map<int, int> cmdDamage = {};
          if (_startingLife == 40) {
            for (int i = 0; i < _playerCount; i++) {
              if (i == index) continue;
              cmdDamage[i] = prefs.getInt('player_${index}_cmd_from_$i') ?? 0;
            }
          }

          return Player(
            id: index,
            name: name,
            life: life,
            colorValue: colorVal,
            backgroundImagePath: bgPath,
            commanderDamageReceived: cmdDamage,
            poison: prefs.getInt('player_${index}_poison') ?? 0,
            energy: prefs.getInt('player_${index}_energy') ?? 0,
            commanderCastCount: prefs.getInt('player_${index}_tax') ?? 0,
            isMonarch: prefs.getBool('player_${index}_monarch') ?? false,
            quarterTurns: prefs.getInt('player_${index}_rotation') ?? _calculateDefaultRotation(index, _playerCount), 
          );
      });
      _isLoading = false;
    });
  }

  Future<void> _saveGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('playerCount', _playerCount);
    await prefs.setInt('startingLife', _startingLife);

    for (final player in _players) {
      await prefs.setInt('player_${player.id}_life', player.life);
      await prefs.setInt('player_${player.id}_color', player.colorValue);
      await prefs.setString('player_${player.id}_name', player.name);
      
      if (player.backgroundImagePath != null) {
        await prefs.setString('player_${player.id}_bg', player.backgroundImagePath!);
      } else {
        await prefs.remove('player_${player.id}_bg');
      }

      await prefs.setInt('player_${player.id}_poison', player.poison);
      await prefs.setInt('player_${player.id}_energy', player.energy);
      await prefs.setInt('player_${player.id}_tax', player.commanderCastCount);
      await prefs.setBool('player_${player.id}_monarch', player.isMonarch);
      await prefs.setInt('player_${player.id}_rotation', player.quarterTurns);

      for (final opponentId in player.commanderDamageReceived.keys) {
        await prefs.setInt('player_${player.id}_cmd_from_$opponentId', player.commanderDamageReceived[opponentId]!);
      }
    }
  }

  int _calculateDefaultRotation(int id, int totalPlayers) {
    if (totalPlayers == 4) return (id % 2 == 0) ? 1 : 3;
    return (id < (totalPlayers / 2).ceil()) ? 2 : 0;
  }

  // --- ACTIONS JOUEURS ---
  void _resetGame({List<Profile?>? assignedProfiles}) {
    _stopGame(); 
    setState(() {
      _gameDuration = Duration.zero;
      if (assignedProfiles != null) _playerCount = assignedProfiles.length;

      _players = List.generate(_playerCount, (index) {
          Map<int, int> cmdDamage = {};
          if (_startingLife == 40) {
            for (int i = 0; i < _playerCount; i++) if (i != index) cmdDamage[i] = 0;
          }

          Profile? profile = (assignedProfiles != null && index < assignedProfiles.length) ? assignedProfiles[index] : null;
          String name = profile?.name ?? "Joueur ${index + 1}";
          int color = profile?.colorValue ?? _defaultColors[index % _defaultColors.length].value;
          String? bgPath = profile?.commanderImageUrl;

          return Player(
            id: index, name: name, life: _startingLife, colorValue: color, backgroundImagePath: bgPath,
            commanderDamageReceived: cmdDamage,
            quarterTurns: _calculateDefaultRotation(index, _playerCount),
          );
      });
    });
    _saveGame();
  }
  
  void _updateLife(int playerId, int change) {
    if (_isSelectingStarter) return;
    setState(() => _players.firstWhere((p) => p.id == playerId).life += change);
    _saveGame();
  }

  Future<void> _pickStartingPlayer() async {
    if (_isSelectingStarter) return;
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
          backgroundColor: const Color(0xFF1A1A1A),
          title: Center(child: Text("Le Destin a choisi !", style: GoogleFonts.cinzel(color: Colors.white70))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 50, color: Color(_players[winnerId].colorValue)),
              const SizedBox(height: 16),
              Text(_players[winnerId].name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(context); setState(() { _highlightedPlayerId = null; _isSelectingStarter = false; }); _startGame(); }, 
              style: ElevatedButton.styleFrom(backgroundColor: Color(_players[winnerId].colorValue)), 
              child: const Text("C'est parti !", style: TextStyle(color: Colors.white))
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
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => GameSetupModal(
        initialLife: _startingLife,
        onGameStart: (life, profiles) {
          setState(() => _startingLife = life);
          _resetGame(assignedProfiles: profiles);
        },
      )
    );
  }

  void _showCommanderDamageSelector(Player attacker) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A).withOpacity(0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
        child: Wrap(
          children: [
            ListTile(title: Text('Dégâts de Commandant', style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text('Attaquant : ${attacker.name}', style: GoogleFonts.cinzel(color: Colors.white70))),
            ..._players.where((opp) => opp.id != attacker.id).map((opponent) {
              final damage = opponent.commanderDamageReceived[attacker.id] ?? 0;
              return ListTile(
                leading: Icon(Icons.shield, color: Color(opponent.colorValue)),
                title: Text(opponent.name, style: const TextStyle(color: Colors.white)),
                trailing: SizedBox(width: 150, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(icon: const Icon(Icons.remove, color: Colors.white70), onPressed: () { 
                    setState(() => opponent.commanderDamageReceived[attacker.id] = (damage - 1).clamp(0, 99)); _saveGame(); Navigator.pop(context); _showCommanderDamageSelector(attacker); 
                  }),
                  Text('$damage', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add, color: Colors.white70), onPressed: () { 
                    setState(() => opponent.commanderDamageReceived[attacker.id] = (damage + 1).clamp(0, 99)); _saveGame(); Navigator.pop(context); _showCommanderDamageSelector(attacker); 
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("Qui a gagné ?", style: GoogleFonts.cinzel(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _players.map((p) {
              return ListTile(
                leading: Icon(Icons.emoji_events, color: Color(p.colorValue)),
                title: Text(p.name, style: const TextStyle(color: Colors.white)),
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
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("Type de victoire ?", style: GoogleFonts.cinzel(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.redAccent),
                title: const Text("Points de Vie (Standard)", style: TextStyle(color: Colors.white)),
                onTap: () => _finalizeGameSave(winner, 'normal'),
              ),
              ListTile(
                leading: const Icon(Icons.shield, color: Colors.blueAccent),
                title: const Text("Dégâts de Commandant", style: TextStyle(color: Colors.white)),
                onTap: () => _finalizeGameSave(winner, 'commander'),
              ),
              ListTile(
                leading: const Icon(Icons.science, color: Colors.greenAccent),
                title: const Text("Poison / Infect", style: TextStyle(color: Colors.white)),
                onTap: () => _finalizeGameSave(winner, 'poison'),
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.white70),
                title: const Text("Concession", style: TextStyle(color: Colors.white)),
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

    // Création des snapshots des joueurs
    List<PlayerHistorySnapshot> snapshots = _players.map((p) {
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
      durationSeconds: _gameDuration.inSeconds, // <-- Le temps de la partie
      winnerName: winner.name,
      format: _startingLife == 40 ? "Commander" : "Standard",
      winMethod: method,
      playerStates: snapshots,
    );

    await _gameHistoryService.addGame(newItem);
    _stopGame();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Partie enregistrée dans l'historique !"), backgroundColor: Colors.green)
      );
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    final bool useCentralMenu = _playerCount >= 2;

    return Stack(
      children: [
        Column(children: [
          Expanded(child: Row(children: _players.sublist(0, (_playerCount/2).ceil()).map((p) => Expanded(child: Padding(padding: const EdgeInsets.all(2), child: _buildPlayerZone(p)))).toList())),
          if (useCentralMenu) _buildCentralBar(),
          if (!useCentralMenu) Container(height: 2, color: Colors.black),
          Expanded(child: Row(children: _players.sublist((_playerCount/2).ceil()).map((p) => Expanded(child: Padding(padding: const EdgeInsets.all(2), child: _buildPlayerZone(p)))).toList())),
        ]),
        if (!useCentralMenu) ...[
          Positioned(bottom: 16, right: 90, child: FloatingActionButton(heroTag: 'dice', onPressed: _showDiceSelector, backgroundColor: Colors.black54, foregroundColor: Colors.white, child: const Icon(Icons.casino_outlined))),
          Positioned(bottom: 16, right: 16, child: _buildSpeedDial()),
        ]
      ],
    );
  }

  Widget _buildPlayerZone(Player p) {
    return PlayerZone(
      player: p, isCommander: _startingLife == 40, isHighlighted: _highlightedPlayerId == p.id,
      onLifeChanged: (val) => _updateLife(p.id, val),
      onShowCommanderDamage: () => _showCommanderDamageSelector(p),
      onColorChanged: (c) { setState(() => p.colorValue = c.value); _saveGame(); },
      onRotationChanged: (r) { setState(() => p.quarterTurns = r); _saveGame(); },
      onSkinChanged: (path) { setState(() => p.backgroundImagePath = path); _saveGame(); },
    );
  }

  Widget _buildCentralBar() {
    return Container(
      height: 60, color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => _resetGame()),
          IconButton(icon: const Icon(Icons.casino, color: Colors.white70), onPressed: _showDiceSelector),
          InkWell(
            onTap: _isGameActive ? _endGame : _pickStartingPlayer,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 50, height: 50, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: _isGameActive ? Colors.redAccent : Colors.yellow.shade800, width: 2)),
              child: _isGameActive 
                ? FittedBox(fit: BoxFit.scaleDown, child: Text(_formatDuration(_gameDuration), style: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))
                : const Icon(Icons.play_arrow, color: Colors.yellow),
            ),
          ),
          IconButton(icon: const Icon(Icons.emoji_events, color: Colors.white70), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentPage())); }),
          IconButton(icon: const Icon(Icons.people, color: Colors.white70), onPressed: _showGameSetupDialog), // <--- Utilise la nouvelle modale
        ],
      ),
    );
  }

  Widget _buildSpeedDial() {
    return SpeedDial(
      icon: Icons.menu, activeIcon: Icons.close, backgroundColor: Colors.black.withOpacity(0.8), foregroundColor: Colors.white, overlayColor: Colors.black, overlayOpacity: 0.4, spacing: 12,
      children: [
        SpeedDialChild(child: const Icon(Icons.play_circle_fill), label: 'Qui commence ?', backgroundColor: Colors.amber.shade800, onTap: _pickStartingPlayer),
        SpeedDialChild(child: const Icon(Icons.people_alt), label: 'Config. Partie', onTap: _showGameSetupDialog),
        SpeedDialChild(child: const Icon(Icons.refresh), label: 'Reset', onTap: () => _resetGame()),
      ],
    );
  }

  void _showDiceSelector() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) {
        final dice = [2, 4, 6, 8, 10, 12, 20, 100];
        return Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Lancer un dé", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22)),
            const SizedBox(height: 24),
            GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: dice.length, itemBuilder: (context, i) => ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, padding: EdgeInsets.zero),
                onPressed: () { Navigator.pop(context); _rollDice(dice[i]); },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.casino, color: Colors.white70), Text("D${dice[i]}", style: GoogleFonts.cinzel(fontSize: 12))]),
            ))
        ]));
    });
  }

  void _rollDice(int sides) {
    showDialog(context: context, barrierDismissible: false, builder: (c) => DiceRollAnimationDialog(sides: sides, finalResult: Random().nextInt(sides) + 1, onReroll: () { Navigator.pop(c); _rollDice(sides); }));
  }
}