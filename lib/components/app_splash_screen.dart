import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/customer_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/order_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

/// Instant in-memory logo bytes (3.5 KB) decoded in ~2ms before `runApp()`
/// so Frame 1 of [AppStartupSplash] always has a GPU-ready [ui.Image]
/// with zero disk/asset latency and zero white-frame delay.
final Uint8List kEmbeddedSplashLogoBytes = base64Decode(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAQDAwQDAwQEAwQFBAQFBgoHBgYGBg0JCggKDw0QEA8N'
  'Dw4RExgUERIXEg4PFRwVFxkZGxsbEBQdHx0aHxgaGxr/2wBDAQQFBQYFBgwHBwwaEQ8RGhoaGhoa'
  'GhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhr/wAARCACcAJwDASIA'
  'AhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQA'
  'AAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3'
  'ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWm'
  'p6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEA'
  'AwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSEx'
  'BhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElK'
  'U1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3'
  'uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD7+ooo'
  'oAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiig'
  'AooooAKKKKACiiigAooooAKKKKACiiigApCcDmlrP1C7ECHmqjFydkJuxPLepF1IqqdXiB6181fF'
  'v9o6Lwhq82jeH7WPU9Qh4uJJHIihb+5gcs3ryAK8km/an8VE5Gn6YP8AgEn/AMVX1eH4dxNamptW'
  'T7nnTxtOMuW594DWIj/EKkXVIWP3hXwA37WPiiBsy6Zpkqj+ECRf13V2fg39qe38QXMdlewJp2pS'
  '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'
  'KKACiiigAooooA//9k=',
);

/// Placeholder route widget shown under [AppStartupSplash] while the
/// startup animation is playing so heavy screens (/home or /login) do not
/// mount or drop frames during the animation.
class AppSplashWaitScreen extends StatelessWidget {
  const AppSplashWaitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).extension<AppSemanticColors>()?.background ??
          AppColors.lightBackground,
      child: const SizedBox.expand(),
    );
  }
}

/// Animated startup splash screen for native builds (Android / iOS / Desktop).
///
/// Driven by a custom delta-clamped [Ticker] and [AnimationBehavior.preserve]
/// so the animation ALWAYS plays smoothly frame-by-frame even when Android
/// Battery Saver / Accessibility `disableAnimations` is active.
class AppStartupSplash extends StatefulWidget {
  const AppStartupSplash({
    super.key,
    required this.child,
    required this.router,
    this.initialLogoImage,
    this.preloadFuture,
  });

  final Widget child;
  final GoRouter router;
  final ui.Image? initialLogoImage;
  final Future<void>? preloadFuture;

  @override
  State<AppStartupSplash> createState() => _AppStartupSplashState();
}

