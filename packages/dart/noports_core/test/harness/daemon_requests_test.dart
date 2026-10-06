import 'dart:async';
import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:noports_core/npt.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'noports_harness.dart';

/// The daemon's replies to a client, as that client decrypts them.
class _Replies {
  _Replies(AtClient client) {
    final subscription = client.notificationService
        .subscribe(
          regex: '${NoPortsHarness.device}\\.${DefaultArgs.namespace}',
          shouldDecrypt: true,
        )
        .where((n) => n.from == NoPortsHarness.daemonAtSign)
        .listen((n) {
      seen.add(n);
      _added.add(n);
    });
    addTearDown(subscription.cancel);
  }

  final List<AtNotification> seen = [];
  final StreamController<AtNotification> _added = StreamController.broadcast();

  bool _isAbout(AtNotification n, String sessionId) =>
      n.key.contains('$sessionId.');

  bool anyAbout(String sessionId) => seen.any((n) => _isAbout(n, sessionId));

  /// The daemon's reply about [sessionId], waiting up to 10 seconds for it.
  Future<String> about(String sessionId) async {
    final reply = seen.where((n) => _isAbout(n, sessionId)).firstOrNull ??
        await _added.stream
            .firstWhere((n) => _isAbout(n, sessionId))
            .timeout(const Duration(seconds: 10));
    return reply.value!;
  }
}

