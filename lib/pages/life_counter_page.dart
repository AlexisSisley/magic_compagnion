// Fichier : lib/pages/life_counter_page.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/pages/dev_tools_page.dart';
import 'package:magic_companion/pages/turn_guide_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_model.dart';
import '../widgets/life_counter/player_zone.dart';


// --- PAGE PRINCIPALE ---
class LifeCounterPage extends StatefulWidget {
  const LifeCounterPage({super.key});

  @override
  State<LifeCounterPage> createState() => _LifeCounterPageState();
}

class _LifeCounterPageState extends State<LifeCounterPage> {
  // --- ÉTAT ---
  List<Player> _players = [];
  int _startingLife = 20;
  int _playerCount = 2;
  bool _isLoading = true;

  final List<Color> _playerColors = [
    Colors.red.shade900.withOpacity(0.7),
    Colors.blue.shade900.withOpacity(0.7),
    Colors.green.shade800.withOpacity(0.7),
    Colors.grey.shade800.withOpacity(0.7),
    Colors.purple.shade900.withOpacity(0.7),
    Colors.orange.shade900.withOpacity(0.7),
  ];

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  // --- LOGIQUE SAUVEGARDE / CHARGEMENT ---

  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerCount = prefs.getInt('playerCount') ?? 2;
      _startingLife = prefs.getInt('startingLife') ?? 20;

      _players = List.generate(
        _playerCount,
        (index) {
          final life = prefs.getInt('player_${index}_life') ?? _startingLife;
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
      
      for (final opponentId in player.commanderDamageReceived.keys) {
        final damage = player.commanderDamageReceived[opponentId]!;
        await prefs.setInt('player_${player.id}_cmd_from_$opponentId', damage);
      }
    }
  }

