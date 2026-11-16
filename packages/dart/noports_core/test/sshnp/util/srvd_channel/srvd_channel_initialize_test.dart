import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import '../../sshnp_mocks.dart';
import 'srvd_channel_mocks.dart';

/// Fails publishing the signing key at once, and answers the relay request
/// only once [relayAnswer] completes.
class _EarlyPskFailureChannel extends StubbedSrvdChannel<String> {
  final Completer<void> relayAnswer = Completer();

  _EarlyPskFailureChannel({required super.atClient, required super.params})
    : super(
        sessionId: 'session',
        srvGenerator: SrvGeneratorStub<String>().call,
        notify: NotifyStub().call,
        subscribe: SubscribeStub().call,
      );

  @override
  Future publishPublicSigningKey({String? value}) => Future.error('psk failed');

  @override
  Future<void> getHostAndPortFromSrvd({
    Duration timeout = DefaultArgs.relayResponseTimeoutDuration,
  }) => relayAnswer.future;
}

/// Runs [body] in its own error zone; returns what it threw, if anything,
/// along with every error that went unhandled meanwhile.
Future<(Object? thrown, List<Object> unhandled)> _runCatchingUnhandled(
  Future<void> Function() body,
) async {
  final unhandled = <Object>[];
  final thrown = Completer<Object?>();
  unawaited(
    runZonedGuarded(() async {
      try {
        await body();
        thrown.complete(null);
      } catch (e) {
        thrown.complete(e);
      }
    }, (e, _) => unhandled.add(e)),
  );
  final result = await thrown.future;
  // let anything that fails late be reported
  await Future.delayed(const Duration(milliseconds: 10));
  return (result, unhandled);
}

void main() {
  group('Given a srvd channel whose signing key publish fails before the relay '
      'answers', () {
    // Built inside the zone under test: a future's error never crosses
    // error zones, so one made outside would escape the check.
    _EarlyPskFailureChannel newChannel() {
      final params = MockSshnpParams();
      when(() => params.verbose).thenReturn(false);
      return _EarlyPskFailureChannel(atClient: MockAtClient(), params: params);
    }

    test('when the relay then answers, then initialize throws the publish '
        'failure and nothing goes unhandled', () async {
      final (thrown, unhandled) = await _runCatchingUnhandled(() async {
        final channel = newChannel();
        final init = channel.initialize();
        await Future.delayed(const Duration(milliseconds: 10));
        channel.relayAnswer.complete();
        await init;
      });

      expect(thrown, 'psk failed');
      expect(
        unhandled,
        isEmpty,
        reason:
            'the publish is awaited only after the relay answers, so a '
            'failure before then would be unhandled - which kills the npt '
            'binary - unless it is ignored up front',
      );
    });

    test('when the relay then fails, then initialize throws the relay '
        'failure and nothing goes unhandled', () async {
      final (thrown, unhandled) = await _runCatchingUnhandled(() async {
        final channel = newChannel();
        final init = channel.initialize();
        await Future.delayed(const Duration(milliseconds: 10));
        channel.relayAnswer.completeError('relay failed');
        await init;
      });

      expect(thrown, 'relay failed');
      expect(
        unhandled,
        isEmpty,
        reason:
            'the publish is never awaited once the relay fails, so its '
            'failure would be unhandled - which kills the npt binary - '
            'unless it is ignored up front',
      );
    });
  });
}
