// Fichier : lib/pages/settings_page.dart
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/backup_service.dart';
import '../../services/bulk_data_service.dart';
import '../../providers/service_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  BackupService get _backupService => ref.read(backupServiceProvider);
  BulkDataService get _bulkDataService => ref.read(bulkDataServiceProvider);
  bool _isLoading = false;

  // Bulk data state
  bool _isBulkChecking = false;
  bool? _bulkUpdateAvailable; // null = not checked, true/false = result
  bool _isBulkDownloading = false;
  double _bulkDownloadProgress = 0.0;

  Future<void> _checkBulkUpdate() async {
    setState(() { _isBulkChecking = true; _bulkUpdateAvailable = null; });
    try {
      final available = await _bulkDataService.isUpdateAvailable();
      if (mounted) setState(() { _bulkUpdateAvailable = available; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vérification : $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isBulkChecking = false);
    }
  }

  Future<void> _downloadBulkData() async {
    setState(() { _isBulkDownloading = true; _bulkDownloadProgress = 0.0; });
    try {
      final path = await _bulkDataService.downloadOracleCards(
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _bulkDownloadProgress = received / total);
          }
        },
      );
      if (mounted) {
        setState(() { _isBulkDownloading = false; _bulkUpdateAvailable = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path != null ? 'Base de cartes mise à jour avec succès !' : 'Échec du téléchargement.',
              style: AppTextStyles.cinzel(),
            ),
            backgroundColor: path != null ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBulkDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur téléchargement : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

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
            _buildSectionTitle('Mise à jour des données'),
            Card(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync, color: AppColors.primary),
                    title: const Text('Mise à jour base de cartes', style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: _buildBulkSubtitle(),
                    trailing: _buildBulkTrailing(),
                    onTap: (_isBulkChecking || _isBulkDownloading) ? null : _checkBulkUpdate,
                  ),
                  if (_bulkUpdateAvailable == true && !_isBulkDownloading)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Télécharger la mise à jour'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade800),
                          onPressed: _downloadBulkData,
                        ),
                      ),
                    ),
                  if (_isBulkDownloading)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _bulkDownloadProgress > 0 ? _bulkDownloadProgress : null,
                            color: AppColors.primary,
                            backgroundColor: AppColors.borderLight,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_bulkDownloadProgress * 100).toStringAsFixed(0)} %',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
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

  Widget _buildBulkSubtitle() {
    if (_isBulkChecking) {
      return const Text('Vérification en cours...', style: TextStyle(color: AppColors.textMuted));
    }
    if (_isBulkDownloading) {
      return const Text('Téléchargement en cours...', style: TextStyle(color: AppColors.textMuted));
    }
    if (_bulkUpdateAvailable == true) {
      return const Text('Une mise à jour est disponible.', style: TextStyle(color: AppColors.accentGreen));
    }
    if (_bulkUpdateAvailable == false) {
      return const Text('Base de cartes à jour.', style: TextStyle(color: AppColors.textMuted));
    }
    return const Text('Appuyez pour vérifier les mises à jour.', style: TextStyle(color: AppColors.textMuted));
  }

  Widget _buildBulkTrailing() {
    if (_isBulkChecking) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    if (_isBulkDownloading) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    if (_bulkUpdateAvailable == false) {
      return const Icon(Icons.check_circle, color: AppColors.accentGreen);
    }
    if (_bulkUpdateAvailable == true) {
      return const Icon(Icons.update, color: AppColors.primary);
    }
    return const Icon(Icons.chevron_right, color: AppColors.textMuted);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title.toUpperCase(), style: AppTextStyles.bold(color: AppColors.primaryShade800, fontSize: 12)),
    );
  }
}