  // --- LOGIQUE MÉTIER ---

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
            commanderDamageReceived: cmdDamage,
          );
        },
      );
    });
    _saveGame();
  }

  void _updateLife(int playerId, int change) {
    setState(() {
      final player = _players.firstWhere((p) => p.id == playerId);
      player.life += change;
    });
    _saveGame();
  }

  void _updateCommanderDamage(int playerId, int opponentId, int change) {
    setState(() {
      final player = _players.firstWhere((p) => p.id == playerId);
      final currentDamage = player.commanderDamageReceived[opponentId] ?? 0;
      player.commanderDamageReceived[opponentId] = (currentDamage + change).clamp(0, 99);
    });
    _saveGame();
  }


  // --- MENUS ---

  void _showFormatSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.9),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom),
            child: Wrap(
              children: <Widget>[
                ListTile(
                  title: Text(
                    'Points de vie de départ',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.white70),
                  title: const Text('Standard / Classique',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('20 Points de vie',
                      style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    setState(() {
                      _startingLife = 20;
                    });
                    _resetGame();
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people, color: Colors.white70),
                  title: const Text('Commander / EDH',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('40 Points de vie',
                      style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    setState(() {
                      _startingLife = 40;
                    });
                    _resetGame();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.9),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom),
            child: Wrap(
              children: <Widget>[
                ListTile(
                  title: Text(
                    'Nombre de joueurs',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                for (int count in [2, 3, 4, 5, 6])
                  ListTile(
                    leading: Icon(
                      count == 2
                          ? Icons.person
                          : count == 3
                              ? Icons.group_add
                              : count == 4
                                  ? Icons.grid_view
                                  : Icons.people,
                      color: Colors.white70,
                    ),
                    title: Text('$count Joueurs',
                        style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() {
                        _playerCount = count;
                      });
                      _resetGame();
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom),
            child: Wrap(
              children: <Widget>[
                ListTile(
                  title: Text(
                    'Infliger des dégâts (Cmdt ${attacker.id + 1})',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    'Sélectionnez une cible :',
                    style: GoogleFonts.cinzel(color: Colors.white70),
                  ),
                ),
                ..._players
                  .where((opponent) => opponent.id != attacker.id)
                  .map((opponent) {
                    final damage = opponent.commanderDamageReceived[attacker.id] ?? 0;
                    return ListTile(
                      leading: Icon(Icons.shield, color: _playerColors[opponent.id]),
                      title: Text('Au Joueur ${opponent.id + 1}',
                          style: const TextStyle(color: Colors.white)),
                      
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
                            Text(
                              '$damage',
                              style: GoogleFonts.cinzel(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold
                              ),
                            ),
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
  // C'est la modale "À propos" avec le trigger caché
  Future<void> _showAboutDialog() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    int tapCount = 0; // Compteur local pour le secret

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder permet de mettre à jour le compteur visuellement si on veut (optionnel)
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
                  
                  // --- LE TRIGGER CACHÉ EST ICI ---
                  InkWell(
                    onTap: () {
                      tapCount++;
                      print("Debug tap: $tapCount");
                      
                      if (tapCount >= 3 && tapCount < 7) {
                        // Petit feedback visuel optionnel (Toast)
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Encore ${7 - tapCount} étapes...", style: GoogleFonts.cinzel()),
                          duration: const Duration(milliseconds: 500),
                          backgroundColor: Colors.grey[800],
                        ));
                      }
                      
                      if (tapCount == 7) {
                        Navigator.pop(context); // Ferme la modale
                        // Ouvre les DevTools
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
  // --- CONSTRUCTION DE L'UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }
    
    return Stack(
      children: [
        _buildLayout(),
        
        // --- BOUTON DÉ (Sorti du menu) ---
        Positioned(
          bottom: 16,
          right: 90, // 16 (marge) + 56 (taille FAB) + 18 (espace)
          child: FloatingActionButton(
            heroTag: 'dice_roll_fab', // Tag unique obligatoire
            onPressed: _rollDice,
            backgroundColor: Colors.black.withOpacity(0.8),
            foregroundColor: Colors.white,
            tooltip: 'Lancer un D20',
            child: const Icon(Icons.casino_outlined),
          ),
        ),

        // --- MENU SPEED DIAL ---
        Positioned(
          bottom: 16,
          right: 16,
          child: SpeedDial(
            icon: Icons.menu,
            activeIcon: Icons.close,
            backgroundColor: Colors.black.withOpacity(0.8),
            foregroundColor: Colors.white,
            overlayColor: Colors.black,
            overlayOpacity: 0.4,
            spacing: 12,
            childrenButtonSize: const Size(56.0, 56.0),
            
            children: [
              SpeedDialChild(
                child: const Icon(Icons.favorite),
                label: 'Format',
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                onTap: _showFormatSelector,
              ),
              SpeedDialChild(
                child: const Icon(Icons.people_alt),
                label: 'Joueurs',
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                onTap: _showPlayerSelector,
              ),
              // Note : Le jet de dé a été déplacé en dehors
              SpeedDialChild(
                child: const Icon(Icons.checklist_rtl_outlined),
                label: 'Phases du Tour',
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TurnGuidePage()),
                  );
                },
              ),
              SpeedDialChild(
                child: const Icon(Icons.refresh),
                label: 'Reset',
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                onTap: _resetGame,
              ),
              SpeedDialChild(
                child: const Icon(Icons.info_outline),
                label: 'Infos', // Discret
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                onTap: _showAboutDialog, // Lance la modale avec le secret
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        
        if (_playerCount <= 3) {
          return Column(
            children: _players.map((player) {
              bool isRotated = player.id == 0;
              return Expanded(
                child: PlayerZone(
                  player: player,
                  backgroundColor: _playerColors[player.id],
                  isRotated: isRotated,
                  isCommander: _startingLife == 40,
                  isVertical: false, 
                  onLifeChanged: (change) => _updateLife(player.id, change),
                  onShowCommanderDamage: () => _showCommanderDamageSelector(player),
                ),
              );
            }).toList(),
          );
        }
        
        else {
          final rowCount = (_playerCount / 2).ceil();
          
          final cellHeight = constraints.maxHeight / rowCount;
          final cellWidth = constraints.maxWidth / 2;
          
          final aspectRatio = (cellHeight > 0) ? cellWidth / cellHeight : 1.0;

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _playerCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: aspectRatio,
            ),
            itemBuilder: (context, index) {
              final player = _players[index];
              bool isRotated = index < 2; 

              return PlayerZone(
                player: player,
                backgroundColor: _playerColors[player.id],
                isRotated: isRotated,
                isCommander: _startingLife == 40,
                isVertical: true,
                onLifeChanged: (change) => _updateLife(player.id, change),
                onShowCommanderDamage: () => _showCommanderDamageSelector(player),
              );
            },
          );
        }
      },
    );
  }
}