// Fichier : lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Imports des pages
import 'package:magic_companion/pages/cards/card_search_page.dart';
import 'package:magic_companion/pages/collections/collection_page.dart';
import 'package:magic_companion/pages/oracle/magic_oracle_page.dart';
import 'package:magic_companion/pages/scans/scanner_page.dart';
import 'package:magic_companion/pages/tools/hypergeometric_page.dart';
import 'package:magic_companion/pages/tournaments/tournament_page.dart';
import 'pages/life_counter/life_counter_page.dart';
import 'pages/glossary/glossary_page.dart';
import 'pages/decks/deck_list_page.dart';
import 'pages/settings/settings_page.dart';
import 'firebase_options.dart';

// Imports Services
import 'services/backup_service.dart';
import 'services/google_drive_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('fr_FR');
  runApp(const MagicCompanionApp());
}

class MagicCompanionApp extends StatelessWidget {
  const MagicCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Magic Companion',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          selectedItemColor: Colors.yellow.shade800,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0; 
  final GoogleDriveService _driveService = GoogleDriveService();
  final BackupService _backupService = BackupService();

  static const List<Widget> _pages = <Widget>[
    LifeCounterPage(),
    ScannerPage(),
    CardSearchPage(),
    DeckListPage(),
    CollectionPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDriveBackupOnStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Sauvegarde auto quand l'app passe en pause
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _performAutoBackup();
    }
  }

  Future<void> _performAutoBackup() async {
    if (_driveService.isSignedIn) {
      print("Début sauvegarde automatique Drive...");
      final jsonString = await _backupService.generateBackupJson();
      await _driveService.uploadBackup(jsonString);
    }
  }

  Future<void> _checkDriveBackupOnStart() async {
    // Connexion silencieuse au démarrage
    final signedIn = await _driveService.signIn(silent: true);
    
    if (signedIn) {
      final backupFile = await _driveService.findBackupFile();
      
      if (backupFile != null && mounted) {
        String dateStr = "Inconnue";
        if (backupFile.modifiedTime != null) {
          dateStr = "${backupFile.modifiedTime!.day}/${backupFile.modifiedTime!.month} à ${backupFile.modifiedTime!.hour}:${backupFile.modifiedTime!.minute}";
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Row(
              children: [
                const Icon(Icons.cloud_download, color: Colors.blueAccent),
                const SizedBox(width: 10),
                const Expanded(child: Text("Sauvegarde trouvée", style: TextStyle(color: Colors.white))),
              ],
            ),
            content: Text(
              "Une sauvegarde a été trouvée sur votre Google Drive datant du $dateStr.\nVoulez-vous la restaurer maintenant ?",
              style: GoogleFonts.cinzel(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Ignorer", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _restoreFromDrive(backupFile.id!);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                child: const Text("Restaurer", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _restoreFromDrive(String fileId) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final jsonString = await _driveService.downloadBackup(fileId);
      if (jsonString != null) {
        await _backupService.restoreFromJson(jsonString);
        if (mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Restauration réussie !"), backgroundColor: Colors.green)
          );
          // Recharger l'app (retour accueil)
          setState(() { _selectedIndex = 0; }); 
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur restauration : $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background_texture_black.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          drawer: _buildDrawer(context), 
          body: SafeArea(
            child: _pages.elementAt(_selectedIndex),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed, 
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Compteur'),
              BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scanner'),             
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Recherche'),
              BottomNavigationBarItem(icon: Icon(Icons.style_outlined), label: 'Decks'),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Collection'),
            ],
          ),
        ),
      ],
    );
  }

  // --- DRAWER ---
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Logo
                Image.asset('assets/icone.png', width: 60, height: 60, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.auto_awesome, size: 48, color: Colors.white24)),
                const SizedBox(height: 16),
                Text('Magic Companion', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Outils & Références', style: GoogleFonts.cinzel(color: Colors.yellow.shade800, fontSize: 14)),
              ],
            ),
          ),
          
          // --- INDICATEUR DE CONNEXION DRIVE ---
          FutureBuilder<bool>(
            future: _driveService.signIn(silent: true),
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              final userEmail = _driveService.currentUser?.email;

              // Cas Connecté
              if (isConnected) {
                return Container(
                  color: Colors.green.withOpacity(0.1),
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done, color: Colors.green),
                    title: Text(userEmail ?? 'Compte Google', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Sauvegarde auto active', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                    trailing: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                      tooltip: "Déconnecter",
                      onPressed: () async {
                        final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A1A),
                          title: const Text("Déconnexion", style: TextStyle(color: Colors.white)),
                          content: const Text("Arrêter la sauvegarde automatique ?", style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Annuler")),
                            TextButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Déconnecter", style: TextStyle(color: Colors.red))),
                          ],
                        ));
                        if(confirm == true) {
                          await _driveService.signOut();
                          setState(() {});
                        }
                      },
                    ),
                  ),
                );
              } 
              // Cas Déconnecté
              else {
                return ListTile(
                  leading: const Icon(Icons.cloud_off, color: Colors.white54),
                  title: Text('Connexion Drive', style: GoogleFonts.cinzel(color: Colors.white)),
                  subtitle: const Text('Activer la sauvegarde auto', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  onTap: () async {
                    // Ici on lance la connexion interactive
                    await _driveService.signIn(silent: false);
                    setState(() {}); 
                  },
                );
              }
            }
          ),
          
          const Divider(color: Colors.white10),
          // --- SECTION JEU ---
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined, color: Colors.white70),
            title: Text('Gestion Tournoi', style: GoogleFonts.cinzel(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => TournamentPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
            title: Text('Oracle (IA)', style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text("Posez vos questions de règles", style: TextStyle(color: Colors.white38, fontSize: 10)),
            tileColor: Colors.purple.withOpacity(0.1), // Mise en valeur subtile
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MagicOraclePage()));
            },
          ),
          // --- SECTION OUTILS ---
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.calculate_outlined, color: Colors.white70),
            title: Text('Calculateur Proba', style: GoogleFonts.cinzel(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HypergeometricPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.white70),
            title: Text('Glossaire', style: GoogleFonts.cinzel(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
                appBar: AppBar(title: Text('Glossaire', style: GoogleFonts.cinzel())),
                backgroundColor: const Color(0xFF1A1A1A),
                body: const GlossaryPage(),
              )));
            },
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white70),
            title: Text('Paramètres & Sauvegarde', style: GoogleFonts.cinzel(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white30),
            title: Text('À propos', style: GoogleFonts.cinzel(color: Colors.white54)),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context, 
                applicationName: 'Magic Companion',
                applicationVersion: '1.0.0',
                applicationIcon: Image.asset('assets/icone.png', width: 60, height: 60, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.auto_awesome, size: 48, color: Colors.white24)),
                children: [Text("Développé avec Flutter", style: GoogleFonts.cinzel())],
              );
            },
          ),
        ],
      ),
    );
  }
}