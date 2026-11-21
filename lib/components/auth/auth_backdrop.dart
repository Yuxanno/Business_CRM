import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Architectural geometric backdrop for Auth screens.
/// Fully static inside a single RepaintBoundary for rock-solid 60/120fps
/// with zero idle GPU/CPU usage and zero per-frame layout passes.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Auth always uses the bright signature brand canvas.
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        extensions: const [AppSemanticColors.light],
      ),
      child: Builder(
        builder: (context) {
          final colors = context.appColors;
          return Scaffold(
            backgroundColor: colors.background,
            body: Stack(
              children: [
                // Static decorative canvas isolated in a single RepaintBoundary
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        // 1. Subtle architectural grid & rising growth curve
                        Positioned.fill(
                          child: CustomPaint(
                            painter: const _AuthCanvasPainter(
                              primary: AppColors.primary,
                              ink: AppColors.ink,
                            ),
                          ),
                        ),

                        // 2. Top-right soft geometric sphere
                        Positioned(
                          top: -98,
                          right: -70,
                          child: _SoftGeomShape(
                            size: 270,
                            radius: 108,
                            angle: 0.18,
                            color: AppColors.primary.withValues(alpha: 0.13),
                          ),
                        ),

                        // 3. Mid-left breathing square accent
                        Positioned(
                          top: 190,
                          left: -105,
                          child: _SoftGeomShape(
                            size: 210,
                            radius: 72,
                            angle: -0.18,
                            color:
                                AppColors.primaryLight.withValues(alpha: 0.11),
                          ),
                        ),

                        // 4. Bottom-right architectural rotated frame
                        Positioned(
                          bottom: -50,
                          right: -35,
                          child: Transform.rotate(
                            angle: math.pi / 7,
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: AppColors.ink.withValues(alpha: 0.07),
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 5. Large editorial watermark typography
                        Positioned(
                          top: 64,
                          left: 24,
                          child: IgnorePointer(
                            child: Text(
                              'BIZFLOW',
                              style: TextStyle(
                                fontSize: 68,
                                fontWeight: FontWeight.w900,
                                height: 0.9,
                                letterSpacing: -3.2,
                                color: AppColors.ink.withValues(alpha: 0.045),
                              ),
                            ),
                          ),
                        ),

                        // 6. Subtle "CRM • FINANCE" pill below language switcher
                        Positioned(
                          top: 58,
                          right: 16,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CRM • FINANCE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color:
                                          AppColors.ink.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Foreground content
                SafeArea(child: child),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SoftGeomShape extends StatelessWidget {
  const _SoftGeomShape({
    required this.size,
    required this.radius,
    required this.angle,
    required this.color,
  });

  final double size;
  final double radius;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _AuthCanvasPainter extends CustomPainter {
  const _AuthCanvasPainter({
    required this.primary,
    required this.ink,
  });

  final Color primary;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle dot matrix in the top area
    final dotPaint = Paint()
      ..color = ink.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    const step = 28.0;
    final maxCols = (size.width / step).ceil();
    for (int x = 0; x <= maxCols; x++) {
      for (int y = 0; y < 9; y++) {
        final dx = x * step + 10;
        final dy = y * step + 18;
        canvas.drawCircle(Offset(dx, dy), 1.15, dotPaint);
      }
    }

    // Minimalist rising trend curve along the lower background
    final curvePaint = Paint()
      ..color = primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final startY = size.height * 0.86;
    final path = Path()
      ..moveTo(-20, startY)
      ..cubicTo(
        size.width * 0.25,
        startY - 34,
        size.width * 0.55,
        startY - 10,
        size.width + 20,
        startY - 92,
      );

    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _AuthCanvasPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.ink != ink;
}
