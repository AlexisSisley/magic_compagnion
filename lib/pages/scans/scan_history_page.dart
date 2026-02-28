// Fichier : lib/pages/scan_history_page.dart
// NOUVEAU FICHIER

import 'dart:io'; // Pour afficher l'image depuis le chemin (File)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/scan_history_model.dart';
import '../../services/scan_history_service.dart';
import '../../services/collection_service.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import 'package:intl/intl.dart';

class ScanHistoryPage extends ConsumerStatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  ConsumerState<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends ConsumerState<ScanHistoryPage> {
  ScanHistoryService get _historyService => ref.read(scanHistoryServiceProvider);
  CollectionService get _collectionService => ref.read(collectionServiceProvider);
  
  List<ScanHistoryItem> _history = [];
  bool _isLoading = true;

  // Formatteur de date (ex: "12 nov. 2025, 14:30")
  final DateFormat _dateFormatter = DateFormat('d MMM y, HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _isLoading = true; });
    final history = await _historyService.loadHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Vider l\'historique ?', style: GoogleFonts.cinzel(color: Colors.white)),
        content: Text(
          'Tous les scans de votre historique seront supprimés.',
          style: GoogleFonts.cinzel(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.cinzel(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Vider', style: GoogleFonts.cinzel(color: Colors.red.shade300)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _historyService.clearHistory();
      _loadHistory(); // Recharge la liste (qui sera vide)
    }
  }

  void _addToCollection(ScanHistoryItem item) {
    _collectionService.upsertCardInCollection(
      scryfallId: item.scryfallId,
      cardName: item.cardName,
      quantityToAdd: 1,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${item.cardName}" ajouté à la collection',
          style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.green.shade700,
      duration: const Duration(seconds: 1),
    ));
  }

  void _viewCardDetail(ScanHistoryItem item) {
    context.push(AppRoutes.cardDetail, extra: {'cardName': item.cardName});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(
          'Historique des Scans',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Vider l\'historique',
            onPressed: (_history.isEmpty || _isLoading) ? null : _clearHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _history.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Votre historique de scan est vide.',
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        
        // Tente de charger l'image prise par l'utilisateur
        Widget leadingImage;
        if (item.imagePath != null) {
          leadingImage = Image.file(
            File(item.imagePath!),
            width: 50,
            height: 70,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Si l'image n'existe plus (ex: cache vidé), affiche une icône
              return const Icon(Icons.broken_image, color: Colors.white30);
            },
          );
        } else {
          leadingImage = const Icon(Icons.image_not_supported, color: Colors.white30);
        }

        return Card(
          color: Colors.black.withAlpha(102),
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: Colors.yellow.shade800.withAlpha(153),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Container(
                width: 50,
                height: 70,
                color: Colors.grey.shade800,
                child: leadingImage,
              ),
            ),
            title: Text(
              item.cardName,
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _dateFormatter.format(item.timestamp), // Affiche la date
              style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
              tooltip: 'Ajouter à la collection',
              onPressed: () => _addToCollection(item),
            ),
            onTap: () => _viewCardDetail(item),
          ),
        );
      },
    );
  }
}