import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/auth/auth_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Destination screen after the cold-start splash finishes.
enum SplashTarget { login, home }

/// Optional home-finale variant: when `true`, the BF chip flies and lands
/// onto the top-left square avatar on the Home screen instead of dissolving in place.
const bool kHomeAvatarLanding = false;

/// Brand-aligned animated startup splash with two finales depending on [target]:
/// - [SplashTarget.login] (2500–3500 ms): `plate` shrinks & dissolves while `chip`
///   and `word` fly onto [loginLogoKey] and [loginWordKey] in the login header.
/// - [SplashTarget.home] (2500–2900 ms): `plate`, `chip`, and `word` scale down
///   slightly (`1.0 → 0.94`) and crossfade into the Home screen (or fly onto
///   [homeAvatarKey] when [kHomeAvatarLanding] is enabled).
class BrandSplash extends StatefulWidget {
  const BrandSplash({
    super.key,
    required this.target,
    required this.onFinished,
    required this.loginLogoKey,
    required this.loginWordKey,
    this.homeAvatarKey,
  });

  final ValueListenable<SplashTarget?> target;
  final VoidCallback onFinished;
  final GlobalKey loginLogoKey;
  final GlobalKey loginWordKey;
  final GlobalKey? homeAvatarKey;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  // Normalized timeline base: 3500 ms = 1.0
  static const int _kBaseMs = 3500;
  static const Duration _kControllerDuration = Duration(milliseconds: _kBaseMs);
  static const Duration _kReducedDuration = Duration(milliseconds: 400);
  static const Duration _kSkipDuration = Duration(milliseconds: 200);

  // Common phase milestones (in normalized 0..1 controller units)
  static const double _t500 = 500 / _kBaseMs;
  static const double _t600 = 600 / _kBaseMs;
  static const double _t1500 = 1500 / _kBaseMs;
  static const double _t1650 = 1650 / _kBaseMs;
  static const double _t2450 = 2450 / _kBaseMs;
  static const double _t2500 = 2500 / _kBaseMs;
  static const double _t2900 = 2900 / _kBaseMs;

  // Initial geometry matching native splash 1:1
  static const double _kChipInitialSize = 130.0;
  static const double _kChipInitialRadius = 30.0;
  static const double _kChipInitialInset = 18.0; // 130 - 36 = 94dp inner logo
  static const double _kLockupExpandedWidth = 284.0;
  static const double _kWordCenterScale = 1.65;

  late final AnimationController _controller;

  ImageStream? _logoStream;
  ImageStreamListener? _logoListener;
  bool _firstFrameDeferred = false;
  bool _firstFrameAllowed = false;
  bool _started = false;
  bool _holdingForTarget = false;
  bool _skipping = false;
  bool _finished = false;
  bool _disableAnimations = false;

  Rect? _cachedLoginLogoRect;
  Rect? _cachedLoginWordRect;
  Rect? _cachedHomeAvatarRect;

  @override
  void initState() {
    super.initState();

    // Hide the real login header brand row while BrandSplash is active so there
    // is never a duplicate logo/wordmark during the login crossfade & flight.
    AuthHeader.brandVisible.value = false;

    _controller = AnimationController(
      vsync: this,
      duration: _kControllerDuration,
    )
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);

