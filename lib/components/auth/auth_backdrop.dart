import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Soft geometric canvas for auth screens — light, teal, not a generic card form.
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
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auth always uses the light brand surface, even if the app is in dark mode.
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
              builder: (context, _) {
                final t = _controller.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -120 + (t * 24),
                      right: -80,
                      child: _Blob(
                        size: 280,
                        color: AppColors.primary.withValues(alpha: 0.14),
                      ),
                    ),
                    Positioned(
                      top: 180 - (t * 18),
                      left: -100,
                      child: _Blob(
                        size: 220,
                        color: AppColors.primaryLight.withValues(alpha: 0.12),
                      ),
                    ),
                    Positioned(
                      bottom: -60 + (t * 20),
                      right: -40,
                      child: Transform.rotate(
                        angle: math.pi / 8,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.ink.withValues(alpha: 0.08),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 72,
                      left: 28,
                      child: IgnorePointer(
                        child: Text(
                          'BIZNES',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                            letterSpacing: -3,
                            color: AppColors.ink.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(child: widget.child),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.42),
      ),
    );
  }
}
