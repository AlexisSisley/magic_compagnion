// Fichier : lib/pages/life_counter/game_history_detail_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/game_history_model.dart';

class GameHistoryDetailPage extends StatelessWidget {
  final GameHistoryItem game;

  const GameHistoryDetailPage({super.key, required this.game});

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String secondsStr = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}h ' : ''}$minutes min $secondsStr s";
  }

  String _getWinMethodLabel() {
    switch (game.winMethod) {
      case 'commander': return "☠️ Dégâts de Commandant";
      case 'poison': return "🧪 Poison";
      case 'concede': return "🏳️ Adversaires ont concédé";
      default: return "⚔️ Victoire Normale (PV)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Rapport de Bataille", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- HEADER ---
            Card(
              color: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, size: 48, color: Colors.yellow),
                    const SizedBox(height: 16),
                    Text("VAINQUEUR", style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(game.winnerName, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24)
                      ),
                      child: Text(_getWinMethodLabel(), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(Icons.calendar_today, "Date", DateFormat('dd/MM/yy').format(game.date)),
                        _buildStatColumn(Icons.timer, "Durée", _formatDuration(game.durationSeconds)),
                        _buildStatColumn(Icons.people, "Joueurs", "${game.playerStates.length}"),
                      ],
                    )
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            Text("État final des joueurs", style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // --- LISTE JOUEURS ---
            ...game.playerStates.map((p) {
              final bool isWinner = p.name == game.winnerName;
              return Card(
                color: isWinner ? Colors.green.withOpacity(0.1) : Colors.black45,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isWinner ? const BorderSide(color: Colors.green, width: 1) : BorderSide.none
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundImage: p.imageUrl != null ? NetworkImage(p.imageUrl!) : null,
                    backgroundColor: Colors.grey.shade800,
                    child: p.imageUrl == null ? Text(p.name[0]) : null,
                  ),
                  title: Text(p.name, style: GoogleFonts.cinzel(color: isWinner ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.poison > 0) ...[
                        const Icon(Icons.science, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text("${p.poison}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                      ],
                      if (p.commanderDamageTaken > 0) ...[
                        const Icon(Icons.shield, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text("${p.commanderDamageTaken}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text("${p.life}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10)),
      ],
    );
  }
}