    widget.target.addListener(_onTargetChanged);
    _warmUpLogoAndStart();
  }

  /// Resolves `assets/images/logo.png` before releasing Flutter's first frame
  /// so Frame 1 matches the native splash without a missing-image blink.
  void _warmUpLogoAndStart() {
    final binding = WidgetsBinding.instance;
    binding.deferFirstFrame();
    _firstFrameDeferred = true;

    const provider = AssetImage('assets/images/logo.png');
    final stream = provider.resolve(ImageConfiguration.empty);
    _logoStream = stream;
    _logoListener = ImageStreamListener(
      (_, _) => _releaseFirstFrameAndStart(),
      onError: (_, _) => _releaseFirstFrameAndStart(),
    );
    stream.addListener(_logoListener!);
  }

  void _releaseFirstFrameAndStart() {
    if (_logoListener != null && _logoStream != null) {
      _logoStream!.removeListener(_logoListener!);
      _logoListener = null;
      _logoStream = null;
    }
    if (_firstFrameDeferred && !_firstFrameAllowed) {
      _firstFrameAllowed = true;
      WidgetsBinding.instance.allowFirstFrame();
    }
    if (!mounted || _started) return;
    _started = true;
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable != _disableAnimations) {
      _disableAnimations = disable;
      _controller.duration =
          disable ? _kReducedDuration : _kControllerDuration;
      if (_started && _controller.isAnimating) {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant BrandSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      oldWidget.target.removeListener(_onTargetChanged);
      widget.target.addListener(_onTargetChanged);
      _onTargetChanged();
    }
  }

  double get _endThreshold {
    if (_disableAnimations) return 1.0;
    return widget.target.value == SplashTarget.home ? _t2900 : 1.0;
  }

  void _onTargetChanged() {
    final t = widget.target.value;
    if (t == null || _finished) return;

    if (t != SplashTarget.login) {
      AuthHeader.brandVisible.value = true;
    }

    if (_holdingForTarget) {
      _holdingForTarget = false;
      if (_skipping) {
        _animateFastTo(_endThreshold);
      } else {
        _controller.forward();
      }
    } else if (_controller.value >= _endThreshold - 0.001) {
      _completeSplash();
    }
  }

  void _onTick() {
    if (_finished) return;

    final t = widget.target.value;

    if (_disableAnimations) {
      if (_controller.value >= 1.0) {
        if (t != null) {
          _completeSplash();
        } else if (!_holdingForTarget) {
          _holdingForTarget = true;
          _controller.stop();
        }
      }
      return;
    }

    // Hold at 2450 ms if target is still unknown so we never show an empty screen.
    if (t == null && !_holdingForTarget && _controller.value >= _t2450) {
      _holdingForTarget = true;
      _controller.stop();
      _controller.value = _t2450;
      return;
    }

    // For Home target, the finale finishes at 2900 ms (_t2900).
    if (t == SplashTarget.home && _controller.value >= _t2900) {
      _controller.stop();
      _controller.value = _t2900;
      _completeSplash();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.target.value != null) {
      _completeSplash();
    }
  }

  void _animateFastTo(double targetValue) {
    _controller
        .animateTo(
          targetValue,
          duration: _kSkipDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
      if (mounted &&
          !_finished &&
          widget.target.value != null &&
          _controller.value >= targetValue - 0.001) {
        _completeSplash();
      }
    });
  }

  void _handleTap() {
    if (_finished || _disableAnimations) return;
    _skipping = true;
    final t = widget.target.value;
    if (t != null) {
      _holdingForTarget = false;
      _animateFastTo(_endThreshold);
    } else if (_controller.value < _t2450) {
      _controller.animateTo(
        _t2450,
        duration: _kSkipDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _completeSplash() {
    if (_finished || !mounted) return;
    _finished = true;
    AuthHeader.brandVisible.value = true;
    widget.onFinished();
  }

  Rect? _measureKeyRect(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final renderObj = ctx.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return null;
    final splashObj = context.findRenderObject();
    final topLeft = renderObj.localToGlobal(
      Offset.zero,
      ancestor: splashObj is RenderBox ? splashObj : null,
    );
    return topLeft & renderObj.size;
  }

  void _refreshTargetRectsIfNeeded(SplashTarget? target) {
    if (target == SplashTarget.login) {
      _cachedLoginLogoRect =
          _measureKeyRect(widget.loginLogoKey) ?? _cachedLoginLogoRect;
      _cachedLoginWordRect =
          _measureKeyRect(widget.loginWordKey) ?? _cachedLoginWordRect;
    } else if (target == SplashTarget.home && kHomeAvatarLanding) {
      _cachedHomeAvatarRect =
          _measureKeyRect(widget.homeAvatarKey) ?? _cachedHomeAvatarRect;
    }
  }

  double _interval(double begin, double end, Curve curve) {
    final v = ((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  @override
  void dispose() {
    widget.target.removeListener(_onTargetChanged);
    if (_logoListener != null && _logoStream != null) {
      _logoStream!.removeListener(_logoListener!);
      _logoListener = null;
      _logoStream = null;
    }
    if (_firstFrameDeferred && !_firstFrameAllowed) {
      _firstFrameAllowed = true;
      WidgetsBinding.instance.allowFirstFrame();
    }
    AuthHeader.brandVisible.value = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final cx = screenSize.width / 2;
    final cy = screenSize.height / 2;
    final baseBodyStyle = AppTheme.light.textTheme.bodyMedium;
    final wordBaseStyle = (baseBodyStyle?.merge(AuthHeader.brandWordStyle) ??
            AuthHeader.brandWordStyle)
        .copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.none,
    );

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, logoImageChild) {
            final currentTarget = widget.target.value;

            // Reduced-motion mode (MediaQuery.disableAnimationsOf(context)):
            // Static 130dp rounded square for 400 ms, then immediate transition.
            if (_disableAnimations) {
              return ColoredBox(
                color: AppColors.lightBackground,
                child: Center(
                  child: _buildChipBox(
                    size: _kChipInitialSize,
                    radius: _kChipInitialRadius,
                    inset: _kChipInitialInset,
                    borderOpacity: 0.0,
                    shadowOpacity: 0.0,
                    logoChild: logoImageChild!,
                  ),
                ),
              );
            }

            // 0–600 ms: soft fade-in of pale teal background spots matching AuthBackdrop
            final spotsFade = _interval(0.0, _t600, Curves.easeOutCubic);

            // 0–500 ms: single expanding teal ring around the 130dp rounded square
            final ringProgress = _interval(0.0, _t500, Curves.easeOutCubic);
            final ringScale = lerpDouble(1.0, 1.45, ringProgress)!;
            final ringOpacity =
                _controller.value <= _t500 ? 0.5 * (1.0 - ringProgress) : 0.0;

            // 500–1500 ms: chip shifts left, word emerges smoothly as chip moves
            final expandP = _interval(_t500, _t1500, Curves.easeInOutCubic);
            final wordRevealP = _interval(
              680 / _kBaseMs,
              _t1500,
              Curves.easeOutCubic,
            );

            // 1650–2450 ms: single diagonal shimmer sweep across the chip
            final shimmerP = _interval(_t1650, _t2450, Curves.easeInOutCubic);
            final showShimmer =
                _controller.value >= _t1650 && _controller.value <= _t2450;

            // Base centered geometry (before 2500 ms finale)
            final lockupWidth = lerpDouble(
              _kChipInitialSize,
              _kLockupExpandedWidth,
              expandP,
            )!;
            final lockupLeft = cx - lockupWidth / 2;
            final baseChipCenter = Offset(
              lockupLeft + _kChipInitialSize / 2,
              cy,
            );
            // Word sits cleanly to the right of the shifted chip (centered in the remaining space)
            final baseWordCenter = Offset(
              cx + 74.0,
              cy,
            );

            // Finale state (2500 ms+)
            double backdropOpacity = 1.0;
            double groupScale = 1.0;
            double groupOpacity = 1.0;

            Rect chipRect = Rect.fromCenter(
              center: baseChipCenter,
              width: _kChipInitialSize,
              height: _kChipInitialSize,
            );
            double chipRadius = _kChipInitialRadius;
            double chipInset = _kChipInitialInset;
            // Border & soft shadow fade in smoothly after frame 1 (0–500 ms) so frame 1
            // is a pure white 130dp rounded square matching the native splash 1:1.
            double chipBorderAlpha = ringProgress;
            double chipShadowAlpha = 0.06 * ringProgress;

            Offset wordCenter = baseWordCenter;
            double wordScale = _kWordCenterScale;
            double wordOpacity = wordRevealP;
            double wordSlideDx = 14.0 * (1.0 - wordRevealP);
            // Clip word to the right of chip so it never protrudes behind/over chip at t=500ms.
            double wordMinX = chipRect.right + 14.0;

            if (_controller.value > _t2500 && currentTarget != null) {
              _refreshTargetRectsIfNeeded(currentTarget);

              if (currentTarget == SplashTarget.login) {
                // Login Finale (2500–3500 ms)
                final flightP =
                    _interval(_t2500, 1.0, Curves.easeInOutCubic);

                // Crossfade the splash backdrop out so LoginScreen appears underneath
                backdropOpacity = (1.0 - flightP).clamp(0.0, 1.0);
                wordMinX = 0.0;

                final targetLogoRect = _cachedLoginLogoRect;
                final targetWordRect = _cachedLoginWordRect;

                if (targetLogoRect != null && targetWordRect != null) {
                  // Fly chip & word directly onto AuthHeader's logoKey and wordKey
                  chipRect = Rect.lerp(chipRect, targetLogoRect, flightP)!;
                  chipRadius = lerpDouble(_kChipInitialRadius, 10.0, flightP)!;
                  chipInset = lerpDouble(_kChipInitialInset, 0.0, flightP)!;
                  chipBorderAlpha = 1.0;
                  chipShadowAlpha = 0.06;

                  wordCenter = Offset.lerp(
                    baseWordCenter,
                    targetWordRect.center,
                    flightP,
                  )!;
                  wordScale = lerpDouble(_kWordCenterScale, 1.0, flightP)!;
                  wordSlideDx = 0.0;
                  wordOpacity = 1.0;
                } else {
                  // Fallback when keys are unavailable: lift lockup up by ~262 dp with scale 0.5
                  final dyShift = -262.0 * flightP;
                  final fbScale = lerpDouble(1.0, 0.5, flightP)!;
                  chipRect = Rect.fromCenter(
                    center: Offset(
                      cx + (baseChipCenter.dx - cx) * fbScale,
                      cy + dyShift,
                    ),
                    width: _kChipInitialSize * fbScale,
                    height: _kChipInitialSize * fbScale,
                  );
                  chipRadius = _kChipInitialRadius * fbScale;
                  chipInset = _kChipInitialInset * fbScale;
                  wordCenter = Offset(
                    cx + (baseWordCenter.dx - cx) * fbScale,
                    cy + dyShift,
                  );
                  wordScale = _kWordCenterScale * fbScale;
                }
              } else {
                // Home Finale (2500–2900 ms, 400 ms crossfade)
                final homeP =
                    _interval(_t2500, _t2900, Curves.easeInOutCubic);
                wordMinX = 0.0;

                if (kHomeAvatarLanding && _cachedHomeAvatarRect != null) {
                  final targetAvatar = _cachedHomeAvatarRect!;
                  wordOpacity = (1.0 - homeP * 1.4).clamp(0.0, 1.0);
                  backdropOpacity = (1.0 - homeP).clamp(0.0, 1.0);

                  chipRect = Rect.lerp(chipRect, targetAvatar, homeP)!;
                  chipRadius =
                      lerpDouble(_kChipInitialRadius, 14.0, homeP)!;
                  chipInset = lerpDouble(_kChipInitialInset, 0.0, homeP)!;
                  groupOpacity = (1.0 - homeP * 0.85).clamp(0.0, 1.0);
                } else {
                  // Default Home Finale: chip & word scale 1.0 → 0.94 and dissolve (crossfade 400 ms)
                  groupScale = lerpDouble(1.0, 0.94, homeP)!;
                  groupOpacity = (1.0 - homeP).clamp(0.0, 1.0);
                  backdropOpacity = (1.0 - homeP).clamp(0.0, 1.0);
                }
              }
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background (#F3F7F6) + pale teal spots (600 ms fade-in matching AuthBackdrop)
                if (backdropOpacity > 0.001)
                  Opacity(
                    opacity: backdropOpacity,
                    child: ColoredBox(
                      color: AppColors.lightBackground,
                      child: Opacity(
                        opacity: spotsFade,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              top: -98,
                              right: -70,
                              child: Transform.rotate(
                                angle: 0.18,
                                child: Container(
                                  width: 270,
                                  height: 270,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(108),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 190,
                              left: -105,
                              child: Transform.rotate(
                                angle: -0.18,
                                child: Container(
                                  width: 210,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight
                                        .withValues(alpha: 0.11),
                                    borderRadius: BorderRadius.circular(72),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 2. Brand elements layer (ring, plate, word, chip)
                Opacity(
                  opacity: groupOpacity,
                  child: Transform.scale(
                    scale: groupScale,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 2a. Expanding teal ring (0–500 ms, opacity 0.5 → 0, scale 1 → 1.45)
                        if (ringOpacity > 0.001)
                          Positioned(
                            left: cx - _kChipInitialSize / 2,
                            top: cy - _kChipInitialSize / 2,
                            width: _kChipInitialSize,
                            height: _kChipInitialSize,
                            child: Transform.scale(
                              scale: ringScale,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    _kChipInitialRadius,
                                  ),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: ringOpacity),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // 2b. "BIZFLOW" wordmark (emerges cleanly to the right of chip as chip slides left)
                        if (wordOpacity > 0.001)
                          ClipRect(
                            clipper: _LeftEdgeClipper(wordMinX),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned(
                                  left: wordCenter.dx - 120,
                                  top: wordCenter.dy - 24,
                                  width: 240,
                                  height: 48,
                                  child: Center(
                                    child: Opacity(
                                      opacity: wordOpacity.clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(-wordSlideDx, 0),
                                        child: Transform.scale(
                                          scale: wordScale,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'BIZFLOW',
                                            maxLines: 1,
                                            softWrap: false,
                                            style: wordBaseStyle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 2c. White square chip with BF logo (130dp radius 30 at t=0, flies to loginLogoKey on login)
                        Positioned.fromRect(
                          rect: chipRect,
                          child: _buildChipBox(
                            size: chipRect.width,
                            radius: chipRadius,
                            inset: chipInset,
                            borderOpacity: chipBorderAlpha,
                            shadowOpacity: chipShadowAlpha,
                            logoChild: logoImageChild!,
                          ),
                        ),

                        // 2d. Diagonal shimmer pass (1650–2450 ms) over the standalone logo chip
                        if (showShimmer)
                          Positioned.fromRect(
                            rect: chipRect,
                            child: IgnorePointer(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(chipRadius),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        -1.6 + 3.2 * shimmerP - 0.55,
                                        -1.0,
                                      ),
                                      end: Alignment(
                                        -1.6 + 3.2 * shimmerP + 0.55,
                                        1.0,
                                      ),
                                      colors: [
                                        AppColors.primaryLight
                                            .withValues(alpha: 0.0),
                                        AppColors.primaryLight
                                            .withValues(alpha: 0.14),
                                        AppColors.lightSurface
                                            .withValues(alpha: 0.50),
                                        AppColors.primaryLight
                                            .withValues(alpha: 0.0),
                                      ],
                                      stops: const [
                                        0.0,
                                        0.45,
                                        0.55,
                                        1.0,
                                      ],
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
              ],
            );
          },
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  Widget _buildChipBox({
    required double size,
    required double radius,
    required double inset,
    required double borderOpacity,
    required double shadowOpacity,
    required Widget logoChild,
  }) {
    final innerRadius = (radius - inset * 0.45).clamp(1.0, radius);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(inset.clamp(0.0, size * 0.35)),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(radius),
        border: borderOpacity > 0.01
            ? Border.all(
                color: AppColors.lightBorder
                    .withValues(alpha: borderOpacity.clamp(0.0, 1.0)),
              )
            : null,
        boxShadow: shadowOpacity > 0.001
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: shadowOpacity),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: logoChild,
      ),
    );
  }
}

class _LeftEdgeClipper extends CustomClipper<Rect> {
  const _LeftEdgeClipper(this.minX);

  final double minX;

  @override
  Rect getClip(Size size) {
    final left = minX.clamp(0.0, size.width);
    return Rect.fromLTRB(left, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant _LeftEdgeClipper oldClipper) =>
      oldClipper.minX != minX;
}
