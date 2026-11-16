import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'sshnp_core_mocks.dart';
import 'sshnp_mocks.dart';

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
  // let the feature check's own failure land
  await Future.delayed(const Duration(milliseconds: 50));
  return (result, unhandled);
}

final _featureCheckFailure = TimeoutException('Daemon feature check timed out');

/// An [SshnpCore] whose daemon feature check fails after [featureCheckDelay],
/// and whose relay step runs [relayStep].
StubbedSshnp _sshnp({
  required Duration featureCheckDelay,
  required Future<void> Function() relayStep,
}) {
  final atClient = MockAtClient();
  final params = MockSshnpParams();
  final sshnpdChannel = MockSshnpdChannel();
  final srvdChannel = MockSrvdChannel();

  when(() => params.sshnpdAtSign).thenReturn('@sshnpd');
  when(() => params.device).thenReturn('mydevice');
  when(() => params.localPort).thenReturn(0);
  when(() => params.verbose).thenReturn(false);
  when(() => params.authenticateDeviceToRvd).thenReturn(true);
  when(() => params.authenticateClientToRvd).thenReturn(true);
  when(() => params.encryptRvdTraffic).thenReturn(true);
  when(() => params.sendSshPublicKey).thenReturn(false);
  when(() => atClient.getPreferences()).thenReturn(null);
  when(() => atClient.setPreferences(any())).thenReturn(null);

  when(() => sshnpdChannel.callInitialization()).thenAnswer((_) async {});
  when(
    () => sshnpdChannel.featureCheck(any(), timeout: any(named: 'timeout')),
  ).thenAnswer(
    (_) => Future.delayed(featureCheckDelay, () => throw _featureCheckFailure),
  );
  when(
    () => sshnpdChannel.resolveRemoteUsername(),
  ).thenAnswer((_) async => 'remoteUser');
  when(
    () => sshnpdChannel.resolveTunnelUsername(
      remoteUsername: any(named: 'remoteUsername'),
    ),
  ).thenAnswer((_) async => 'tunnelUser');
  when(
    () => sshnpdChannel.sharePublicKeyIfRequired(any()),
  ).thenAnswer((_) async {});
  when(() => sshnpdChannel.cachedPingResponse).thenReturn(null);
  when(() => srvdChannel.callInitialization()).thenAnswer((_) => relayStep());

  final sshnp = StubbedSshnp(
    atClient: atClient,
    params: params,
    sshnpdChannel: sshnpdChannel,
    srvdChannel: srvdChannel,
  );
  final initialize = FunctionStub<void>();
  final callInitialization = FunctionStub<void>();
  final completeInitialization = FunctionStub<void>();
  when(() => initialize()).thenReturn(null);
  when(() => callInitialization()).thenReturn(null);
  when(() => completeInitialization()).thenReturn(null);
  sshnp.stubAsyncInitialization(
    stubbedCallInitialization: callInitialization,
    stubbedInitialize: initialize,
    stubbedCompleteInitialization: completeInitialization,
  );
  return sshnp;
}

void main() {
  setUpAll(() {
    registerFallbackValue(AtClientPreference());
    registerFallbackValue(<DaemonFeature>[]);
    registerFallbackValue(Duration.zero);
  });

  // Built inside the zone under test: a future's error never crosses error
  // zones, so one made outside would escape the check.
  group('Given an SshnpCore whose daemon feature check fails while the relay '
      'step is still running', () {
    test('when the relay step throws, then initialize throws the relay '
        'failure and nothing goes unhandled', () async {
      final relayFailure = SshnpError('relay failed');
      final (thrown, unhandled) = await _runCatchingUnhandled(() async {
        final sshnp = _sshnp(
          featureCheckDelay: const Duration(milliseconds: 10),
          relayStep: () async => throw relayFailure,
        );
        await sshnp.initialize();
      });

      expect(thrown, same(relayFailure));
      expect(
        unhandled,
        isEmpty,
        reason:
            'the feature check is awaited only after the relay step, so once '
            'the relay step throws nothing ever awaits it, and its failure is '
            'unhandled',
      );
    });
  });

  group('Given an SshnpCore whose daemon feature check fails before the relay '
      'step finishes', () {
    test('when the relay step then succeeds, then initialize throws the '
        'feature check failure and nothing goes unhandled', () async {
      final (thrown, unhandled) = await _runCatchingUnhandled(() async {
        final sshnp = _sshnp(
          featureCheckDelay: Duration.zero,
          relayStep: () =>
              Future.delayed(const Duration(milliseconds: 20), () {}),
        );
        await sshnp.initialize();
      });

      expect(thrown, same(_featureCheckFailure));
      expect(
        unhandled,
        isEmpty,
        reason:
            'a feature check that fails before anything awaits it is '
            'unhandled at that moment, even though initialize awaits it '
            'later',
      );
    });
  });
}
