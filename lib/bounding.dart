import 'package:flutter/material.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detectionResults;

  BoundingBoxPainter(this.detectionResults);

  @override
  void paint(Canvas canvas, Size size) {
    for (var result in detectionResults) {
      if (result['box'] == null) continue;
      
      final box = result['box'];
      final objectStatus = result['status'] ?? 'Unknown';
      final confidence = result['confidence'] ?? 0.0;
      
      // Ensure we have 4 coordinates
      if (box.length < 4) continue;
      
      final x1 = (box[0] as num).toDouble();
      final y1 = (box[1] as num).toDouble();
      final x2 = (box[2] as num).toDouble();
      final y2 = (box[3] as num).toDouble();

      final boxColor = _getBoxColor(objectStatus);
      
      // Draw main bounding box with gradient effect
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = boxColor;

      // Draw the main rectangle
      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      canvas.drawRect(rect, paint);
      
      // Draw corner accents for a more modern look
      _drawCornerAccents(canvas, rect, boxColor);

      // Draw label with modern styling
      _drawModernLabel(canvas, objectStatus, confidence, x1, y1, boxColor);
    }
  }

  void _drawCornerAccents(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = color
      ..strokeCap = StrokeCap.round;

    const cornerLength = 20.0;
    
    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );
    
    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );
    
    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );
    
    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );
  }

  void _drawModernLabel(Canvas canvas, String status, double confidence, 
                       double x, double y, Color boxColor) {
    final text = '$status (${(confidence * 100).toInt()}%)';
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Calculate label dimensions with padding
    const padding = 8.0;
    final labelWidth = textPainter.width + (padding * 2);
    final labelHeight = textPainter.height + (padding * 2);
    
    // Create rounded rectangle for label background
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y - labelHeight - 5, labelWidth, labelHeight),
      const Radius.circular(8),
    );

    // Draw label background with gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        boxColor,
        boxColor.withOpacity(0.8),
      ],
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(labelRect.outerRect);
    
    canvas.drawRRect(labelRect, gradientPaint);
    
    // Draw subtle border around label
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.3);
    
    canvas.drawRRect(labelRect, borderPaint);

    // Draw the text
    textPainter.paint(
      canvas, 
      Offset(x + padding, y - labelHeight - 5 + padding),
    );
    
    // Add a small indicator dot
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    
    canvas.drawCircle(
      Offset(x + labelWidth - 12, y - labelHeight/2 - 5),
      3,
      dotPaint,
    );
  }

  Color _getBoxColor(String status) {
    switch (status.toLowerCase()) {
      case 'closed eyes':
      case 'drowsy':
        return const Color(0xFFFF5252); // Modern red
      case 'open eyes':
      case 'alert':
        return const Color(0xFF4CAF50); // Modern green
      case 'yawning':
        return const Color(0xFFFF9800); // Modern orange
      default:
        return const Color(0xFF2196F3); // Modern blue
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}