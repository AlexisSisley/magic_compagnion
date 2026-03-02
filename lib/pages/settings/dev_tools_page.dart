// Fichier : lib/pages/dev_tools_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class DevToolsPage extends StatefulWidget {
  const DevToolsPage({super.key});

  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage> {
  Map<String, String> _deviceData = {};

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _deviceData = {
        'App Name': info.appName,
        'Package Name': info.packageName,
        'Version': info.version,
        'Build Number': info.buildNumber,
        'Platform': Platform.operatingSystem,
        'Dart Version': Platform.version,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010), // Fond très sombre style "Terminal"
      appBar: AppBar(
        title: Text('🛠️ DevTools', style: AppTextStyles.bold()),
        backgroundColor: Colors.red.shade900, // Couleur d'avertissement
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Informations Build'),
          ..._deviceData.entries.map((e) => _buildInfoTile(e.key, e.value)),
          
          const Divider(color: AppColors.borderMedium, height: 32),
          
          _buildSectionTitle('Actions Debug'),
          _buildActionTile(
            icon: Icons.delete_forever,
            color: AppColors.error,
            title: 'Vider le cache image',
            onTap: () {
              PaintingBinding.instance.imageCache.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache vidé !')));
            },
          ),
          _buildActionTile(
            icon: Icons.bug_report,
            color: AppColors.warning,
            title: 'Test Crash (Non fonctionnel)',
            onTap: () {
              // throw Exception("Test Crash !"); // Décommente pour tester Crashlytics plus tard
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.bold(color: AppColors.synergyNeutral, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoTile(String key, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      color: AppColors.textPrimary.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: AppTextStyles.label(color: AppColors.textSecondary)),
          SelectableText(value, style: AppTextStyles.cinzel(color: AppColors.accentGreen, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: AppTextStyles.cinzel()),
      tileColor: AppColors.textPrimary.withValues(alpha: 0.05),
      onTap: onTap,
    );
  }
}