void main() {
  /// A well-formed npt request for [sessionId] to open 127.0.0.1:22, naming a
  /// relay nothing listens on, so a request the daemon accepts fails when its
  /// side of the tunnel connects to the relay.
  Map<String, dynamic> nptPayload(String sessionId) => NptSessionRequest(
        sessionId: sessionId,
        rvdHost: '127.0.0.1',
        rvdPort: 1,
        requestedHost: '127.0.0.1',
        requestedPort: 22,
        authenticateToRvd: false,
        relayAuthMode: RelayAuthMode.payload,
        relayAuthAesKey: null,
        clientNonce: 'client-nonce',
        rvdNonce: 'rvd-nonce',
        encryptRvdTraffic: false,
        clientEphemeralPK: RsaKeyPair.generate().atPublicKey.publicKey,
        clientEphemeralPKType: EncryptionKeyType.rsa2048.name,
        timeout: const Duration(seconds: 5),
        twinKeys: false,
        relayAtsign: null,
      ).toJson();

  /// A well-formed direct ssh request for [sessionId]. A daemon that accepts
  /// it fails to start its side, since a test process has no srv binary.
  Map<String, dynamic> sshPayload(String sessionId) => SshnpSessionRequest(
        direct: true,
        sessionId: sessionId,
        host: '127.0.0.1',
        port: 1,
        authenticateToRvd: false,
        relayAuthMode: RelayAuthMode.payload,
        relayAuthAesKey: null,
        clientNonce: 'client-nonce',
        rvdNonce: 'rvd-nonce',
        encryptRvdTraffic: false,
        twinKeys: false,
        relayAtsign: null,
      ).toJson();

  /// Sends [envelope] to the daemon as [client]'s request of type [type].
  Future<void> sendRequest(AtClient client, String type, String envelope) =>
      client.notificationService.notify(
        NotificationParams.forUpdate(
          AtKey()
            ..key = type
            ..namespace = '${NoPortsHarness.device}.${DefaultArgs.namespace}'
            ..sharedBy = client.getCurrentAtSign()
            ..sharedWith = NoPortsHarness.daemonAtSign
            ..metadata = (Metadata()..ttl = 10000),
          value: envelope,
        ),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

  /// The requests of type [type] the daemon's atServer has received.
  int requestsReceived(NoPortsHarness harness, String type) => harness
      .server[NoPortsHarness.daemonAtSign].received
      .where((n) => n.key.contains(type))
      .length;

  const startFailed = 'Failed to start up the daemon side';
  const permitOpen = ['127.0.0.1:22', 'localhost:22'];

  for (final MapEntry(key: type, value: payload) in {
    'npt_request': nptPayload,
    'ssh_request': sshPayload,
  }.entries) {
    group(type, () {
      test('a request whose session id is not a UUID gets no reply, while a'
          ' valid one beside it does', () async {
        final harness = NoPortsHarness.create();
        await harness.startDaemon(permitOpen: permitOpen);
        final alice = await harness.openClient(
          NoPortsHarness.clientAtSign,
          namespace: DefaultArgs.namespace,
        );
        final replies = _Replies(alice);
        final valid = Uuid().v4();

        await sendRequest(
          alice,
          type,
          await signAndWrapAndJsonEncode(
            alice,
            payload(Uuid().v4())..['sessionId'] = 'not-a-uuid',
          ),
        );
        await sendRequest(
          alice,
          type,
          await signAndWrapAndJsonEncode(alice, payload(valid)),
        );

        expect(await replies.about(valid), contains(startFailed));
        expect(requestsReceived(harness, type), 2);
        expect(replies.anyAbout('not-a-uuid'), isFalse);
      });

      test('a request missing its signature gets no reply, while a valid one'
          ' beside it does', () async {
        final harness = NoPortsHarness.create();
        await harness.startDaemon(permitOpen: permitOpen);
        final alice = await harness.openClient(
          NoPortsHarness.clientAtSign,
          namespace: DefaultArgs.namespace,
        );
        final replies = _Replies(alice);
        final unsigned = Uuid().v4();
        final valid = Uuid().v4();

        await sendRequest(
          alice,
          type,
          jsonEncode({'payload': payload(unsigned)}),
        );
        await sendRequest(
          alice,
          type,
          await signAndWrapAndJsonEncode(alice, payload(valid)),
        );

        expect(await replies.about(valid), contains(startFailed));
        expect(requestsReceived(harness, type), 2);
        expect(replies.anyAbout(unsigned), isFalse);
      });

      test('a strict daemon refuses a request changed after it was signed, and'
          ' accepts one that was not', () async {
        final harness = NoPortsHarness.create();
        await harness.startDaemon(permitOpen: permitOpen, strict: true);
        final alice = await harness.openClient(
          NoPortsHarness.clientAtSign,
          namespace: DefaultArgs.namespace,
        );
        final replies = _Replies(alice);
        final tampered = Uuid().v4();
        final genuine = Uuid().v4();
        final envelope = jsonDecode(
          await signAndWrapAndJsonEncode(alice, payload(tampered)),
        );
        envelope['payload']['clientNonce'] = 'another-nonce';

        await sendRequest(alice, type, jsonEncode(envelope));
        await sendRequest(
          alice,
          type,
          await signAndWrapAndJsonEncode(alice, payload(genuine)),
        );

        expect(
          await replies.about(tampered),
          contains('Signature not verified'),
        );
        expect(await replies.about(genuine), contains(startFailed));
      });
    });
  }

  test("a client the daemon doesn't list as a manager gets no answer at all",
      () async {
    const eve = '@eve';
    final harness = NoPortsHarness.create();
    harness.server.addAtSign(eve);
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = Npt.create(
      params: NptParams(
        clientAtSign: eve,
        sshnpdAtSign: NoPortsHarness.daemonAtSign,
        srvdAtSign: NoPortsHarness.relayAtSign,
        remoteHost: '127.0.0.1',
        remotePort: echo.port,
        device: NoPortsHarness.device,
        localPort: 0,
        localHost: '127.0.0.1',
        inline: true,
        timeout: const Duration(seconds: 30),
        daemonPingTimeout: const Duration(seconds: 2),
      ),
      atClient: await harness.openClient(eve, namespace: DefaultArgs.namespace),
    );
    addTearDown(npt.close);

    await expectLater(
      npt.run(),
      throwsA(isA<TimeoutException>().having(
        (e) => e.message,
        'message',
        'Daemon feature check timed out',
      )),
    );
    expect(
      harness.server[NoPortsHarness.daemonAtSign].received
          .where((n) => n.from == eve),
      isNotEmpty,
      reason: "eve's ping reached the daemon",
    );
    expect(
      harness.server[eve].received
          .where((n) => n.from == NoPortsHarness.daemonAtSign),
      isEmpty,
      reason: 'the daemon sent eve nothing',
    );
  });
}
