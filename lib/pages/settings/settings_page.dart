// Fichier : lib/pages/settings_page.dart
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export: $e')));
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
            content: Text("Données restaurées avec succès ! Redémarrez l'app pour voir les changements.", style: AppTextStyles.cinzel()),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur import: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Paramètres', style: AppTextStyles.bold()),
        backgroundColor: AppColors.textOnPrimary,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Sauvegarde & Données'),
            Card(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.accent),
                    title: const Text('Exporter mes données (JSON)', style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: const Text('Sauvegardez votre collection et vos decks.', style: TextStyle(color: AppColors.textMuted)),
                    onTap: _export,
                  ),
                  const Divider(color: AppColors.borderLight),
                  ListTile(
                    leading: const Icon(Icons.cloud_download_outlined, color: AppColors.accentGreen),
                    title: const Text('Importer une sauvegarde', style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: const Text('Restaurez vos données depuis un fichier.', style: TextStyle(color: AppColors.textMuted)),
                    onTap: _import,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Application'),
            Card(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              child: const ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.textSecondary),
                title: Text('Version', style: TextStyle(color: AppColors.textPrimary)),
                trailing: Text('1.0.0', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title.toUpperCase(), style: AppTextStyles.bold(color: AppColors.primaryShade800, fontSize: 12)),
    );
  }
}
