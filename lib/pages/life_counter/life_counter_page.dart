// Fichier : lib/pages/life_counter/life_counter_page.dart

import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/game_history_model.dart';
import 'package:magic_companion/pages/settings/dev_tools_page.dart';
import 'package:magic_companion/pages/glossary/turn_guide_page.dart';
import 'package:magic_companion/pages/tournaments/tournament_page.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/player_model.dart';
import '../../widgets/life_counter/player_zone.dart';

class LifeCounterPage extends StatefulWidget {
  const LifeCounterPage({super.key});

  @override
  State<LifeCounterPage> createState() => _LifeCounterPageState();
}

class _LifeCounterPageState extends State<LifeCounterPage> {
  final GameHistoryService _gameHistoryService = GameHistoryService();
  
  List<Player> _players = [];
  int _startingLife = 40; // Défaut Commander pour l'usage courant
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
      if (mounted) {
        setState(() {
          _gameDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopGame() {
    _gameTimer?.cancel();
    setState(() {
      _isGameActive = false;
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${d.inHours}:$minutes"; // H:MM
    }
    return "$minutes:$seconds"; // MM:SS
  }

  int _calculateDefaultRotation(int id, int totalPlayers) {
    if (totalPlayers == 4) {
      // Spécifique 4 joueurs : Gauche (0,2) = 1 (90°), Droite (1,3) = 3 (270°)
      bool isLeft = (id % 2 == 0);
      return isLeft ? 1 : 3;
    } else {
      // Standard : Haut = 2 (180°), Bas = 0 (0°)
      int splitIndex = (totalPlayers / 2).ceil();
      bool isTop = id < splitIndex;
      return isTop ? 2 : 0;
    }
  }

  // --- SAUVEGARDE & CHARGEMENT ---
  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerCount = prefs.getInt('playerCount') ?? 4;
      _startingLife = prefs.getInt('startingLife') ?? 40;

      _players = List.generate(
        _playerCount,
        (index) {
          final life = prefs.getInt('player_${index}_life') ?? _startingLife;
          final colorVal = prefs.getInt('player_${index}_color') ?? _defaultColors[index % _defaultColors.length].value;
          
          final poison = prefs.getInt('player_${index}_poison') ?? 0;
          final energy = prefs.getInt('player_${index}_energy') ?? 0;
          final tax = prefs.getInt('player_${index}_tax') ?? 0;
          final isMonarch = prefs.getBool('player_${index}_monarch') ?? false;
          
          // Chargement de la rotation (si existe, sinon calcul par défaut)
          final savedRotation = prefs.getInt('player_${index}_rotation');
          final rotation = savedRotation ?? _calculateDefaultRotation(index, _playerCount);

          Map<int, int> cmdDamage = {};
          if (_startingLife == 40) {
            for (int i = 0; i < _playerCount; i++) {
              if (i == index) continue;
              cmdDamage[i] = prefs.getInt('player_${index}_cmd_from_$i') ?? 0;
            }
          }

          return Player(
            id: index,
            life: life,
            colorValue: colorVal,
            commanderDamageReceived: cmdDamage,
            poison: poison,
            energy: energy,
            commanderCastCount: tax,
            isMonarch: isMonarch,
            quarterTurns: rotation, 
          );
        },
      );
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
      await prefs.setInt('player_${player.id}_poison', player.poison);
      await prefs.setInt('player_${player.id}_energy', player.energy);
      await prefs.setInt('player_${player.id}_tax', player.commanderCastCount);
      await prefs.setBool('player_${player.id}_monarch', player.isMonarch);
      
      // Sauvegarde rotation
      await prefs.setInt('player_${player.id}_rotation', player.quarterTurns);

      for (final opponentId in player.commanderDamageReceived.keys) {
        final damage = player.commanderDamageReceived[opponentId]!;
        await prefs.setInt('player_${player.id}_cmd_from_$opponentId', damage);
      }
    }
  }

  // --- LOGIQUE JEU ---
  void _resetGame() {
    _stopGame(); // Arrête le chrono au reset
    setState(() {
      _gameDuration = Duration.zero; // Remet le chrono à 0
      _players = List.generate(
        _playerCount,
        (index) {
          Map<int, int> cmdDamage = {};
          if (_startingLife == 40) {
            for (int i = 0; i < _playerCount; i++) {
              if (i == index) continue;
              cmdDamage[i] = 0;
            }
          }
          return Player(
            id: index,
            life: _startingLife,
            colorValue: _defaultColors[index % _defaultColors.length].value,
            commanderDamageReceived: cmdDamage,
            poison: 0,
            energy: 0,
            commanderCastCount: 0,
            isMonarch: false,
            quarterTurns: _calculateDefaultRotation(index, _playerCount),
          );
        },
      );
    });
    _saveGame();
  }
  
  // ---- Update point -----
  void _updateLife(int playerId, int change) {
    if (_isSelectingStarter) return;
    setState(() {
      _players.firstWhere((p) => p.id == playerId).life += change;
    });
    _saveGame();
  }

  void _updatePlayerColor(int playerId, Color newColor) {
    setState(() {
      _players.firstWhere((p) => p.id == playerId).colorValue = newColor.value;
    });
    _saveGame();
  }

  void _updatePlayerRotation(int playerId, int newRotation) {
    setState(() {
      _players.firstWhere((p) => p.id == playerId).quarterTurns = newRotation;
    });
    _saveGame();
  }

  void _updateCommanderDamage(int playerId, int opponentId, int change) {
    if (_isSelectingStarter) return;
    setState(() {
      final player = _players.firstWhere((p) => p.id == playerId);
      final currentDamage = player.commanderDamageReceived[opponentId] ?? 0;
      player.commanderDamageReceived[opponentId] = (currentDamage + change).clamp(0, 99);
    });
    _saveGame();
  }
  
  Future<void> _pickStartingPlayer() async {
    if (_isSelectingStarter) return;
    setState(() { _isSelectingStarter = true; });
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
              Text("JOUEUR ${winnerId + 1}", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { 
                Navigator.pop(context); 
                setState(() { 
                  _highlightedPlayerId = null; 
                  _isSelectingStarter = false; 
                });
                _startGame(); // <--- LANCE LE CHRONO ICI
              }, 
              style: ElevatedButton.styleFrom(backgroundColor: Color(_players[winnerId].colorValue)), 
              child: const Text("C'est parti !", style: TextStyle(color: Colors.white))
            )
          ]
        ),
      );
    }
  }

  // --- SYSTÈME DE DÉS COMPLET ---
  
  void _showDiceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // Liste des dés disponibles (2 = Coin Flip)
        final List<int> diceTypes = [2, 4, 6, 8, 10, 12, 20, 100];

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Lancer un dé", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: diceTypes.length,
                itemBuilder: (context, index) {
                  final sides = diceTypes[index];
                  return _buildDiceButton(context, sides);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDiceButton(BuildContext context, int sides) {
    // ignore: unused_local_variable
    String label = "D$sides";
    IconData? icon;
    // Choix d'icônes représentatives
    if (sides == 2) {
      label = "Pile/Face";
      icon = Icons.monetization_on;
    } else if (sides == 4) {
      icon = Icons.change_history; // Triangle
    } else if (sides == 6) {
      icon = Icons.looks_6; 
    } else if (sides == 8) {
      icon = Icons.diamond; // Forme octaèdre
    } else if (sides == 20) {
      icon = Icons.casino; 
    } else {
       icon = Icons.all_out; // Générique pour les autres
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.05),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), 
          side: BorderSide(color: Colors.yellow.shade800.withOpacity(0.5))
        ),
        padding: EdgeInsets.zero,
      ),
      onPressed: () {
        Navigator.pop(context);
        _rollSpecificDice(sides);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Colors.white70),
          const SizedBox(height: 4),
          Text(
            sides == 2 ? "COIN" : "D$sides", 
            style: GoogleFonts.cinzel(fontSize: sides == 2 ? 10 : 14, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  // Fonction modifiée pour lancer l'animation
  void _rollSpecificDice(int sides) {
    // On calcule le résultat AVANT d'ouvrir la modale
    final int finalResult = Random().nextInt(sides) + 1;

    showDialog(
      context: context,
      barrierDismissible: false, // On empêche de fermer pendant l'animation
      builder: (context) {
        return DiceRollAnimationDialog(
          sides: sides,
          finalResult: finalResult,
          onReroll: () {
            Navigator.pop(context);
            _rollSpecificDice(sides);
          },
        );
      }
    );
  }

  void _showFormatSelector() {
    buildShowModalBottomSheet(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('20 PV (Standard/Modern)', style: TextStyle(color: Colors.white)),
            onTap: () {
              setState(() => _startingLife = 20);
              _resetGame();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('40 PV (Commander)', style: TextStyle(color: Colors.white)),
            onTap: () {
              setState(() => _startingLife = 40);
              _resetGame();
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }

  void _showPlayerSelector() {
    buildShowModalBottomSheet(
      context,
      (ctx) => Wrap(
        children: [2, 3, 4, 5, 6, 7, 8].map((i) => ListTile(
          title: Text('$i Joueurs', style: const TextStyle(color: Colors.white)),
          onTap: () {
            setState(() => _playerCount = i);
            _resetGame();
            Navigator.pop(ctx);
          },
        )).toList(),
      ),
    );
  }

  void buildShowModalBottomSheet(BuildContext context, Widget Function(BuildContext) builder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewPadding.bottom),
        child: builder(ctx),
      ),
    );
  }

  void _showCommanderDamageSelector(Player attacker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.9),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
            child: Wrap(
              children: <Widget>[
                ListTile(
                  title: Text('Infliger des dégâts (Cmdt ${attacker.id + 1})', style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('Sélectionnez une cible :', style: GoogleFonts.cinzel(color: Colors.white70)),
                ),
                ..._players.where((opponent) => opponent.id != attacker.id).map((opponent) {
                  final damage = opponent.commanderDamageReceived[attacker.id] ?? 0;
                  return ListTile(
                    leading: Icon(Icons.shield, color: Color(opponent.colorValue)),
                    title: Text('Au Joueur ${opponent.id + 1}', style: const TextStyle(color: Colors.white)),
                    trailing: SizedBox(
                      width: 150,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white70),
                            onPressed: () {
                              _updateCommanderDamage(opponent.id, attacker.id, -1);
                              Navigator.pop(context);
                              _showCommanderDamageSelector(attacker);
                            },
                          ),
                          Text('$damage', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white70),
                            onPressed: () {
                              _updateCommanderDamage(opponent.id, attacker.id, 1);
                              Navigator.pop(context);
                              _showCommanderDamageSelector(attacker);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                })
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showAboutDialog() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    int tapCount = 0; 

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.yellow, size: 24),
                  const SizedBox(width: 12),
                  Text('Magic Companion', style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Le compagnon ultime pour vos parties de Magic: The Gathering.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () {
                      tapCount++;
                      if (tapCount >= 3 && tapCount < 7) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Encore ${7 - tapCount} étapes...", style: GoogleFonts.cinzel()),
                          duration: const Duration(milliseconds: 500),
                          backgroundColor: Colors.grey[800],
                        ));
                      }
                      if (tapCount == 7) {
                        Navigator.pop(context); 
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DevToolsPage()),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Version ${packageInfo.version}',
                            style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            'Build ${packageInfo.buildNumber}',
                            style: GoogleFonts.cinzel(color: Colors.white24, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer', style: GoogleFonts.cinzel(color: Colors.yellow.shade800)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _endGame() {
    // On met en pause le timer visuellement (optionnel, mais sympa)
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("Fin de partie - Qui a gagné ?", style: GoogleFonts.cinzel(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _players.map((p) {
              return ListTile(
                leading: Icon(Icons.emoji_events, color: _defaultColors[p.id]),
                title: Text("Joueur ${p.id + 1}", style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  final newItem = GameHistoryItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    date: DateTime.now(),
                    playerNames: _players.map((pl) => "Joueur ${pl.id + 1}").toList(),
                    winnerName: "Joueur ${p.id + 1}",
                    format: _startingLife == 40 ? "Commander" : "Standard",
                  );
                  await _gameHistoryService.addGame(newItem);
                  
                  _stopGame(); 
                  
                  if (mounted) {
                    Navigator.pop(context); 
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Partie enregistrée dans l'historique !"), backgroundColor: Colors.green)
                    );
                  }
                },
              );
            }).toList(),
          ),
        );
      }
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    
    // Menu central si >= 6 joueurs
    final bool useCentralMenu = _playerCount >= 2;

    return Stack(
      children: [
        _buildBlockLayout(useCentralMenu),
        
        if (!useCentralMenu) ...[
          Positioned(
            bottom: 16, 
            right: 90, 
           child: FloatingActionButton(
            heroTag: 'dice', 
            onPressed: _showDiceSelector, // Appel de la nouvelle modale
            backgroundColor: Colors.black54, 
            foregroundColor: Colors.white, 
            child: const Icon(Icons.casino_outlined)
            )
          ),
          Positioned(bottom: 16, right: 16, child: _buildSpeedDial()),
        ]
      ],
    );
  }

  // --- MOTEUR DE DISPOSITION EN BLOCS (SPLIT VIEW) ---
  Widget _buildBlockLayout(bool useCentralMenu) {
    int splitIndex = (_playerCount / 2).ceil(); 
    List<Player> topPlayers = _players.sublist(0, splitIndex);
    List<Player> bottomPlayers = _players.sublist(splitIndex, _playerCount);

    return Column(
      children: [
        Expanded(child: _buildPlayerRow(topPlayers)),
        if (useCentralMenu) _buildCentralMenuBar(),
        if (!useCentralMenu) Container(height: 2, color: Colors.black),
        Expanded(child: _buildPlayerRow(bottomPlayers)),
      ],
    );
  }

  // Génère une ligne de joueurs (qui s'adaptent en largeur)
  Widget _buildPlayerRow(List<Player> players) {
    return Row(
      children: players.map((player) {
        // NOTE: On n'a plus besoin de calculer la rotation ici
        // Elle est stockée dans player.quarterTurns et passée au widget via l'objet Player
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: PlayerZone(
              player: player,
              isCommander: _startingLife == 40,
              isHighlighted: _highlightedPlayerId == player.id,
              onLifeChanged: (val) => _updateLife(player.id, val),
              onShowCommanderDamage: () => _showCommanderDamageSelector(player),
              onColorChanged: (c) => _updatePlayerColor(player.id, c),
              onRotationChanged: (newRot) => _updatePlayerRotation(player.id, newRot), // <--- Liaison callback
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCentralMenuBar() {
    return Container(
      height: 60, color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _resetGame),
          IconButton(icon: const Icon(Icons.casino, color: Colors.white70), onPressed: _showDiceSelector), // Appel ici aussi
          IconButton(icon: const Icon(Icons.checklist_rtl_outlined, color: Colors.white70), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const TurnGuidePage())); }),          
          InkWell(
            onTap: _isGameActive ? _endGame : _pickStartingPlayer,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 50, height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: Colors.black, 
                border: Border.all(
                  color: _isGameActive ? Colors.redAccent : Colors.yellow.shade800, 
                  width: 2
                )
              ),
              child: _isGameActive 
                ? FittedBox( // S'assure que le texte rentre
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatDuration(_gameDuration), 
                      style: GoogleFonts.robotoMono( // Police Monospace pour éviter que les chiffres bougent
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      )
                    ),
                  )
                : const Icon(Icons.play_arrow, color: Colors.yellow),
            ),
          ),
          IconButton(icon: const Icon(Icons.emoji_events, color: Colors.white70), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentPage())); }),
          IconButton(icon: const Icon(Icons.people, color: Colors.white70), onPressed: _showPlayerSelector),
          IconButton(icon: const Icon(Icons.favorite, color: Colors.white70), onPressed: _showFormatSelector),
        ],
      ),
    );
  }

  Widget _buildSpeedDial() {
    return SpeedDial(
      icon: Icons.menu, activeIcon: Icons.close,
      backgroundColor: Colors.black.withOpacity(0.8), foregroundColor: Colors.white,
      overlayColor: Colors.black, overlayOpacity: 0.4, spacing: 12,
      childrenButtonSize: const Size(56.0, 56.0),
      children: [
        SpeedDialChild(child: const Icon(Icons.play_circle_fill), label: 'Qui commence ?', backgroundColor: Colors.amber.shade800, onTap: _pickStartingPlayer),
        SpeedDialChild(child: const Icon(Icons.favorite), label: 'Format', onTap: _showFormatSelector),
        SpeedDialChild(child: const Icon(Icons.people_alt), label: 'Joueurs', onTap: _showPlayerSelector),
        SpeedDialChild(child: const Icon(Icons.emoji_events), label: 'Tournoi', backgroundColor: Colors.blueAccent, onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentPage())); }),
        SpeedDialChild(child: const Icon(Icons.checklist_rtl_outlined), label: 'Phases du Tour', onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const TurnGuidePage())); }),
        SpeedDialChild(child: const Icon(Icons.refresh), label: 'Reset', onTap: _resetGame),
        SpeedDialChild(child: const Icon(Icons.flag), label: 'Finir', backgroundColor: Colors.red.shade900, onTap: _endGame),
      ],
    );
  }
}

