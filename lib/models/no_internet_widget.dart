import 'package:flutter/material.dart';

class BrokenCarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint mainPaint = Paint()
      ..color = const Color.fromARGB(255, 101, 204, 82)
      ..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint smokePaint = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw car body
    final Path carBody = Path()
      ..moveTo(size.width * 0.2, size.height * 0.6)
      ..lineTo(size.width * 0.15, size.height * 0.4)
      ..lineTo(size.width * 0.3, size.height * 0.35)
      ..lineTo(size.width * 0.4, size.height * 0.25)
      ..lineTo(size.width * 0.75, size.height * 0.25)
      ..lineTo(size.width * 0.85, size.height * 0.35)
      ..lineTo(size.width * 0.9, size.height * 0.6)
      ..close();

    canvas.drawPath(carBody, mainPaint);
    canvas.drawPath(carBody, strokePaint);

    // Draw windows
    final Path windows = Path()
      ..moveTo(size.width * 0.4, size.height * 0.28)
      ..lineTo(size.width * 0.55, size.height * 0.28)
      ..lineTo(size.width * 0.55, size.height * 0.35)
      ..lineTo(size.width * 0.4, size.height * 0.35)
      ..close();

    canvas.drawPath(windows, whitePaint);
    canvas.drawPath(windows, strokePaint);

    // Draw wheels (tilted to show it's broken)
    final Paint tirePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Left wheel (fallen off)
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.7),
      size.width * 0.08,
      tirePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.7),
      size.width * 0.08,
      strokePaint,
    );

    // Right wheel (tilted)
    final Paint wheelStrokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.save();
    canvas.translate(size.width * 0.75, size.height * 0.65);
    canvas.rotate(-0.3);
    canvas.drawCircle(
      Offset.zero,
      size.width * 0.08,
      tirePaint,
    );
    // Add wheel details
    for (int i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset.zero,
        Offset(size.width * 0.08, 0),
        wheelStrokePaint,
      );
      canvas.rotate(3.14159 / 3);
    }
    canvas.restore();

    // Draw sad face
    // Eyes
    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.45),
      size.width * 0.03,
      whitePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.65, size.height * 0.45),
      size.width * 0.03,
      whitePaint,
    );

    // Sad eyebrows
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.4),
      Offset(size.width * 0.48, size.height * 0.42),
      strokePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, size.height * 0.42),
      Offset(size.width * 0.68, size.height * 0.4),
      strokePaint,
    );

    // Sad mouth
    final Path mouth = Path()
      ..moveTo(size.width * 0.5, size.height * 0.52)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.48,
        size.width * 0.6,
        size.height * 0.52,
      );
    canvas.drawPath(mouth, strokePaint);

    // Draw smoke clouds
    _drawSmoke(canvas, size, smokePaint, strokePaint);

    // Draw broken pieces
    _drawBrokenPieces(canvas, size, mainPaint, strokePaint);
  }

  void _drawSmoke(
      Canvas canvas, Size size, Paint smokePaint, Paint strokePaint) {
    List<Offset> smokePositions = [
      Offset(size.width * 0.9, size.height * 0.3),
      Offset(size.width * 0.95, size.height * 0.25),
      Offset(size.width * 0.85, size.height * 0.2),
    ];

    for (var position in smokePositions) {
      final Path smoke = Path()
        ..addOval(Rect.fromCenter(
          center: position,
          width: size.width * 0.1,
          height: size.width * 0.1,
        ));
      canvas.drawPath(smoke, smokePaint);
      canvas.drawPath(smoke, strokePaint..strokeWidth = 1);
    }
  }

  void _drawBrokenPieces(
      Canvas canvas, Size size, Paint mainPaint, Paint strokePaint) {
    // Draw some scattered pieces to show it's broken
    List<Offset> piecePositions = [
      Offset(size.width * 0.2, size.height * 0.75),
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.85, size.height * 0.75),
    ];

    for (var position in piecePositions) {
      final Path piece = Path()
        ..moveTo(position.dx, position.dy)
        ..lineTo(
            position.dx + size.width * 0.05, position.dy - size.height * 0.02)
        ..lineTo(
            position.dx + size.width * 0.08, position.dy + size.height * 0.02)
        ..close();
      canvas.drawPath(piece, mainPaint);
      canvas.drawPath(piece, strokePaint);
    }

    // Add some "fix me" text with an arrow
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Fix me!',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width * 0.2, size.height * 0.15));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NoInternetWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetWidget({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 101, 204, 82),
            Color.fromARGB(255, 220, 247, 214),
          ],
        ),
      ),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 250,
                  height: 200,
                  child: CustomPaint(
                    painter: BrokenCarPainter(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please check your internet connection\nand try again',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 101, 204, 82),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text(
                        'Retry Connection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
