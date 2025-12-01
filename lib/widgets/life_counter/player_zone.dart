// Fichier : lib/widgets/life_counter/player_zone.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/player_model.dart';

class _FloatingNumber {
  final int id;
  final String text;
  final Color color;
  double top = 20.0; // Position de départ ajustée
  double opacity = 1.0;

  _FloatingNumber({required this.id, required this.text, required this.color});
}

class PlayerZone extends StatefulWidget {
  const PlayerZone({
    super.key,
    required this.player,
    required this.onLifeChanged, 
    required this.onShowCommanderDamage,
    required this.onColorChanged,
    this.isRotated = false,
    this.isCommander = false,
    this.isHighlighted = false,
  });

  final Player player;
  final bool isRotated;
  final bool isCommander;
  final bool isHighlighted;
  final Function(int) onLifeChanged;
  final Function(Color) onColorChanged;
  final VoidCallback onShowCommanderDamage;

  @override
  State<PlayerZone> createState() => _PlayerZoneState();
}

class _PlayerZoneState extends State<PlayerZone> {
  final List<_FloatingNumber> _floatingNumbers = [];
  int _nextNumberId = 0;

  final List<Color> _colorOptions = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.grey.shade800, Colors.purple.shade900, Colors.orange.shade900,
    Colors.teal.shade900, Colors.pink.shade900, Colors.brown.shade800, 
    Colors.indigo.shade900, Colors.blueGrey.shade800, Colors.black
  ];

  void _triggerChange(int change) {
    widget.onLifeChanged(change);
    _showFloatingNumber(change);
  }

  void _showFloatingNumber(int change) {
    final String text = (change > 0) ? '+$change' : '$change';
    final Color color = (change > 0) ? Colors.greenAccent : Colors.redAccent;
    final int id = _nextNumberId++;

    final number = _FloatingNumber(id: id, text: text, color: color);
    if(mounted) setState(() => _floatingNumbers.add(number));

    // Animation vers le haut (plus courte pour être plus dynamique)
    Timer(const Duration(milliseconds: 50), () {
      if(mounted) setState(() { number.top = -50.0; number.opacity = 0.0; });
    });

    Timer(const Duration(milliseconds: 600), () {
      if(mounted) setState(() => _floatingNumbers.removeWhere((n) => n.id == id));
    });
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Couleur Joueur ${widget.player.id + 1}", style: GoogleFonts.cinzel(color: Colors.white)),
        content: Wrap(
          spacing: 12, runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _colorOptions.map((c) => GestureDetector(
            onTap: () { widget.onColorChanged(c); Navigator.pop(ctx); },
            child: Container(
              width: 45, height: 45,
              decoration: BoxDecoration(
                color: c, 
                shape: BoxShape.circle, 
                border: Border.all(color: Colors.white54, width: 2),
                boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
              ),
            ),
          )).toList(),
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Color(widget.player.colorValue);

    Widget content = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: widget.isHighlighted 
            ? Border.all(color: Colors.white, width: 4) 
            : Border.all(color: Colors.white12, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(2,2))]
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // --- LAYOUT PRINCIPAL : Row pour diviser clairement les zones ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ZONE MOINS (Gauche) - Prend tout l'espace disponible
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _triggerChange(-1),
                    onLongPress: () => _triggerChange(-5),
                    splashColor: Colors.black12,
                    highlightColor: Colors.black12,
                    child: Center(
                      // Icône plus grosse et plus visible
                      child: Icon(Icons.remove, color: Colors.white.withOpacity(0.6), size: 48),
                    ),
                  ),
                ),
              ),

              // 2. ZONE CENTRALE (Info Vie) - Taille Fixe
              SizedBox(
                width: 110, // Largeur fixe pour que le texte ne bouge pas les boutons
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Score de vie (Taille réduite pour ne pas être "trop gros")
                    Text(
                      '${widget.player.life}',
                      style: GoogleFonts.cinzel(
                        fontSize: 60, // Réduit par rapport à avant
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [const Shadow(blurRadius: 5, color: Colors.black45)]
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    // Dégâts commandant (si activé)
                    if (widget.isCommander)
                      GestureDetector(
                        onTap: widget.onShowCommanderDamage,
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            'CMD: ${widget.player.totalCommanderDamage}', 
                            style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 3. ZONE PLUS (Droite) - Prend tout l'espace disponible
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _triggerChange(1),
                    onLongPress: () => _triggerChange(5),
                    splashColor: Colors.black12,
                    highlightColor: Colors.black12,
                    child: Center(
                      // Icône plus grosse et plus visible
                      child: Icon(Icons.add, color: Colors.white.withOpacity(0.6), size: 48),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 4. ANIMATIONS FLOTTANTES (Au dessus de tout)
          Center(
            child: IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: _floatingNumbers.map((n) => AnimatedPositioned(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  top: n.top, 
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: n.opacity,
                    child: Text(
                      n.text, 
                      style: GoogleFonts.cinzel(fontSize: 48, fontWeight: FontWeight.bold, color: n.color, shadows: [const Shadow(blurRadius: 4, color: Colors.black)])
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),

          // 5. BOUTON PARAMÈTRES (Discret en haut à droite)
          Positioned(
            top: 0, right: 0, 
            child: IconButton(
              icon: const Icon(Icons.palette, color: Colors.white24, size: 20),
              onPressed: _showColorPicker,
              tooltip: "Changer la couleur",
            ),
          ),
          
          // 6. OVERLAY SURBRILLANCE (Qui commence ?)
          if (widget.isHighlighted)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(8)),
                child: Text("Start ?", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
    );

    // Rotation si nécessaire
    if (widget.isRotated) {
      return Transform.rotate(angle: 3.14159, child: content);
    }
    return content;
  }
}