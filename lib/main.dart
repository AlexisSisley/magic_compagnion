// Fichier : lib/main.dart

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
import 'pages/set_list_page.dart'; // Assurez-vous d'avoir créé ce fichier à l'étape précédente

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise le package de formatage des dates pour le français
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
      
      // Configuration de la localisation
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      
      // Thème sombre global
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Fond gris foncé par défaut
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black.withAlpha((0.9 * 255).round()),
          selectedItemColor: Colors.yellow.shade800, // Couleur active (Or)
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed, // Nécessaire pour 5 items
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

  // Liste des 5 pages principales pour la barre du bas
  static const List<Widget> _pages = <Widget>[
    LifeCounterPage(),  // Index 0
    ScannerPage(),      // Index 1
    CardSearchPage(),   // Index 2
    DeckListPage(),     // Index 3
    CollectionPage(),   // Index 4
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
        // Image de fond globale
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background_texture_black.png'), // Vérifiez que cette image existe
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        Scaffold(
          backgroundColor: Colors.transparent,
          
          // --- LE MENU LATÉRAL (DRAWER) ---
          // C'est ici que l'on met les fonctionnalités "secondaires"
          drawer: _buildDrawer(context),
          
          // Pour ouvrir le drawer, l'utilisateur peut glisser depuis la gauche
          // ou on peut ajouter un bouton dans l'AppBar si la page en a une.
          // Note : LifeCounterPage a déjà ses propres boutons, mais le swipe fonctionnera.
          
          body: SafeArea(
            child: _pages.elementAt(_selectedIndex),
          ),
          
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            // Force l'affichage des labels pour 5 items
            type: BottomNavigationBarType.fixed, 
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Compteur',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt), 
                label: 'Scanner',             
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search), 
                label: 'Recherche',
              ),
              BottomNavigationBarItem( 
                icon: Icon(Icons.style_outlined), 
                label: 'Decks',
              ),
              BottomNavigationBarItem( 
                icon: Icon(Icons.inventory_2_outlined), 
                label: 'Collection',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Construction du Menu Latéral
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // En-tête du menu
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Logo ou Icône
                const Icon(Icons.auto_awesome, size: 48, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  'Magic Companion',
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Outils & Références',
                  style: GoogleFonts.cinzel(
                    color: Colors.yellow.shade800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // --- LES AUTRES PAGES ---
          
          ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.white70),
            title: Text('Glossaire', style: GoogleFonts.cinzel(color: Colors.white)),
            onTap: () {
              Navigator.pop(context); // Ferme le menu
              // Navigue vers la page Glossaire (en la mettant dans un Scaffold pour avoir le bouton retour)
              Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
                appBar: AppBar(title: Text('Glossaire', style: GoogleFonts.cinzel())),
                backgroundColor: const Color(0xFF1A1A1A),
                body: const GlossaryPage(),
              )));
            },
          ),
          
          const Divider(color: Colors.white10),
          
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