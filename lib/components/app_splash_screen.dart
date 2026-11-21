import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Animated startup splash screen for native builds (Android / iOS / Desktop).
/// On Web (`kIsWeb`), `web/index.html` already plays the single unified 60fps
/// hardware-accelerated splash animation and holds it until Flutter's first frame
/// is ready, so `AppStartupSplash` passes straight through on Web with zero
/// double-loading or logo flicker.
class AppStartupSplash extends StatefulWidget {
  const AppStartupSplash({
    super.key,
    required this.child,
    this.logoBytes,
  });

  final Widget child;
  final Uint8List? logoBytes;

  @override
  State<AppStartupSplash> createState() => _AppStartupSplashState();
}

class _AppStartupSplashState extends State<AppStartupSplash>
    with TickerProviderStateMixin {
  static const String _brandName = 'BizFlow';

  AnimationController? _introCtrl;
  AnimationController? _exitCtrl;

  bool _minIntroCompleted = false;
  bool _forceTimeoutReached = false;
  bool _exiting = false;
  bool _dismissed = kIsWeb;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    final introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    final exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _introCtrl = introCtrl;
    _exitCtrl = exitCtrl;

    // Wait for Flutter's first rendered frame (when Android removes the static
    // launch_background) before starting the splash animation clock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        if (!mounted) return;
        introCtrl.forward().whenComplete(() {
          if (!mounted) return;
          setState(() => _minIntroCompleted = true);
        });
      });
    });

    _safetyTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _forceTimeoutReached = true);
    });
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _introCtrl?.dispose();
    _exitCtrl?.dispose();
    super.dispose();
  }

  void _triggerExitIfNeeded(bool pagesReady) {
    if (_dismissed || _exiting) return;
    if (!_minIntroCompleted) return;
    if (!pagesReady && !_forceTimeoutReached) return;

    _exiting = true;
    _safetyTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _exitCtrl?.forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _dismissed = true);
      });
    });
  }

  Offset _computeLogoOffset(double t) {
    if (t <= 0.12) {
      return Offset.zero;
    } else if (t <= 0.48) {
      final p = Curves.easeInOutCubic.transform((t - 0.12) / 0.36);
      return Offset(68.0 * p, 0);
    } else {
      // Single continuous sweep from (+68, 0) to (0, -52) above "BizFlow"
      final raw = ((t - 0.48) / 0.52).clamp(0.0, 1.0);
      final p = Curves.easeInOutCubic.transform(raw);
      return Offset(68.0 * (1.0 - p), -52.0 * p);
    }
  }

  Offset _computeWordmarkOffset(double t) {
    if (t <= 0.48) {
      return const Offset(-38.0, 0.0);
    }
    final p =
        Curves.easeInOutCubic.transform(((t - 0.48) / 0.52).clamp(0.0, 1.0));
    return Offset(-38.0 * (1.0 - p), 22.0 * p);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return widget.child;
    }

    final settings = context.watch<SettingsProvider>();
    final dashboard = context.watch<DashboardProvider>();

    final bool pagesReady;
    if (settings.isLoading) {
      pagesReady = false;
    } else if (!settings.isOnboardingDone) {
      pagesReady = true;
    } else {
      pagesReady = (dashboard.hasData || dashboard.hasLoadedOnce) &&
          !dashboard.isLoading;
    }

    _triggerExitIfNeeded(pagesReady);

    final colors = context.appColors;
    final introCtrl = _introCtrl!;
    final exitCtrl = _exitCtrl!;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !_exiting,
          child: widget.child,
        ),
        AbsorbPointer(
          absorbing: !_exiting,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(parent: exitCtrl, curve: Curves.easeOutCubic),
            ),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: introCtrl,
                builder: (context, _) {
                  final t = introCtrl.value;
                  final logoScale = t < 0.14
                      ? (0.88 + 0.12 * Curves.easeOutCubic.transform(t / 0.14))
                      : 1.0;
                  final logoOffset = _computeLogoOffset(t);
                  final wordmarkOffset = _computeWordmarkOffset(t);
                  final loaderOpacity = t <= 0.86
                      ? 0.0
                      : Curves.easeOut
                          .transform(((t - 0.86) / 0.14).clamp(0.0, 1.0));

                  return ColoredBox(
                    color: colors.background,
                  child: Center(
                    child: SizedBox(
                      width: 280,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Staggered per-letter "BizFlow" wordmark
                          Transform.translate(
                            offset: wordmarkOffset,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_brandName.length, (i) {
                                final start = 0.16 + (i * 0.045);
                                final end = (start + 0.18).clamp(0.0, 1.0);
                                final charP = Curves.easeOutCubic.transform(
                                  ((t - start) / (end - start)).clamp(0.0, 1.0),
                                );
                                return Opacity(
                                  opacity: charP,
                                  child: Transform.translate(
                                    offset: Offset(
                                      -6.0 * (1.0 - charP),
                                      5.0 * (1.0 - charP),
                                    ),
                                    child: Transform.scale(
                                      scale: 0.86 + (0.14 * charP),
                                      child: Text(
                                        _brandName[i],
                                        style: TextStyle(
                                          fontSize: 27,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.7,
                                          color: colors.textPrimary,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          // 2. Persistent preloaded Logo (never flickers or disappears)
                          Transform.translate(
                            offset: logoOffset,
                            child: Transform.scale(
                              scale: logoScale,
                              child: Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: colors.border,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.ink.withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(21),
                                  child: widget.logoBytes != null
                                      ? Image.memory(
                                          widget.logoBytes!,
                                          width: 78,
                                          height: 78,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                        )
                                      : Image.asset(
                                          'assets/images/logo.png',
                                          width: 78,
                                          height: 78,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                        ),
                                ),
                              ),
                            ),
                          ),

                          // 3. Loading bar directly underneath "BizFlow"
                          if (loaderOpacity > 0.001)
                            Transform.translate(
                              offset: const Offset(0, 58),
                              child: Opacity(
                                opacity: loaderOpacity,
                                child: SizedBox(
                                  width: 54,
                                  height: 3.5,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      backgroundColor: colors.border,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ),
      ],
    );
  }
}
