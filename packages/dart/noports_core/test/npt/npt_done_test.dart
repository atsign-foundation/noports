import 'package:at_client/at_client.dart';
import 'package:noports_core/npt.dart';
import 'package:test/test.dart';

/// Minimal stand-in - these tests only exercise the startup failure path, so
/// the only calls that must succeed are the ones [NptBase]'s constructor makes.
class _FailingAtClient implements AtClient {
  AtClientPreference _preference = AtClientPreference()
    ..rootDomain = 'root.atsign.org';

  @override
  AtClientPreference? getPreferences() => _preference;

  @override
  void setPreferences(AtClientPreference preference) =>
      _preference = preference;

  @override
  String? getCurrentAtSign() => '@alice';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not available');
}

NptParams _params() => NptParams(
  clientAtSign: '@alice',
  sshnpdAtSign: '@device',
  srvdAtSign: '@rv_test',
  remoteHost: 'localhost',
  remotePort: 3389,
  device: 'test_device',
  inline: true,
  timeout: Duration(seconds: 1),
);

void main() {
  group('Npt.done completes on startup failure', () {
    /// Regression coverage for
    /// https://github.com/atsign-foundation/noports/issues/2789 - `done` used
    /// to be completed only on the success paths, so a caller which awaited it
    /// after a failed startup (as NoPorts Desktop does) waited forever.
    test('runInline which throws still completes done', () async {
      final npt = Npt.create(
        atClient: _FailingAtClient(),
        params: _params(),
      );

      await expectLater(npt.runInline(), throwsA(isA<Object>()));

      await expectLater(
        npt.done.timeout(Duration(seconds: 5)),
        completes,
        reason: 'done must not hang once startup has failed',
      );
    });

    test('run which throws still completes done', () async {
      final npt = Npt.create(
        atClient: _FailingAtClient(),
        params: _params(),
      );

      await expectLater(npt.run(), throwsA(isA<Object>()));

      await expectLater(
        npt.done.timeout(Duration(seconds: 5)),
        completes,
        reason: 'done must not hang once startup has failed',
      );
    });

    test('close is idempotent, so a late close cannot double complete',
        () async {
      final npt = Npt.create(
        atClient: _FailingAtClient(),
        params: _params(),
      );

      await expectLater(npt.runInline(), throwsA(isA<Object>()));

      // runInline already closed us on its way out; this must be a no-op
      // rather than a "Completer already completed" state error
      await npt.close();
      await npt.close();

      await expectLater(npt.done.timeout(Duration(seconds: 5)), completes);
    });
  });
}
