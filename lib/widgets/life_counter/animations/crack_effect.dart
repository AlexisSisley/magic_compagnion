// Fichier : lib/widgets/life_counter/animations/crack_effect.dart
// Task 13: CrackEffect CustomPainter for EliminationOverlay Phase 2

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Draws 5-8 crack lines radiating from center of canvas with a zigzag pattern.
/// [progress] controls how much of each crack is drawn (0.0 to 1.0).
class CrackEffect extends CustomPainter {
  final double progress;
  final Color color;

  const CrackEffect({
    required this.progress,
    this.color = const Color(0xB3FFFFFF), // white with 70% opacity
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;

    // Use a fixed seed for deterministic cracks (same each frame)
    final rng = math.Random(42);
    const crackCount = 7;

    for (int i = 0; i < crackCount; i++) {
      // Evenly spread angles with small random offset
      final baseAngle = (i / crackCount) * 2 * math.pi;
      final angleOffset = (rng.nextDouble() - 0.5) * 0.6;
      final angle = baseAngle + angleOffset;

      final segmentCount = 3 + rng.nextInt(3); // 3-5 segments per crack
      final totalLength = (maxRadius * 0.4) + rng.nextDouble() * maxRadius * 0.4;
      final drawnLength = totalLength * progress;

      var currentPos = center;
      var remainingLength = drawnLength;
      var currentAngle = angle;

      final path = Path()..moveTo(currentPos.dx, currentPos.dy);

      for (int s = 0; s < segmentCount && remainingLength > 0; s++) {
        final segmentLength = totalLength / segmentCount;
        final actualSegment = math.min(segmentLength, remainingLength);

        // Small zigzag deviation for each segment
        final deviation = (rng.nextDouble() - 0.5) * 0.4;
        currentAngle += deviation;

        final nextPos = Offset(
          currentPos.dx + math.cos(currentAngle) * actualSegment,
          currentPos.dy + math.sin(currentAngle) * actualSegment,
        );
        path.lineTo(nextPos.dx, nextPos.dy);

        currentPos = nextPos;
        remainingLength -= actualSegment;
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CrackEffect oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
