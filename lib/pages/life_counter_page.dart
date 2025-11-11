// Fichier : lib/pages/life_counter_page.dart
// VERSION FINALE (Avec Compteur Commander)

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // --- LOGIQUE SAUVEGARDE / CHARGEMENT (MISE À JOUR) ---

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
          
          // On ne charge les dégâts de Cdt que si on est en mode Commander
          if (_startingLife == 40) {
            for (int i = 0; i < _playerCount; i++) {
              if (i == index) continue; // Pas de dégâts de soi-même
              // Charge les dégâts de Cdt de l'adversaire 'i'
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
      
      // Sauvegarder les dégâts de Cdt
      for (final opponentId in player.commanderDamageReceived.keys) {
        final damage = player.commanderDamageReceived[opponentId]!;
        await prefs.setInt('player_${player.id}_cmd_from_$opponentId', damage);
      }
    }
  }

  // --- LOGIQUE MÉTIER (MISE À JOUR) ---

  void _resetGame() {
    setState(() {
      _players = List.generate(
        _playerCount,
        (index) {
          Map<int, int> cmdDamage = {};
          // On n'initialise les dégâts de Cdt que si on est en mode Commander
          if (_startingLife == 40) {
            for (int i = 0; i < _playerCount; i++) {
              if (i == index) continue;
              cmdDamage[i] = 0; // 0 dégâts de Cdt de l'adversaire 'i'
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

  // NOUVEAU: Mettre à jour les dégâts de Commandant
  void _updateCommanderDamage(int playerId, int opponentId, int change) {
    setState(() {
      final player = _players.firstWhere((p) => p.id == playerId);
      // Met à jour les dégâts pour cet adversaire spécifique
      final currentDamage = player.commanderDamageReceived[opponentId] ?? 0;
      player.commanderDamageReceived[opponentId] = (currentDamage + change).clamp(0, 99); // Bloque à 0 min
    });
    _saveGame();
  }


  // --- MENUS (Mis à jour) ---

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

  // NOUVEAU: Menu pour choisir les dégâts de Cdt
  void _showCommanderDamageSelector(Player player) {
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
                    'Dégâts de Commandant (Joueur ${player.id + 1})',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    'Total reçus : ${player.totalCommanderDamage}',
                    style: GoogleFonts.cinzel(color: Colors.white70),
                  ),
                ),
                // Lister tous les adversaires
                ..._players
                  .where((opponent) => opponent.id != player.id)
                  .map((opponent) {
                    final damage = player.commanderDamageReceived[opponent.id] ?? 0;
                    return ListTile(
                      leading: Icon(Icons.shield, color: _playerColors[opponent.id]),
                      title: Text('Du Joueur ${opponent.id + 1}',
                          style: const TextStyle(color: Colors.white)),
                      // Affiche les dégâts actuels de cet adversaire
                      trailing: SizedBox(
                        width: 150, // Largeur fixe
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white70),
                              onPressed: () {
                                _updateCommanderDamage(player.id, opponent.id, -1);
                                // On reconstruit le BottomSheet pour rafraîchir
                                Navigator.pop(context);
                                _showCommanderDamageSelector(player);
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
                                _updateCommanderDamage(player.id, opponent.id, 1);
                                Navigator.pop(context);
                                _showCommanderDamageSelector(player);
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
    
    // --- Logique de l'Easter Egg ---
    String title = 'Jet de D20';
    String content = '$result';
    Color contentColor = Colors.yellow.shade700;

    if (result == 1) {
      title = 'POUR FRODON !';
      content = '$result ⚔️'; // Une petite épée
      contentColor = Colors.red.shade400;
    }
    // ---

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: GoogleFonts.cinzel(color: Colors.white)), // Utilise le titre variable
        content: Text(
          content, // Utilise le contenu variable
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            color: contentColor, // Utilise la couleur variable
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
        
        Positioned(
          bottom: 16,
          right: 16,
          child: SpeedDial(
            icon: Icons.menu, // Icône principale
            activeIcon: Icons.close, // Icône quand le menu est ouvert
            backgroundColor: Colors.black.withOpacity(0.8),
            foregroundColor: Colors.white,
            overlayColor: Colors.black, // Couleur du fond estompé
            overlayOpacity: 0.4,
            spacing: 12, // Espace entre les boutons
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
              SpeedDialChild(
                child: const Icon(Icons.casino_outlined),
                label: 'Jet de Dé',
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                onTap: _rollDice,
              ),
              SpeedDialChild(
                child: const Icon(Icons.refresh),
                label: 'Reset',
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                onTap: _resetGame,
              ),
            ],
          ),
        ),
        // --- Fin de la correction ---
      ],
    );
  }

  // NOUVELLE Fonction pour construire le layout (MISE À JOUR)
  Widget _buildLayout() {
    // 1-3 joueurs : Colonne (inchangée, sauf la callback)
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
              onLifeChanged: (change) => _updateLife(player.id, change), // <-- MODIFIÉ
              onShowCommanderDamage: () => _showCommanderDamageSelector(player),
            ),
          );
        }).toList(),
      );
    }
    
    // 4-6 joueurs : Grille (MODIFIÉE)
    else {
      // --- CORRECTION DU LAYOUT ---
      final mediaQuery = MediaQuery.of(context);
      // Hauteur réelle de l'écran (sans encoche/barre de statut)
      final safeHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom;
      final screenWidth = mediaQuery.size.width;
      
      // Calcule le nombre de rangées
      final rowCount = (_playerCount / 2).ceil(); // 4->2, 5->3, 6->3
      
      // Calcule la hauteur d'une cellule (en enlevant la barre de nav ~80px)
      // (kBottomNavigationBarHeight est ~56, mais 80 donne de la marge)
      final cellHeight = (safeHeight - 80) / rowCount; 
      final cellWidth = screenWidth / 2;
      
      // Calcule le ratio dynamique
      final aspectRatio = (cellHeight > 0) ? cellWidth / cellHeight : 1.0;
      // ---

      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _playerCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: aspectRatio, // <-- MODIFIÉ
        ),
        itemBuilder: (context, index) {
          final player = _players[index];
          bool isRotated = index < 2; // Seuls les 2 joueurs du haut sont tournés

          return PlayerZone(
            player: player,
            backgroundColor: _playerColors[player.id],
            isRotated: isRotated,
            isCommander: _startingLife == 40,
            onLifeChanged: (change) => _updateLife(player.id, change), // <-- MODIFIÉ
            onShowCommanderDamage: () => _showCommanderDamageSelector(player),
          );
        },
      );
    }
  }
}