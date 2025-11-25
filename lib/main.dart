// Fichier : lib/main.dart
// VERSION MISE À JOUR : Ajout de l'entrée Paramètres dans le Drawer

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Imports des pages
import 'package:magic_companion/pages/card_search_page.dart';
import 'package:magic_companion/pages/collection_page.dart';
import 'package:magic_companion/pages/scanner_page.dart';
import 'pages/life_counter_page.dart';
import 'pages/glossary_page.dart';
import 'pages/deck_list_page.dart';
import 'pages/settings_page.dart'; // <-- NOUVEL IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0; 

  static const List<Widget> _pages = <Widget>[
    LifeCounterPage(),
    ScannerPage(),
    CardSearchPage(),
    DeckListPage(),
    CollectionPage(),
  ];

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
          drawer: _buildDrawer(context), // Menu latéral
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

  // --- DRAWER MIS À JOUR ---
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
                const Icon(Icons.auto_awesome, size: 48, color: Colors.white24),
                const SizedBox(height: 16),
                Text('Magic Companion', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Outils & Références', style: GoogleFonts.cinzel(color: Colors.yellow.shade800, fontSize: 14)),
              ],
            ),
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

          // --- NOUVEAU : BOUTON PARAMÈTRES ---
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
                applicationIcon: const Icon(Icons.auto_awesome, size: 40),
                children: [Text("Développé avec Flutter", style: GoogleFonts.cinzel())],
              );
            },
          ),
        ],
      ),
    );
  }
}