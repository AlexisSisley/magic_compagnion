// Fichier : lib/widgets/life_counter/player_zone.dart
// VERSION MISE À JOUR (Layout vertical/horizontal)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/player_model.dart';

// ... (La classe _FloatingNumber est inchangée) ...
class _FloatingNumber {
  final int id;
  final String text;
  final Color color;
  double top = 100.0;
  double opacity = 1.0;

  _FloatingNumber({required this.id, required this.text, required this.color});
}


class PlayerZone extends StatefulWidget {
  const PlayerZone({
    super.key,
    required this.player,
    required this.backgroundColor,
    required this.onLifeChanged, 
    required this.onShowCommanderDamage,
    this.isRotated = false,
    this.isCommander = false,
    this.isVertical = false, // <-- NOUVEAU PARAMÈTRE
  });

  final Player player;
  final Color backgroundColor;
  final bool isRotated;
  final bool isCommander;
  final bool isVertical; // <-- NOUVEAU PARAMÈTRE
  final Function(int) onLifeChanged; 
  final VoidCallback onShowCommanderDamage;

  @override
  State<PlayerZone> createState() => _PlayerZoneState();
}

class _PlayerZoneState extends State<PlayerZone> {
  final List<_FloatingNumber> _floatingNumbers = [];
  int _nextNumberId = 0;

  // Fonction pour déclencher le changement de vie ET l'animation
  void _triggerChange(int change) {
    widget.onLifeChanged(change);
    _showFloatingNumber(change);
  }

  // Gère l'animation (inchangée)
  void _showFloatingNumber(int change) {
    final String text = (change > 0) ? '+$change' : '$change';
    final Color color = (change > 0) ? Colors.green.shade300 : Colors.red.shade300;
    final int id = _nextNumberId++;

    final number = _FloatingNumber(id: id, text: text, color: color);
    setState(() {
      _floatingNumbers.add(number);
    });

    Timer(const Duration(milliseconds: 100), () {
      setState(() {
        number.top = 0.0;
        number.opacity = 0.8;
      });
    });

    Timer(const Duration(milliseconds: 1200), () {
      setState(() {
        _floatingNumbers.removeWhere((n) => n.id == id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Le contenu principal est un Stack pour les animations et le fond
    Widget mainContent = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Container(color: widget.backgroundColor),
        
        // Choisir le layout
        widget.isVertical 
            ? _buildVerticalLayout() 
            : _buildHorizontalLayout(),

        // Les animations restent au-dessus de tout, au centre
        Center(
          child: IgnorePointer( // Ignore les clics sur les chiffres
            child: Stack(
              alignment: Alignment.center,
              children: _floatingNumbers.map((number) {
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  top: number.top,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 1000),
                    opacity: number.opacity,
                    child: Text(
                      number.text,
                      style: GoogleFonts.cinzel(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: number.color,
                        shadows: [
                          const Shadow(blurRadius: 4.0, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );

    // La rotation s'applique à l'ensemble
    if (widget.isRotated) {
      return Transform.rotate(
        angle: 3.14159, // 180 degrés
        child: mainContent,
      );
    }
    return mainContent;
  }

  // --- NOUVEAU WIDGET : Layout vertical (pour 4+ joueurs) ---
  Widget _buildVerticalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // --- Bouton Plus ---
        Expanded(
          flex: 2, // Donne plus d'espace au tap
          child: GestureDetector(
            onTap: () => _triggerChange(1),
            onLongPress: () => _triggerChange(5),
            child: Container(
              width: double.infinity,
              color: Colors.transparent, // Zone de tap
              child: const Icon(Icons.add, size: 50, color: Colors.white70),
            ),
          ),
        ),
        
        // --- Zone Centrale ---
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Vie ---
            Text(
              '${widget.player.life}',
              style: GoogleFonts.cinzel(
                fontSize: 80, // Police réduite pour le mode vertical
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
            
            // --- Bouton Dégâts de Commandant ---
            if (widget.isCommander)
              GestureDetector(
                onTap: widget.onShowCommanderDamage,
                child: Container(
                  margin: const EdgeInsets.only(top: 8.0), // Espace
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CDT: ${widget.player.totalCommanderDamage}', // Texte plus court
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 16, // Police un peu plus petite
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        
        // --- Bouton Moins ---
        Expanded(
          flex: 2, // Donne plus d'espace au tap
          child: GestureDetector(
            onTap: () => _triggerChange(-1),
            onLongPress: () => _triggerChange(-5),
            child: Container(
              width: double.infinity,
              color: Colors.transparent, // Zone de tap
              child: const Icon(Icons.remove, size: 50, color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }

  // --- ANCIEN WIDGET : Layout horizontal (pour 1-3 joueurs) ---
  Widget _buildHorizontalLayout() {
    return Stack(
      children: [
        // --- Bouton Moins ---
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => _triggerChange(-1),
            onLongPress: () => _triggerChange(-5),
            child: Container(
              width: 120,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(Icons.remove, size: 60, color: Colors.white70),
            ),
          ),
        ),
        
        // --- Bouton Plus ---
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => _triggerChange(1),
            onLongPress: () => _triggerChange(5),
            child: Container(
              width: 120,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(Icons.add, size: 60, color: Colors.white70),
            ),
          ),
        ),
        
        // --- Affichage Principal (Vie) ---
        Center(
          child: Text(
            '${widget.player.life}',
            style: GoogleFonts.cinzel(
              fontSize: 104, // Grosse police pour le mode horizontal
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(2.0, 2.0),
                ),
              ],
            ),
          ),
        ),
        
        // --- Bouton Dégâts de Commandant ---
        if (widget.isCommander)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: widget.onShowCommanderDamage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CDT Reçus : ${widget.player.totalCommanderDamage}',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}