// --- NOUVEAU WIDGET POUR L'ANIMATION DU DÉ ---

class DiceRollAnimationDialog extends StatefulWidget {
  final int sides;
  final int finalResult;
  final VoidCallback onReroll;

  const DiceRollAnimationDialog({
    super.key,
    required this.sides,
    required this.finalResult,
    required this.onReroll,
  });

  @override
  State<DiceRollAnimationDialog> createState() => _DiceRollAnimationDialogState();
}

class _DiceRollAnimationDialogState extends State<DiceRollAnimationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _spinTimer;
  int _currentSpinValue = 1;
  bool _isAnimating = true;

  @override
  void initState() {
    super.initState();
    // Durée de l'animation : 1.5 secondes
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Courbe d'animation pour un effet de ralentissement à la fin
    final CurvedAnimation curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    // Rotation : fait plusieurs tours complets (multiplié par pi * 2)
    _animation = Tween<double>(begin: 0, end: widget.sides == 2 ? pi * 10 : pi * 6).animate(curve);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _spinTimer?.cancel();
        setState(() {
          _isAnimating = false;
        });
      }
    });

    // Démarrage de l'animation
    _controller.forward();

    // Si ce n'est pas une pièce, on fait défiler des chiffres aléatoires pendant que ça tourne
    if (widget.sides > 2) {
      _spinTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
        setState(() {
          _currentSpinValue = Random().nextInt(widget.sides) + 1;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.2))),
      // On cache le titre pendant l'animation pour plus d'immersion
      title: _isAnimating ? null : Center(child: Text(_getTitle(), style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18))),
      content: SizedBox(
        height: 150,
        child: Center(
          child: _isAnimating ? _buildAnimatedView() : _buildFinalResultView(),
        ),
      ),
      actions: _isAnimating ? [] : _buildActions(), // Pas de boutons pendant l'animation
    );
  }

  // --- VUES PENDANT L'ANIMATION ---

  Widget _buildAnimatedView() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Animation Pile ou Face (Rotation sur l'axe Y - horizontal)
        if (widget.sides == 2) {
            // On détermine si on montre le côté pile ou face visuellement pendant la rotation
            // C'est juste visuel, le vrai résultat est déjà calculé.
            bool showHeads = (_animation.value / pi).floor() % 2 == 0;
             return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                ..rotateY(_animation.value),
              child: Icon(
                Icons.monetization_on, // Ou une icône différente pour pile/face si vous en avez
                size: 100, 
                color: showHeads ? Colors.amber : Colors.blueGrey.shade300
              ),
            );
        }

        // Animation des Dés (Rotation sur l'axe Z - comme une roue)
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _animation.value,
              child: Icon(_getIconForDice(widget.sides), size: 100, color: Colors.white12),
            ),
            // Le chiffre qui change rapidement par dessus
            Text(
              '$_currentSpinValue',
              style: GoogleFonts.cinzel(
                color: Colors.white.withOpacity(0.7),
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

   IconData _getIconForDice(int sides) {
    if (sides == 4) return Icons.change_history;
    if (sides == 6) return Icons.looks_6;
    if (sides == 8) return Icons.diamond;
    if (sides == 20) return Icons.casino;
    return Icons.all_out;
  }


  // --- VUE DU RÉSULTAT FINAL (Votre logique d'origine) ---

  String _getTitle() {
     if (widget.sides == 2) return "Pile ou Face";
     // Easter Egg Frodon
     if (widget.sides == 20 && widget.finalResult == 1) return 'POUR FRODON !';
     if (widget.sides == 20 && widget.finalResult == 20) return 'FUS RO DAH !!! 🐉';
     return 'Résultat D${widget.sides}';
  }

  Widget _buildFinalResultView() {
    String content = '${widget.finalResult}';
    Color contentColor = Colors.yellow.shade700;
    double fontSize = 80;

    if (widget.sides == 2) {
      content = widget.finalResult == 1 ? "FACE" : "PILE";
      contentColor = widget.finalResult == 1 ? Colors.amber : Colors.blueGrey;
      fontSize = 40;
    }

    // EASTER EGG POUR FRODON
    if (widget.sides == 20 && widget.finalResult == 1) {
      content = '${widget.finalResult} ⚔️';
      contentColor = Colors.red.shade400;
    }
    // EASTER EGG FUS RO DAH
    if (widget.sides == 20 && widget.finalResult == 20) {
      content = '${widget.finalResult} 💨';
      contentColor = Colors.cyanAccent; 
    }

    return Text(
      content,
      textAlign: TextAlign.center,
      style: GoogleFonts.cinzel(
        color: contentColor,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [BoxShadow(color: contentColor.withOpacity(0.5), blurRadius: 20)]
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: widget.onReroll,
            icon: const Icon(Icons.refresh, color: Colors.white54),
            label: Text('Relancer', style: GoogleFonts.cinzel(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
            child: Text('OK', style: GoogleFonts.cinzel(color: Colors.white)),
          ),
        ],
      ),
    ];
  }
}