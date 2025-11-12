// Fichier : lib/main.dart
// VERSION CORRIGÉE (avec initialisation de intl)

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart' ;
import 'package:magic_companion/pages/card_search_page.dart';
import 'package:magic_companion/pages/collection_page.dart';
import 'package:magic_companion/pages/scanner_page.dart';
import 'pages/life_counter_page.dart'; 
import 'pages/glossary_page.dart'; 
import 'pages/deck_list_page.dart';

// --- Imports pour la localisation (maintenant valides) ---
import 'package:flutter_localizations/flutter_localizations.dart';

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
      
      // Garantit que l'app utilise le format FR pour les dates
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'), // Supporte le Français
        Locale('en', 'US'), // Fallback Anglais
      ],
      locale: const Locale('fr', 'FR'),
      
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: const AppShell(),
    );
  }
}

// ... (Le reste de AppShell est inchangé) ...
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0; 

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
          body: SafeArea(
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
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white54,
          ),
        ),
      ],
    );
  }
}