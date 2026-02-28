// Fichier : lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/backup_service.dart';
import '../../providers/service_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  BackupService get _backupService => ref.read(backupServiceProvider);
  bool _isLoading = false;

  Future<void> _export() async {
    setState(() => _isLoading = true);
    try {
      await _backupService.exportData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur export: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _import() async {
    setState(() => _isLoading = true);
    try {
      final bool success = await _backupService.importData();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Données restaurées avec succès ! Redémarrez l'app pour voir les changements.", style: GoogleFonts.cinzel()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur import: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text('Paramètres', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
        : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle("Sauvegarde & Données"),
            Card(
              color: Colors.white.withValues(alpha: 0.05),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined, color: Colors.blueAccent),
                    title: const Text("Exporter mes données (JSON)", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Sauvegardez votre collection et vos decks.", style: TextStyle(color: Colors.white54)),
                    onTap: _export,
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    leading: const Icon(Icons.cloud_download_outlined, color: Colors.greenAccent),
                    title: const Text("Importer une sauvegarde", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Restaurez vos données depuis un fichier.", style: TextStyle(color: Colors.white54)),
                    onTap: _import,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle("Application"),
            Card(
              color: Colors.white.withValues(alpha: 0.05),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white70),
                title: const Text("Version", style: TextStyle(color: Colors.white)),
                trailing: const Text("1.0.0", style: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title.toUpperCase(), style: GoogleFonts.cinzel(color: Colors.yellow.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}