import 'dart:async';
import 'dart:math';

/// Measures how late a periodic timer fires on this isolate's event loop and
/// reports the p50, p99 and largest lateness every [reportEvery].
class LoopLagProbe {
  LoopLagProbe({
    required this.reportEvery,
    required this.onReport,
    this.tick = const Duration(milliseconds: 10),
  });

  final Duration reportEvery;
  final Duration tick;
  final void Function(String report) onReport;

  final List<int> _lagMicros = [];
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;
  Timer? _reporter;
  int _expected = 0;

  /// Starts ticking and reporting.
  void start() {
    _clock.start();
    _expected = tick.inMicroseconds;
    _ticker = Timer.periodic(tick, (_) {
      final int now = _clock.elapsedMicroseconds;
      _lagMicros.add(max(0, now - _expected));
      _expected = now + tick.inMicroseconds;
    });
    _reporter = Timer.periodic(reportEvery, (_) => _report());
  }

  /// Stops ticking and reporting.
  void stop() {
    _ticker?.cancel();
    _reporter?.cancel();
  }

  void _report() {
    if (_lagMicros.isEmpty) return;
    final List<int> sorted = List.of(_lagMicros)..sort();
    _lagMicros.clear();
    int at(double q) => sorted[min(sorted.length - 1, (q * sorted.length).floor())];
    String ms(int micros) => (micros / 1000).toStringAsFixed(2);
    onReport('loop lag over ${sorted.length} ticks: p50 ${ms(at(0.5))} ms,'
        ' p99 ${ms(at(0.99))} ms, max ${ms(sorted.last)} ms');
  }
}
