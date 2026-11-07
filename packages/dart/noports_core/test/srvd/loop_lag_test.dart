import 'dart:async';

import 'package:noports_core/src/srvd/loop_lag.dart';
import 'package:test/test.dart';

double _maxMs(String report) =>
    double.parse(RegExp(r'max ([0-9.]+) ms').firstMatch(report)!.group(1)!);

void main() {
  test('reports the lateness of a blocked event loop', () async {
    final List<String> reports = [];
    final LoopLagProbe probe = LoopLagProbe(
      reportEvery: const Duration(milliseconds: 300),
      onReport: reports.add,
    )..start();
    addTearDown(probe.stop);

    await Future<void>.delayed(const Duration(milliseconds: 320));
    final Stopwatch busy = Stopwatch()..start();
    while (busy.elapsedMilliseconds < 150) {}
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(reports, hasLength(greaterThanOrEqualTo(2)));
    expect(reports.first, matches(RegExp(r'^loop lag over \d+ ticks: p50 ')));
    expect(_maxMs(reports.first), lessThan(100),
        reason: 'the control: an idle loop is not late by 100 ms');
    expect(reports.skip(1).map(_maxMs).reduce((a, b) => a > b ? a : b),
        greaterThan(100), reason: 'the 150 ms block shows as lag');
  });
}
