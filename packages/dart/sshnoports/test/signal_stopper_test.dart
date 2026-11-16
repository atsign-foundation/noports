import 'dart:async';
import 'dart:io';

import 'package:sshnoports/src/signal_stopper.dart';
import 'package:test/test.dart';

void main() {
  late List<int> exits;
  late SignalStopper stopper;

  setUp(() {
    exits = [];
    stopper = SignalStopper(exit: exits.add, log: (_) {});
  });

  test('The first signal stops srvd gracefully and the second exits at once',
      () async {
    final stopping = Completer<void>();
    int stops = 0;
    stopper.stop = () {
      stops++;
      return stopping.future;
    };

    final first = stopper.handle(ProcessSignal.sigterm);
    await pumpEventQueue();

    expect(stops, 1);
    expect(exits, isEmpty, reason: 'the first signal waits for the stop');
    await stopper.handle(ProcessSignal.sigterm);
    expect(exits, [1], reason: 'the second signal exits at once');
    expect(stops, 1, reason: 'the second signal starts no stop of its own');
    stopping.complete();
    await first;
    expect(exits, [1, 0], reason: 'the first exits once its stop is done');
  });

  test('A signal before there is anything to stop exits at once', () async {
    await stopper.handle(ProcessSignal.sigint);

    expect(exits, [1]);
  });

  test('A stop that fails still exits', () async {
    final logged = <String>[];
    stopper = SignalStopper(exit: exits.add, log: logged.add)
      ..stop = () async => throw StateError('broken');

    await stopper.handle(ProcessSignal.sigterm);

    expect(exits, [0]);
    expect(logged.where((m) => m.contains('broken')), hasLength(1));
  });
}
