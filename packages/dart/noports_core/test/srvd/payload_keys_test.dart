import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  group('Given a relay @relay and a session in payload mode', () {
    const relay = '@relay';
    final relayKeyPair = RsaKeyPair.generate();
    final publicKeys = {
      '@alice': RsaKeyPair.generate().atPublicKey.publicKey,
      '@bob': RsaKeyPair.generate().atPublicKey.publicKey,
    };

    late MockAtClient atClient;
    late SrvdImpl srvd;

    setUp(() {
      registerFallbackValue(AtKey());
      atClient = MockAtClient();
      when(() => atClient.getCurrentAtSign()).thenReturn(relay);
      // Answers as at_client does: a public key from the atServer, except
      // the relay's own, which is read from local storage, where it isn't,
      // unless the atServer is asked.
      when(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as AtKey;
        final options = invocation.namedArguments[#getRequestOptions]
            as GetRequestOptions?;
        final owner = key.sharedBy!;
        if (owner == relay) {
          if (!(options?.useRemoteAtServer ?? false)) {
            throw KeyNotFoundException(
              'public:publickey$relay does not exist in keystore',
            );
          }
          return AtValue()..value = relayKeyPair.atPublicKey.publicKey;
        }
        return AtValue()..value = publicKeys[owner];
      });
      srvd = SrvdImpl(
        atClient: atClient,
        atSign: relay.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: false,
        localBindPort443: 443,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckInterval: Duration.zero,
      );
    });

    SrvdSessionParams session({required String a, required String b}) =>
        SrvdSessionParams(
          sessionId: 'the-session',
          atSignA: a,
          atSignB: b,
          authenticateSocketA: true,
          authenticateSocketB: true,
          rvdNonce: 'rvd nonce',
          relayAuthMode: RelayAuthMode.payload,
          only443: false,
          multipleAcksOk: false,
          preFetch: const [],
          sendJsonResponse: true,
        );

    test(
        "when the session's client side is @relay itself, then the relay"
        " authenticates that side with @relay's public key, fetched from its"
        ' atServer, and the session starts', () async {
      final params = await srvd.withPayloadKeys(session(a: relay, b: '@bob'));

      expect(params.publicKeyA, relayKeyPair.atPublicKey.publicKey);
      expect(params.publicKeyB, publicKeys['@bob']);
    });

    test(
        "when the session's daemon side is @relay itself, then the relay does"
        ' the same for the daemon side', () async {
      final params = await srvd.withPayloadKeys(session(a: '@alice', b: relay));

      expect(params.publicKeyA, publicKeys['@alice']);
      expect(params.publicKeyB, relayKeyPair.atPublicKey.publicKey);
    });

    test(
        'when both sides are other atSigns, then the relay looks up their'
        ' public keys from the atServer as now', () async {
      final params =
          await srvd.withPayloadKeys(session(a: '@alice', b: '@bob'));

      expect(params.publicKeyA, publicKeys['@alice']);
      expect(params.publicKeyB, publicKeys['@bob']);
      verify(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).called(2);
    });
  });
}
