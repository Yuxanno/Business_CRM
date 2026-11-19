import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Architectural geometric backdrop for Auth screens.
/// Light editorial surface with subtle animated shapes, a fine diagonal grid,
/// and a stylized rising growth curve — high-FPS with zero blur shaders.
class AuthBackdrop extends StatefulWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            body: AnimatedBuilder(
              animation: _controller,
              builder: (context, childWidget) {
                final t = Curves.easeInOutSine.transform(_controller.value);
                return Stack(
                  children: [
                    // 1. Subtle architectural grid & rising growth curve
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _AuthCanvasPainter(
                            progress: t,
                            primary: AppColors.primary,
                            ink: AppColors.ink,
                          ),
                        ),
                      ),
                    ),

                    // 2. Top-right soft geometric sphere
                    Positioned(
                      top: -105 + (t * 20),
                      right: -75 + (t * 10),
                      child: _SoftGeomShape(
                        size: 270,
                        radius: 108,
                        angle: 0.15 + t * 0.08,
                        color: AppColors.primary.withValues(alpha: 0.13),
                      ),
                    ),

                    // 3. Mid-left breathing square accent
                    Positioned(
                      top: 195 - (t * 16),
                      left: -105,
                      child: _SoftGeomShape(
                        size: 210,
                        radius: 72,
                        angle: -0.2 + t * 0.06,
                        color: AppColors.primaryLight.withValues(alpha: 0.11),
                      ),
                    ),

                    // 4. Bottom-right architectural rotated frame
                    Positioned(
                      bottom: -55 + (t * 18),
                      right: -35,
                      child: Transform.rotate(
                        angle: math.pi / 7 + (t * 0.05),
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

                    // 6. Floating subtle "growth" pill accent in top-right
                    Positioned(
                      top: 54 + (t * 6),
                      right: 22,
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
                              color: AppColors.primary.withValues(alpha: 0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
                                  color: AppColors.ink.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Foreground content
                    SafeArea(child: childWidget!),
                  ],
                );
              },
              child: widget.child,
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
    required this.progress,
    required this.primary,
    required this.ink,
  });

  final double progress;
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
        startY - 30 - (progress * 10),
        size.width * 0.55,
        startY - 12 + (progress * 8),
        size.width + 20,
        startY - 88 - (progress * 12),
      );

    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(_AuthCanvasPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
