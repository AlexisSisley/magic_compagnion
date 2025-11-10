// Fichier : lib/pages/life_counter_page.dart
// VERSION FINALE (Avec Compteur Commander)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- MODÈLE MIS À JOUR ---
class Player {
  final int id;
  int life;
  // NOUVEAU: Stocke les dégâts reçus, ex: { 1: 5, 2: 10 }
  // (signifie 5 dégâts du Cdt du Joueur 1, 10 du Cdt du Joueur 2)
  Map<int, int> commanderDamageReceived;

  Player({
    required this.id,
    required this.life,
    required this.commanderDamageReceived,
  });

  // NOUVEAU: Calcule le total des dégâts de Cdt reçus
  int get totalCommanderDamage {
    return commanderDamageReceived.values.fold(0, (sum, damage) => sum + damage);
  }
}

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
        Align(
          alignment: Alignment.center,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
              shape: const CircleBorder(),
            ),
            onPressed: _resetGame,
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'fab_players',
                onPressed: _showPlayerSelector,
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                child: const Icon(Icons.people_alt),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'fab_format',
                onPressed: _showFormatSelector,
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.white,
                child: const Icon(Icons.favorite),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // NOUVELLE Fonction pour construire le layout (MISE À JOUR)
  Widget _buildLayout() {
    // Si on a 2 ou 3 joueurs, on garde une Colonne (1v1, 1v1v1)
    if (_playerCount <= 3) {
      return Column(
        children: _players.map((player) {
          bool isRotated = player.id == 0;
          return Expanded(
            child: PlayerZone(
              player: player, // <-- MODIFIÉ: Passe l'objet Player
              backgroundColor: _playerColors[player.id],
              isRotated: isRotated,
              isCommander: _startingLife == 40, // <-- NOUVEAU
              onDecrement: () => _updateLife(player.id, -1),
              onIncrement: () => _updateLife(player.id, 1),
              onShowCommanderDamage: () => _showCommanderDamageSelector(player), // <-- NOUVEAU
            ),
          );
        }).toList(),
      );
    }
    
    // Si on a 4, 5, ou 6 joueurs, on utilise une Grille (2x2, 2x3)
    else {
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _playerCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.4,
        ),
        itemBuilder: (context, index) {
          final player = _players[index];
          bool isRotated = index < 2;

          return PlayerZone(
            player: player, // <-- MODIFIÉ: Passe l'objet Player
            backgroundColor: _playerColors[player.id],
            isRotated: isRotated,
            isCommander: _startingLife == 40, // <-- NOUVEAU
            onDecrement: () => _updateLife(player.id, -1),
            onIncrement: () => _updateLife(player.id, 1),
            onShowCommanderDamage: () => _showCommanderDamageSelector(player), // <-- NOUVEAU
          );
        },
      );
    }
  }
}

// --- WIDGET ZONE JOUEUR (FORTEMENT MODIFIÉ) ---
class PlayerZone extends StatelessWidget {
  const PlayerZone({
    super.key,
    required this.player, // <-- MODIFIÉ
    required this.backgroundColor,
    required this.onDecrement,
    required this.onIncrement,
    required this.onShowCommanderDamage, // <-- NOUVEAU
    this.isRotated = false,
    this.isCommander = false, // <-- NOUVEAU
  });

  final Player player; // <-- MODIFIÉ
  final Color backgroundColor;
  final bool isRotated;
  final bool isCommander; // <-- NOUVEAU
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onShowCommanderDamage; // <-- NOUVEAU

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      children: [
        Container(color: backgroundColor),
        // --- Bouton Moins (inchangé) ---
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 120,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(Icons.remove, size: 60, color: Colors.white70),
            ),
          ),
        ),
        // --- Bouton Plus (inchangé) ---
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 120,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(Icons.add, size: 60, color: Colors.white70),
            ),
          ),
        ),
        // --- Affichage Principal (Vie) ---
        Center(
          child: Text(
            '${player.life}',
            style: GoogleFonts.cinzel(
              fontSize: 104,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(2.0, 2.0),
                ),
              ],
            ),
          ),
        ),

        // --- NOUVEAU: Affichage et bouton des dégâts de Cdt ---
        if (isCommander)
          Positioned(
            // Position en haut (ou en bas si tourné)
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onShowCommanderDamage, // Ouvre le menu
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    // Affiche le total des dégâts de Cdt
                    'CDT : ${player.totalCommanderDamage}',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (isRotated) {
      return Transform.rotate(
        angle: 3.14159, // 180 degrés
        child: content,
      );
    }
    return content;
  }
}