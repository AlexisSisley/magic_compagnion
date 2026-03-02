// Fichier : lib/pages/life_counter/game_history_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/game_history_model.dart';
import '../../services/game_history_service.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';

class GameHistoryPage extends ConsumerStatefulWidget {
  const GameHistoryPage({super.key});

  @override
  ConsumerState<GameHistoryPage> createState() => _GameHistoryPageState();
}

class _GameHistoryPageState extends ConsumerState<GameHistoryPage> {
  GameHistoryService get _service => ref.read(gameHistoryServiceProvider);
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
              const Icon(Icons.auto_awesome, color: AppColors.accentPurple),
              const SizedBox(width: 12),
              Text('Méfaits accomplis ⚡', style: AppTextStyles.bold(color: AppColors.accentPurple)),
            ],
          ),
          backgroundColor: AppColors.textOnPrimary,
          duration: const Duration(seconds: 3),
        )
      );
    }
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String secondsStr = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}h ' : ''}$minutes min $secondsStr s";
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Historique des batailles', style: AppTextStyles.bold()),
        backgroundColor: AppColors.textOnPrimary,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: AppColors.accentRed),
              tooltip: 'Tout effacer',
              onPressed: () => showDialog(
                context: context, 
                builder: (c) => AlertDialog(
                  backgroundColor: AppColors.scaffoldBackground,
                  title: const Text("Effacer l'historique ?", style: TextStyle(color: AppColors.textPrimary)),
                  actions: [
                    TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Non')),
                    TextButton(onPressed: (){ Navigator.pop(c); _clearAll(); }, child: const Text('Oui', style: TextStyle(color: AppColors.error))),
                  ],
                )
              ),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary)) 
        : _history.isEmpty 
          ? Center(child: Text('Aucune partie enregistrée.', style: AppTextStyles.cinzel(color: AppColors.textMuted)))
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
        child: const Icon(Icons.delete, color: AppColors.textPrimary),
      ),
      onDismissed: (_) => _deleteItem(index),
      child: GestureDetector(
        // Navigation vers la page de détails au clic
        onTap: () {
          context.push(AppRoutes.gameHistoryDetail, extra: game);
        },
        child: Card(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.1)),
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
                      style: GoogleFonts.roboto(color: AppColors.borderFaint, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(game.durationSeconds),
                      style: GoogleFonts.roboto(color: AppColors.borderFaint, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: game.format == 'Commander' ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: game.format == 'Commander' ? Colors.amber.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.5))
                      ),
                      child: Text(game.format.toUpperCase(), style: AppTextStyles.bold(color: AppColors.textSecondary, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Vainqueur
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Vainqueur : ', style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                    Text(game.winnerName, style: AppTextStyles.bold(color: AppColors.primary, fontSize: 16)),
                  ],
                ),
                
                const Divider(color: AppColors.borderLight, height: 24),
                
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
                                border: isWinner ? Border.all(color: AppColors.primary, width: 2) : null,
                                boxShadow: isWinner ? [BoxShadow(color: Colors.yellow.withValues(alpha: 0.3), blurRadius: 8)] : null,
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.greyShade800,
                                backgroundImage: image != null ? NetworkImage(image) : null,
                                child: image == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.textPrimary)) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(name, style: TextStyle(color: isWinner ? AppColors.primary : AppColors.textSecondary, fontSize: 10)),
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
