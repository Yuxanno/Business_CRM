import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Adaptive frame-rate and rendering quality controller.
/// Monitors frame timings via [SchedulerBinding] so devices that cannot sustain
/// 60 FPS automatically enter lightweight rendering mode (disabling heavy box
/// shadows, blur filters, and non-essential decorative animations) to maintain
/// a steady, responsive 30–60 FPS without overheating or overloading the CPU/GPU.
class PerformanceService {
  PerformanceService._();
  static final PerformanceService instance = PerformanceService._();

  final ValueNotifier<bool> lowEndMode = ValueNotifier<bool>(false);

  bool _started = false;
  int _slowFrames = 0;
  int _totalSampled = 0;

  bool get isLowEnd => lowEndMode.value;

  void startMonitoring() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (lowEndMode.value) return;
    for (final t in timings) {
      _totalSampled++;
      final totalMs = t.totalSpan.inMilliseconds;
      // Frame budget for 60Hz is ~16.6ms; >28ms means dropping below ~35 FPS.
      if (totalMs > 28) {
        _slowFrames++;
      }
    }
    if (_totalSampled >= 24) {
      if (_slowFrames >= 7) {
        lowEndMode.value = true;
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      } else if (_totalSampled >= 120) {
        // Device is comfortably holding 60 FPS; stop sampling overhead.
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      }
    }
  }
}
