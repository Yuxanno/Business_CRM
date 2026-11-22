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

/// Animated startup splash screen for native builds (Android / iOS / Desktop).
/// Runs heavy initialization & cache hydration in parallel with the intro
/// animation and transitions to the main screen immediately once both are ready.
class AppStartupSplash extends StatefulWidget {
  const AppStartupSplash({
    super.key,
    required this.child,
    this.router,
    this.logoBytes,
  });

  final Widget child;
  final GoRouter? router;
  final Uint8List? logoBytes;

  @override
  State<AppStartupSplash> createState() => _AppStartupSplashState();
}

class _AppStartupSplashState extends State<AppStartupSplash>
    with TickerProviderStateMixin {
  static const String _brandName = 'BizFlow';

  AnimationController? _introCtrl;
  AnimationController? _exitCtrl;

  bool _exiting = false;
  bool _dismissed = kIsWeb;
  bool _precached = false;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _introCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 950),
      );
      _exitCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
    }

    // Start initialization & animation immediately on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runStartupSequence();
    });
  }

  Future<void> _runStartupSequence() async {
    final initFuture = _initializeApp();

    if (kIsWeb) {
      await initFuture;
      return;
    }

    final introFuture = _introCtrl!.forward().orCancel.catchError((_) {});
    await Future.wait([introFuture, initFuture]);

    if (!mounted) return;
    _triggerExit();
  }

  Future<void> _initializeApp() async {
    final settings = context.read<SettingsProvider>();
    final dashboard = context.read<DashboardProvider>();
    final finance = context.read<FinanceProvider>();
    final orders = context.read<OrderProvider>();
    final debts = context.read<DebtProvider>();
    final customers = context.read<CustomerProvider>();

    await settings.init(skipRemoteSync: true);
    if (!mounted) return;

    final targetRoute = settings.isOnboardingDone ? '/home' : '/login';
    widget.router?.go(targetRoute);

    if (settings.isOnboardingDone) {
      // Hydrate dashboard cache first so Home has instant data when revealed.
      await dashboard.hydrateFromCache();

      // Hydrate secondary tabs & start background services without blocking exit.
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await finance.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await orders.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await debts.hydrateFromCache();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await customers.hydrateFromCache();
      }());
    }

    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 600),
      () => ApiClient.instance.startKeepAlive(),
    ));
    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 1000),
      () => NotificationService.instance.init(),
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached && !kIsWeb && widget.logoBytes == null) {
      _precached = true;
      precacheImage(const AssetImage('assets/images/logo.png'), context);
    }
  }

  @override
  void dispose() {
    _introCtrl?.dispose();
    _exitCtrl?.dispose();
    super.dispose();
  }

  void _triggerExit() {
    if (_dismissed || _exiting) return;
    _exiting = true;
    _exitCtrl?.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _dismissed = true);
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

    final colors = context.appColors;
    final introCtrl = _introCtrl!;
    final exitCtrl = _exitCtrl!;

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
                            // 1. Staggered per-letter "BizFlow" wordmark (no Opacity saveLayer)
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

                            // 2. Persistent preloaded Logo
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
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
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
                                            cacheWidth: 180,
                                            cacheHeight: 180,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                          )
                                        : Image.asset(
                                            'assets/images/logo.png',
                                            width: 78,
                                            height: 78,
                                            cacheWidth: 180,
                                            cacheHeight: 180,
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
                                child: SizedBox(
                                  width: 54,
                                  height: 3.5,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      backgroundColor: colors.border
                                          .withValues(alpha: loaderOpacity),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary
                                            .withValues(alpha: loaderOpacity),
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
