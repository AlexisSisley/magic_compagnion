import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class SkyrimSneakLoader extends StatefulWidget {
  const SkyrimSneakLoader({super.key});

  @override
  State<SkyrimSneakLoader> createState() => _SkyrimSneakLoaderState();
}

class _SkyrimSneakLoaderState extends State<SkyrimSneakLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    // Animation de respiration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() { _isOpen = !_isOpen; });
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _SkyrimEyePainter(breath: _controller.value, isOpen: _isOpen),
              child: const SizedBox(width: 100, height: 50),
            );
          },
        ),
      ),
    );
  }
}

class _SkyrimEyePainter extends CustomPainter {
  final double breath;
  final bool isOpen;

  _SkyrimEyePainter({required this.breath, required this.isOpen});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC0A060) // Couleur parchemin/interface Skyrim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    
    // 1. Dessiner la forme de l'œil (courbes de Bézier)
    final path = Path();
    path.moveTo(0, center.dy);
    // Courbe supérieure
    path.quadraticBezierTo(center.dx, -size.height * 0.2, size.width, center.dy);
    // Courbe inférieure
    path.quadraticBezierTo(center.dx, size.height * 1.2, 0, center.dy);
    canvas.drawPath(path, paint);

    // 2. Dessiner l'intérieur
    if (isOpen) {
       // Oeil ouvert : Pupille qui "respire" (change de taille)
       paint.style = PaintingStyle.fill;
       canvas.drawCircle(center, 6 + (breath * 3), paint); 
    } else {
       // Oeil fermé : Trait horizontal
       final linePaint = Paint()
         ..color = paint.color
         ..strokeWidth = 3
         ..strokeCap = StrokeCap.round;
       canvas.drawLine(
         Offset(center.dx - 15, center.dy), 
         Offset(center.dx + 15, center.dy), 
         linePaint
       );
       
       // Texte "HIDDEN" qui apparaît/disparaît doucement
       final textSpan = TextSpan(
         text: 'HIDDEN',
         style: AppTextStyles.bold(color: paint.color.withValues(alpha: 0.5 + breath * 0.5), fontSize: 12),
       );
       final textPainter = TextPainter(
         text: textSpan, 
         textDirection: TextDirection.ltr
       )..layout();
       
       textPainter.paint(
         canvas, 
         Offset(center.dx - textPainter.width / 2, size.height + 5)
       );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyrimEyePainter oldDelegate) {
    return oldDelegate.breath != breath || oldDelegate.isOpen != isOpen;
  }
}
