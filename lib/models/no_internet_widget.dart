import 'package:flutter/material.dart';

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
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    painter: RobotPainter(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oops! No Internet Connection',
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                        'Retry',
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

class RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color.fromARGB(255, 101, 204, 82)
      ..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw body
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.3, size.width * 0.6, size.height * 0.5),
      const Radius.circular(20),
    );
    canvas.drawRRect(body, paint);
    canvas.drawRRect(body, strokePaint);

    // Draw head
    final RRect head = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.3, size.height * 0.1, size.width * 0.4, size.height * 0.25),
      const Radius.circular(15),
    );
    canvas.drawRRect(head, paint);
    canvas.drawRRect(head, strokePaint);

    // Draw eyes
    final Paint eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.2),
      size.width * 0.05,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.2),
      size.width * 0.05,
      eyePaint,
    );

    // Draw pupils
    final Paint pupilPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.2),
      size.width * 0.02,
      pupilPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.2),
      size.width * 0.02,
      pupilPaint,
    );

    // Draw antenna
    final Path antennaPath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.1)
      ..lineTo(size.width * 0.5, size.height * 0.0);
    canvas.drawPath(antennaPath, strokePaint);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.0),
      size.width * 0.02,
      paint,
    );

    // Draw arms
    final Path leftArm = Path()
      ..moveTo(size.width * 0.2, size.height * 0.4)
      ..lineTo(size.width * 0.1, size.height * 0.5);
    canvas.drawPath(leftArm, strokePaint);

    final Path rightArm = Path()
      ..moveTo(size.width * 0.8, size.height * 0.4)
      ..lineTo(size.width * 0.9, size.height * 0.5);
    canvas.drawPath(rightArm, strokePaint);

    // Draw legs
    final Path leftLeg = Path()
      ..moveTo(size.width * 0.35, size.height * 0.8)
      ..lineTo(size.width * 0.35, size.height * 0.95);
    canvas.drawPath(leftLeg, strokePaint);

    final Path rightLeg = Path()
      ..moveTo(size.width * 0.65, size.height * 0.8)
      ..lineTo(size.width * 0.65, size.height * 0.95);
    canvas.drawPath(rightLeg, strokePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}