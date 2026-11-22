import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Placeholder route widget shown under [AppSplashScreen] while the
/// startup animation is playing so destination screens (/home or /login) do not
/// cause jank or premature rendering.
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

/// Backward compatibility alias.
typedef AppStartupSplash = AppSplashScreen;

/// Seamless startup splash screen.
///
/// Matches Android native `launch_background.xml` (background `#F3F7F6` and centered
/// 78x78 logo) with 0ms visual jump, runs smoothly for exactly 2.5 seconds,
/// and then gracefully transitions to the destination screen.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({
    super.key,
    required this.child,
    required this.router,
    this.preloadFuture,
  });

  final Widget child;
  final GoRouter router;
  final Future<void>? preloadFuture;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with TickerProviderStateMixin {
  static const String _brandName = 'BizFlow';
  static const Duration _kTotalSplashDuration = Duration(milliseconds: 2500);

  late final AnimationController _animCtrl;
  late final AnimationController _exitCtrl;

  bool _exiting = false;
  bool _dismissed = kIsWeb;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: _kTotalSplashDuration,
    );

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    if (!kIsWeb) {
      _animCtrl.forward();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runStartupSequence();
    });
  }

  Future<void> _runStartupSequence() async {
    if (kIsWeb) {
      await (widget.preloadFuture ?? _prepareAppData());
      _startBackgroundServices();
      return;
    }

    // Run parallel: the exact 2.5s splash animation and data preload.
    final timerFuture = Future<void>.delayed(_kTotalSplashDuration);
    final dataFuture = (widget.preloadFuture ?? _prepareAppData()).timeout(
      const Duration(milliseconds: 2200),
      onTimeout: () {},
    );

    await Future.wait([timerFuture, dataFuture]);
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
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await finance.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await orders.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await debts.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await customers.hydrateFromCache();
      }());
    }

    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 200),
      () => ApiClient.instance.startKeepAlive(),
    ));
    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 400),
      () => NotificationService.instance.init(),
    ));
  }

  void _triggerExit() {
    if (_dismissed || _exiting) return;
    setState(() => _exiting = true);
    _exitCtrl.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _dismissed = true);
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return widget.child;
    }

    final colors = context.appColors;

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
              CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
            ),
            child: RepaintBoundary(
              child: ColoredBox(
                color: colors.background,
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    final t = _animCtrl.value;

                    // Timeline:
                    // 0.00..0.22 (0 - 550ms): Logo stays perfectly centered at (0, 0)
                    //   matching Android native splash with zero visual shift.
                    // 0.22..0.48 (550 - 1200ms): Logo smoothly glides up to (0, -42)
                    //   while "BizFlow" letters fade in and glide down to (0, 32).
                    // 0.48..0.88 (1200 - 2200ms): Subtle loader progress bar pulses.
                    // 0.88..1.00 (2200 - 2500ms): Steady hold before smooth exit.

                    Offset logoOffset;
                    if (t <= 0.22) {
                      logoOffset = Offset.zero;
                    } else if (t <= 0.48) {
                      final p = Curves.easeInOutCubic.transform(
                        (t - 0.22) / 0.26,
                      );
                      logoOffset = Offset(0.0, -42.0 * p);
                    } else {
                      logoOffset = const Offset(0.0, -42.0);
                    }

                    final wordmarkOpacity = t <= 0.24
                        ? 0.0
                        : Curves.easeOut.transform(
                            ((t - 0.24) / 0.22).clamp(0.0, 1.0),
                          );

                    final wordmarkOffset = t <= 0.24
                        ? const Offset(0.0, 16.0)
                        : Offset(
                            0.0,
                            32.0 - (16.0 * (1.0 - wordmarkOpacity)),
                          );

                    final loaderOpacity = t <= 0.42
                        ? 0.0
                        : Curves.easeOut.transform(
                            ((t - 0.42) / 0.12).clamp(0.0, 1.0),
                          );

                    // Loader wave cycle
                    final loaderCycle = ((t * 2500) % 800) / 800.0;
                    final slideProgress =
                        Curves.easeInOutCubic.transform(loaderCycle);

                    return Center(
                      child: SizedBox(
                        width: 280,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. "BizFlow" Brand Title
                            if (wordmarkOpacity > 0.001)
                              Transform.translate(
                                offset: wordmarkOffset,
                                child: Opacity(
                                  opacity: wordmarkOpacity,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children:
                                        List.generate(_brandName.length, (i) {
                                      final start = 0.24 + (i * 0.025);
                                      final end =
                                          (start + 0.12).clamp(0.0, 1.0);
                                      final charP = Curves.easeOutCubic
                                          .transform(
                                            ((t - start) / (end - start))
                                                .clamp(0.0, 1.0),
                                          );
                                      return Transform.translate(
                                        offset: Offset(
                                          0.0,
                                          4.0 * (1.0 - charP),
                                        ),
                                        child: Text(
                                          _brandName[i],
                                          style: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: colors.textPrimary
                                                .withValues(alpha: charP),
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),

                            // 2. Logo Card (Identical 78x78 dp centered logo)
                            Transform.translate(
                              offset: logoOffset,
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
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 78,
                                    height: 78,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),

                            // 3. Elegant animated loading bar
                            if (loaderOpacity > 0.001)
                              Transform.translate(
                                offset: const Offset(0.0, 68.0),
                                child: Opacity(
                                  opacity: loaderOpacity,
                                  child: SizedBox(
                                    width: 56,
                                    height: 3.5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: ColoredBox(
                                        color: colors.border,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Transform.translate(
                                            offset: Offset(
                                              -20.0 + (76.0 * slideProgress),
                                              0,
                                            ),
                                            child: Container(
                                              width: 26,
                                              height: 3.5,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
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
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