class _AppStartupSplashState extends State<AppStartupSplash>
    with TickerProviderStateMixin {
  static const String _brandName = 'BizFlow';

  // Fast, crisp timeline (~1.25s total):
  // 0..110ms:    Crisp logo entrance at center (0, 0)
  // 110..520ms:  Logo glides right (+68, 0) while "BizFlow" letters reveal left-to-right
  // 520..920ms:  Logo sweeps above "BizFlow" to (0, -52) while "BizFlow" centers at (0, +22)
  // 780..1250ms: Sliding progress bar animates below "BizFlow" at (0, +58)
  static const double _kIntroDurationMs = 1250.0;
  static const double _kLoaderPeriodMs = 700.0;
  static const double _kMaxFrameStepMs = 45.0;

  Ticker? _ticker;
  Duration? _lastTick;
  double _elapsedMs = 0.0;

  AnimationController? _exitCtrl;
  final Completer<void> _introCompleter = Completer<void>();

  ui.Image? _decodedLogo;

  bool _exiting = false;
  bool _dismissed = kIsWeb;

  @override
  void initState() {
    super.initState();
    _decodedLogo = widget.initialLogoImage;

    if (!kIsWeb) {
      _exitCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
        animationBehavior: AnimationBehavior.preserve,
      );

      // Start the animation ticker immediately in initState so frame 1 is already live.
      _ticker = createTicker(_onTick)..start();
      _upgradeToHighResLogo();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runStartupSequence();
    });
  }

  void _onTick(Duration now) {
    if (_lastTick == null) {
      _lastTick = now;
      _elapsedMs += 16.0;
    } else {
      final rawDeltaMs = (now - _lastTick!).inMicroseconds / 1000.0;
      _lastTick = now;
      _elapsedMs += rawDeltaMs.clamp(0.0, _kMaxFrameStepMs);
    }

    if (_elapsedMs >= _kIntroDurationMs && !_introCompleter.isCompleted) {
      _introCompleter.complete();
    }

    if (mounted && !_dismissed) {
      setState(() {});
    }
  }

  Future<void> _upgradeToHighResLogo() async {
    if (kIsWeb) return;
    try {
      // If initialLogoImage was not pre-decoded yet, decode embedded bytes first (~2ms)
      if (_decodedLogo == null) {
        final quickCodec =
            await ui.instantiateImageCodec(kEmbeddedSplashLogoBytes);
        final quickFrame = await quickCodec.getNextFrame();
        if (mounted && _decodedLogo == null) {
          setState(() => _decodedLogo = quickFrame.image);
        }
      }
      // Then upgrade to high-res asset logo seamlessly
      final bd = await rootBundle.load('assets/images/logo.png');
      final codec = await ui.instantiateImageCodec(
        bd.buffer.asUint8List(),
        targetWidth: 240,
        targetHeight: 240,
      );
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _decodedLogo = frame.image);
      }
    } catch (_) {}
  }

  Future<void> _runStartupSequence() async {
    if (kIsWeb) {
      await (widget.preloadFuture ?? _prepareAppData());
      _startBackgroundServices();
      return;
    }

    final dataFuture = (widget.preloadFuture ?? _prepareAppData()).timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () {},
    );

    await Future.wait([_introCompleter.future, dataFuture]);
    if (!mounted) return;

    final settings = context.read<SettingsProvider>();
    final targetRoute = settings.isOnboardingDone ? '/home' : '/login';
    widget.router.go(targetRoute);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerExit();
      _startBackgroundServices();
    });
  }

  Future<void> _prepareAppData() async {
    final settings = context.read<SettingsProvider>();
    final dashboard = context.read<DashboardProvider>();

    if (settings.isLoading) {
      await settings.init(skipRemoteSync: true);
    }
    if (!mounted) return;

    if (settings.isOnboardingDone) {
      await dashboard.hydrateFromCache();
    }
  }

  void _startBackgroundServices() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final finance = context.read<FinanceProvider>();
    final orders = context.read<OrderProvider>();
    final debts = context.read<DebtProvider>();
    final customers = context.read<CustomerProvider>();

    if (settings.isOnboardingDone) {
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await finance.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await orders.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await debts.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await customers.hydrateFromCache();
      }());
    }

    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 300),
      () => ApiClient.instance.startKeepAlive(),
    ));
    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 600),
      () => NotificationService.instance.init(),
    ));
  }

  void _triggerExit() {
    if (_dismissed || _exiting) return;
    setState(() => _exiting = true);
    _exitCtrl?.forward().whenComplete(() {
      if (!mounted) return;
      _ticker?.stop();
      setState(() => _dismissed = true);
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _exitCtrl?.dispose();
    super.dispose();
  }

  Offset _computeLogoOffset(double t) {
    if (t <= 0.08) {
      return Offset.zero;
    } else if (t <= 0.42) {
      final p = Curves.easeInOutCubic.transform((t - 0.08) / 0.34);
      return Offset(68.0 * p, 0.0);
    } else if (t <= 0.74) {
      final raw = ((t - 0.42) / 0.32).clamp(0.0, 1.0);
      final p = Curves.easeInOutCubic.transform(raw);
      return Offset(68.0 * (1.0 - p), -52.0 * p);
    } else {
      return const Offset(0.0, -52.0);
    }
  }

  Offset _computeWordmarkOffset(double t) {
    if (t <= 0.42) {
      return const Offset(-38.0, 0.0);
    } else if (t <= 0.74) {
      final raw = ((t - 0.42) / 0.32).clamp(0.0, 1.0);
      final p = Curves.easeInOutCubic.transform(raw);
      return Offset(-38.0 * (1.0 - p), 22.0 * p);
    } else {
      return const Offset(0.0, 22.0);
    }
  }

  Widget _buildLogoVisual() {
    if (_decodedLogo != null) {
      return RawImage(
        image: _decodedLogo,
        width: 78,
        height: 78,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }
    return Image.memory(
      kEmbeddedSplashLogoBytes,
      width: 78,
      height: 78,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return widget.child;
    }

    final colors = context.appColors;
    final exitCtrl = _exitCtrl!;

    final t = (_elapsedMs / _kIntroDurationMs).clamp(0.0, 1.0);
    final logoScale = t < 0.08
        ? (0.92 + 0.08 * Curves.easeOutCubic.transform(t / 0.08))
        : 1.0;
    final logoOffset = _computeLogoOffset(t);
    final wordmarkOffset = _computeWordmarkOffset(t);
    final loaderOpacity = t <= 0.62
        ? 0.0
        : Curves.easeOut.transform(((t - 0.62) / 0.12).clamp(0.0, 1.0));

    final loaderElapsed = (_elapsedMs - (_kIntroDurationMs * 0.58)).clamp(
      0.0,
      double.infinity,
    );
    final loaderCycle = (loaderElapsed % _kLoaderPeriodMs) / _kLoaderPeriodMs;
    final slideProgress = Curves.easeInOutCubic.transform(loaderCycle);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            ignoring: !_exiting,
            child: widget.child,
          ),
        ),
        AbsorbPointer(
          absorbing: !_exiting,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(parent: exitCtrl, curve: Curves.easeOutCubic),
            ),
            child: RepaintBoundary(
              child: ColoredBox(
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
                              final start = 0.10 + (i * 0.036);
                              final end = (start + 0.14).clamp(0.0, 1.0);
                              final charP = Curves.easeOutCubic.transform(
                                ((t - start) / (end - start)).clamp(0.0, 1.0),
                              );
                              return Transform.translate(
                                offset: Offset(
                                  -6.0 * (1.0 - charP),
                                  5.0 * (1.0 - charP),
                                ),
                                child: Transform.scale(
                                  scale: 0.86 + (0.14 * charP),
                                  child: Text(
                                    _brandName[i],
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.7,
                                      color: colors.textPrimary
                                          .withValues(alpha: charP),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        // 2. Always-visible synchronous Logo card
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
                                    blurRadius: 18,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(21),
                                child: _buildLogoVisual(),
                              ),
                            ),
                          ),
                        ),

                        // 3. Sliding progress bar underneath "BizFlow"
                        if (loaderOpacity > 0.001)
                          Transform.translate(
                            offset: const Offset(0, 58),
                            child: SizedBox(
                              width: 54,
                              height: 3.5,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: ColoredBox(
                                  color: colors.border
                                      .withValues(alpha: loaderOpacity),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Transform.translate(
                                      offset: Offset(
                                        -20.0 + (74.0 * slideProgress),
                                        0,
                                      ),
                                      child: Container(
                                        width: 28,
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: loaderOpacity),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}
