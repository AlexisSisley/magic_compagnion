// Fichier : lib/main.dart

import 'package:flutter/material.dart';
import 'package:magic_companion/pages/card_search_page.dart';
import 'package:magic_companion/pages/collection_page.dart';
import 'package:magic_companion/pages/scanner_page.dart';
import 'pages/life_counter_page.dart'; 
import 'pages/glossary_page.dart'; 
import 'pages/deck_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MagicCompanionApp());
}

class MagicCompanionApp extends StatelessWidget {
  const MagicCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        // Thème global
        scaffoldBackgroundColor: Colors.transparent,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
        ),
      ),
      // Notre "coquille" devient la page d'accueil
      home: const AppShell(),
    );
  }
}

// Ce widget gère la navigation principale et le fond
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0; // 0 = Compteur, 1 = Glossaire

  // La liste de nos deux pages principales
  static const List<Widget> _pages = <Widget>[
    LifeCounterPage(),
    GlossaryPage(),
    CardSearchPage(),
    ScannerPage(),
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
        // 1. NOTRE FOND TEXTURÉ (persiste sur toutes les pages)
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background_texture_black.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // 2. Le Scaffold (l'échafaudage de l'app)
        Scaffold(
          backgroundColor: Colors.transparent, // Important pour voir la texture
          body: SafeArea(
            // SafeArea évite que l'UI passe sous l'encoche/barre de statut
            child: _pages.elementAt(_selectedIndex),
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Compteur',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.book),
                label: 'Glossaire',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search), 
                label: 'Recherche',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt), 
                label: 'Scanner',             
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
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed, // Important pour 4+ items
            backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white54,
          ),
        ),
      ],
    );
  }
}