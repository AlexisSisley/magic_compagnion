// Fichier : lib/widgets/scans/scanner_overlay_painter.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Custom painter that draws the card-shaped scanning overlay
/// with animated laser line and corner indicators.
class ScannerOverlayPainter extends CustomPainter {
  final double scanValue;
  final Color borderColor;

  ScannerOverlayPainter({required this.scanValue, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final double cardWidth = size.width * 0.75;
    final double cardHeight = cardWidth * 1.4;

    final double left = (size.width - cardWidth) / 2;
    final double top = (size.height - cardHeight) / 2;
    final Rect scanRect = Rect.fromLTWH(left, top, cardWidth, cardHeight);
    final RRect scanRRect =
        RRect.fromRectAndRadius(scanRect, const Radius.circular(12));

    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cutoutPath = Path()..addRRect(scanRRect);

    final Path overlayPath =
        Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    paint.color = AppColors.textOnPrimary.withValues(alpha: 0.6);
    canvas.drawPath(overlayPath, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(scanRRect, borderPaint);

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    double cornerSize = 20;
    canvas.drawPath(
        Path()
          ..moveTo(left, top + cornerSize)
          ..lineTo(left, top)
          ..lineTo(left + cornerSize, top),
        cornerPaint);
    canvas.drawPath(
        Path()
          ..moveTo(left + cardWidth, top + cornerSize)
          ..lineTo(left + cardWidth, top)
          ..lineTo(left + cardWidth - cornerSize, top),
        cornerPaint);
    canvas.drawPath(
        Path()
          ..moveTo(left, top + cardHeight - cornerSize)
          ..lineTo(left, top + cardHeight)
          ..lineTo(left + cornerSize, top + cardHeight),
        cornerPaint);
    canvas.drawPath(
        Path()
          ..moveTo(left + cardWidth, top + cardHeight - cornerSize)
          ..lineTo(left + cardWidth, top + cardHeight)
          ..lineTo(left + cardWidth - cornerSize, top + cardHeight),
        cornerPaint);

    final double scanY = top + (cardHeight * scanValue);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          borderColor.withValues(alpha: 0),
          borderColor,
          borderColor.withValues(alpha: 0)
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(left, scanY, cardWidth, 4));

    canvas.drawRect(Rect.fromLTWH(left, scanY, cardWidth, 2), laserPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) =>
      oldDelegate.scanValue != scanValue;
}
