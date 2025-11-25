import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/game_history_model.dart';
import '../../services/game_history_service.dart';

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
    if(mounted) setState(() { _history = list; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Historique des parties", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
               await _service.clearHistory();
               _load();
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _history.isEmpty 
          ? Center(child: Text("Aucune partie enregistrée.", style: GoogleFonts.cinzel(color: Colors.white54)))
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final game = _history[index];
                return Card(
                  color: Colors.white.withOpacity(0.05),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events, color: Colors.yellow),
                    title: Text("Vainqueur : ${game.winnerName}", style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "${game.format} • ${DateFormat('dd/MM/yyyy HH:mm').format(game.date)}\n${game.playerNames.length} Joueurs",
                      style: const TextStyle(color: Colors.white54, fontSize: 12)
                    ),
                  ),
                );
              },
            ),
    );
  }
}