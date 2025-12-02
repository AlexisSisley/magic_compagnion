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
  int _startingLife = 20;
  int _playerCount = 2;
  bool _isLoading = true;
  
  int? _highlightedPlayerId;
  bool _isSelectingStarter = false;

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

  // --- SAUVEGARDE & CHARGEMENT ---
  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerCount = prefs.getInt('playerCount') ?? 2;
      _startingLife = prefs.getInt('startingLife') ?? 20;

      _players = List.generate(
        _playerCount,
        (index) {
          final life = prefs.getInt('player_${index}_life') ?? _startingLife;
          final colorVal = prefs.getInt('player_${index}_color') ?? _defaultColors[index % _defaultColors.length].value;
          
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
      for (final opponentId in player.commanderDamageReceived.keys) {
        final damage = player.commanderDamageReceived[opponentId]!;
        await prefs.setInt('player_${player.id}_cmd_from_$opponentId', damage);
      }
    }
  }

  // --- LOGIQUE JEU ---
  void _resetGame() {
    setState(() {
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
            // Reset couleur par défaut
            colorValue: _defaultColors[index % _defaultColors.length].value,
            commanderDamageReceived: cmdDamage,
          );
        },
      );
    });
    _saveGame();
  }

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
          actions: [ElevatedButton(onPressed: () { Navigator.pop(context); setState(() { _highlightedPlayerId = null; _isSelectingStarter = false; }); }, style: ElevatedButton.styleFrom(backgroundColor: Color(_players[winnerId].colorValue)), child: const Text("C'est parti !", style: TextStyle(color: Colors.white)))]
        ),
      );
    }
  }

  void _rollDice() {
    final int result = Random().nextInt(20) + 1; // Un D20
    
    String title = 'Jet de D20';
    String content = '$result';
    Color contentColor = Colors.yellow.shade700;

    if (result == 1) {
      title = 'POUR FRODON !';
      content = '$result ⚔️';
      contentColor = Colors.red.shade400;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: GoogleFonts.cinzel(color: Colors.white)),
        content: Text(
          content,
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            color: contentColor,
            fontSize: 80,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.cinzel(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- SYSTÈME DE DÉS (D4, D6, D8, D10, D12, D20, D100) ---
  
  void _showDiceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Lancer un dé", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [4, 6, 8, 10, 12, 20, 100].map((sides) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.yellow.shade800)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _rollSpecificDice(sides);
                    },
                    child: Text("D$sides", style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              )
            ],
          ),
        );
      }
    );
  }

  void _rollSpecificDice(int sides) {
    final int result = Random().nextInt(sides) + 1;
    
    String title = 'Résultat D$sides';
    String content = '$result';
    Color contentColor = Colors.yellow.shade700;

    // EASTER EGG POUR FRODON (Uniquement sur le D20)
    if (sides == 20 && result == 1) {
      title = 'POUR FRODON !';
      content = '$result ⚔️';
      contentColor = Colors.red.shade400;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: GoogleFonts.cinzel(color: Colors.white)),
        content: Text(
          content,
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            color: contentColor,
            fontSize: 80,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.cinzel(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rollSpecificDice(sides); // Relancer le même dé
            },
            child: Text('Relancer', style: GoogleFonts.cinzel(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showFormatSelector() {
    buildShowModalBottomSheet(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('20 PV', style: TextStyle(color: Colors.white)),
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
                  
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Partie enregistrée dans l'historique !"), backgroundColor: Colors.green)
                  );
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
            onPressed: _showDiceSelector, 
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

    // On supprime le RotatedBox global ici pour avoir un contrôle fin par joueur
    return Column(
      children: [
        Expanded(child: _buildPlayerRow(topPlayers, isTopRow: true)),
        
        if (useCentralMenu) _buildCentralMenuBar(),
        if (!useCentralMenu) Container(height: 2, color: Colors.black),

        Expanded(child: _buildPlayerRow(bottomPlayers, isTopRow: false)),
      ],
    );
  }

  // Génère une ligne de joueurs (qui s'adaptent en largeur)
  Widget _buildPlayerRow(List<Player> players, {required bool isTopRow}) {
    return Row(
      children: players.map((player) {
        // --- LOGIQUE DE ROTATION ---
        int quarterTurns = 0;

        if (_playerCount == 4) {
          // Logique spécifique 4 joueurs (regarde vers le centre)
          // 0, 1 (Top) | 2, 3 (Bottom)
          // Gauche (0, 2) : 1 (90° Horaire)
          // Droite (1, 3) : 3 (270° / 90° Anti-horaire)
          bool isLeft = (player.id % 2 == 0);
          quarterTurns = isLeft ? 1 : 3;
        } else {
          // Logique Standard (Haut inversé, Bas normal)
          quarterTurns = isTopRow ? 2 : 0;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: PlayerZone(
              player: player,
              quarterTurns: quarterTurns, // On passe la rotation calculée
              isCommander: _startingLife == 40,
              isHighlighted: _highlightedPlayerId == player.id,
              onLifeChanged: (val) => _updateLife(player.id, val),
              onShowCommanderDamage: () => _showCommanderDamageSelector(player),
              onColorChanged: (c) => _updatePlayerColor(player.id, c),
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
          IconButton(icon: const Icon(Icons.casino, color: Colors.white70), onPressed: _rollDice),
          IconButton(icon: const Icon(Icons.checklist_rtl_outlined, color: Colors.white70), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const TurnGuidePage())); }),          
          Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: Colors.yellow.shade800, width: 2)), child: IconButton(icon: const Icon(Icons.play_arrow, color: Colors.yellow), onPressed: _pickStartingPlayer)),
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