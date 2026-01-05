// Fichier : lib/pages/life_counter/game_history_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/game_history_model.dart';
import '../../services/game_history_service.dart';
import 'game_history_detail_page.dart';

class GameHistoryPage extends StatefulWidget {
  const GameHistoryPage({super.key});

  @override
  State<GameHistoryPage> createState() => _GameHistoryPageState();
}

class _GameHistoryPageState extends State<GameHistoryPage> {
  final GameHistoryService _service = GameHistoryService();
  List<GameHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.loadHistory();
    if (mounted) setState(() { _history = list; _isLoading = false; });
  }

  Future<void> _deleteItem(int index) async {
    setState(() {
      _history.removeAt(index);
    });
    // On réécrit l'historique complet pour valider la suppression
    await _service.clearHistory();
    for (var item in _history.reversed) {
      await _service.addGame(item);
    }
  }

  Future<void> _clearAll() async {
    await _service.clearHistory();
    _load();
    // --- EASTER EGG HARRY POTTER ---
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
              const SizedBox(width: 12),
              Text("Méfaits accomplis ⚡", style: GoogleFonts.cinzel(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 3),
        )
      );
    }
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String secondsStr = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}h ' : ''}$minutes min $secondsStr s";
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Historique des batailles", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: "Tout effacer",
              onPressed: () => showDialog(
                context: context, 
                builder: (c) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A1A),
                  title: const Text("Effacer l'historique ?", style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Non")),
                    TextButton(onPressed: (){ Navigator.pop(c); _clearAll(); }, child: const Text("Oui", style: TextStyle(color: Colors.red))),
                  ],
                )
              ),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white)) 
        : _history.isEmpty 
          ? Center(child: Text("Aucune partie enregistrée.", style: GoogleFonts.cinzel(color: Colors.white54)))
          : ListView.builder(
              itemCount: _history.length,
              padding: const EdgeInsets.all(12), // Un peu de padding autour de la liste
              itemBuilder: (context, index) {
                final game = _history[index];
                return _buildHistoryCard(game, index);
              },
            ),
    );
  }

  Widget _buildHistoryCard(GameHistoryItem game, int index) {
    return Dismissible(
      key: Key(game.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12), // Marge pour matcher la card
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(index),
      child: GestureDetector(
        // Navigation vers la page de détails au clic
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GameHistoryDetailPage(game: game))
          );
        },
        child: Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Date & Format
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy • HH:mm').format(game.date),
                      style: GoogleFonts.roboto(color: Colors.white38, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(game.durationSeconds),
                      style: GoogleFonts.roboto(color: Colors.white38, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: game.format == 'Commander' ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: game.format == 'Commander' ? Colors.amber.withOpacity(0.5) : Colors.blue.withOpacity(0.5))
                      ),
                      child: Text(game.format.toUpperCase(), style: GoogleFonts.cinzel(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Vainqueur
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.yellow, size: 20),
                    const SizedBox(width: 8),
                    Text("Vainqueur : ", style: GoogleFonts.cinzel(color: Colors.white70)),
                    Text(game.winnerName, style: GoogleFonts.cinzel(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                
                const Divider(color: Colors.white10, height: 24),
                
                // Liste des joueurs (Avatars)
                // Adapté pour utiliser 'playerStates' du nouveau modèle
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: game.playerStates.map((playerState) {
                      final name = playerState.name;
                      final image = playerState.imageUrl;
                      final isWinner = name == game.winnerName;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: isWinner ? Border.all(color: Colors.yellow, width: 2) : null,
                                boxShadow: isWinner ? [BoxShadow(color: Colors.yellow.withOpacity(0.3), blurRadius: 8)] : null,
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey.shade800,
                                backgroundImage: image != null ? NetworkImage(image) : null,
                                child: image == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white)) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(name, style: TextStyle(color: isWinner ? Colors.yellow : Colors.white70, fontSize: 10)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}