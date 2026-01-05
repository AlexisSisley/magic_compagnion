// Fichier : lib/widgets/life_counter/dice_roll_dialog.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DiceRollAnimationDialog extends StatefulWidget {
  final int sides;
  final int finalResult;
  final VoidCallback onReroll;

  const DiceRollAnimationDialog({
    super.key,
    required this.sides,
    required this.finalResult,
    required this.onReroll,
  });

  @override
  State<DiceRollAnimationDialog> createState() => _DiceRollAnimationDialogState();
}

class _DiceRollAnimationDialogState extends State<DiceRollAnimationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _spinTimer;
  int _currentSpinValue = 1;
  bool _isAnimating = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    final CurvedAnimation curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    
    // Rotation plus importante pour les pièces (pile ou face)
    _animation = Tween<double>(
      begin: 0, 
      end: widget.sides == 2 ? pi * 10 : pi * 6
    ).animate(curve);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _spinTimer?.cancel();
        setState(() { _isAnimating = false; });
      }
    });

    _controller.forward();

    // Effet de défilement des chiffres (sauf pour pile/face)
    if (widget.sides > 2) {
      _spinTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
        setState(() { _currentSpinValue = Random().nextInt(widget.sides) + 1; });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.2))),
      title: _isAnimating ? null : Center(child: Text(_getTitle(), style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18))),
      content: SizedBox(
        height: 150,
        child: Center(child: _isAnimating ? _buildAnimatedView() : _buildFinalResultView()),
      ),
      actions: _isAnimating ? [] : _buildActions(),
    );
  }

  Widget _buildAnimatedView() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        if (widget.sides == 2) {
            bool showHeads = (_animation.value / pi).floor() % 2 == 0;
             return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(_animation.value),
              child: Icon(Icons.monetization_on, size: 100, color: showHeads ? Colors.amber : Colors.blueGrey.shade300),
            );
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(angle: _animation.value, child: Icon(_getIconForDice(widget.sides), size: 100, color: Colors.white12)),
            Text('$_currentSpinValue', style: GoogleFonts.cinzel(color: Colors.white.withOpacity(0.7), fontSize: 50, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

   IconData _getIconForDice(int sides) {
    if (sides == 4) return Icons.change_history;
    if (sides == 6) return Icons.looks_6;
    if (sides == 8) return Icons.diamond;
    if (sides == 20) return Icons.casino;
    return Icons.all_out;
  }

  String _getTitle() {
     if (widget.sides == 2) return "Pile ou Face";
     if (widget.sides == 20 && widget.finalResult == 1) return 'POUR FRODON !';
     if (widget.sides == 20 && widget.finalResult == 20) return 'FUS RO DAH !!! 🐉';
     return 'Résultat D${widget.sides}';
  }

  Widget _buildFinalResultView() {
    String content = '${widget.finalResult}';
    Color contentColor = Colors.yellow.shade700;
    double fontSize = 80;

    if (widget.sides == 2) {
      content = widget.finalResult == 1 ? "FACE" : "PILE";
      contentColor = widget.finalResult == 1 ? Colors.amber : Colors.blueGrey;
      fontSize = 40;
    }
    if (widget.sides == 20 && widget.finalResult == 1) {
      content = '${widget.finalResult} ⚔️';
      contentColor = Colors.red.shade400;
    }
    if (widget.sides == 20 && widget.finalResult == 20) {
      content = '${widget.finalResult} 💨';
      contentColor = Colors.cyanAccent; 
    }

    return Text(content, textAlign: TextAlign.center, style: GoogleFonts.cinzel(color: contentColor, fontSize: fontSize, fontWeight: FontWeight.bold, shadows: [BoxShadow(color: contentColor.withOpacity(0.5), blurRadius: 20)]));
  }

  List<Widget> _buildActions() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(onPressed: widget.onReroll, icon: const Icon(Icons.refresh, color: Colors.white54), label: Text('Relancer', style: GoogleFonts.cinzel(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white10), child: Text('OK', style: GoogleFonts.cinzel(color: Colors.white))),
        ],
      ),
    ];
  }
}