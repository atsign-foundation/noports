import 'dart:async';
import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/npa/npa_rpcs.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'log_capture.dart';
import 'noports_harness.dart';

const _alice = NoPortsHarness.clientAtSign;
const _carol = '@carol';

/// An npt request for [sessionId] carrying [relayAuthAesKey], to open
/// 127.0.0.1:22 through a relay nothing listens on.
Map<String, dynamic> _nptPayload(String sessionId, String relayAuthAesKey) =>
    NptSessionRequest(
      sessionId: sessionId,
      rvdHost: '127.0.0.1',
      rvdPort: 1,
      requestedHost: '127.0.0.1',
      requestedPort: 22,
      authenticateToRvd: true,
      relayAuthMode: RelayAuthMode.escr,
      relayAuthAesKey: relayAuthAesKey,
      clientNonce: 'client-nonce',
      rvdNonce: 'rvd-nonce',
      encryptRvdTraffic: false,
      clientEphemeralPK: RsaKeyPair.generate().atPublicKey.publicKey,
      clientEphemeralPKType: EncryptionKeyType.rsa2048.name,
      timeout: const Duration(seconds: 5),
      twinKeys: false,
      relayAtsign: null,
    ).toJson();

/// A direct ssh request for [sessionId] carrying [relayAuthAesKey], through a
/// relay nothing listens on.
Map<String, dynamic> _sshPayload(String sessionId, String relayAuthAesKey) =>
    SshnpSessionRequest(
      direct: true,
      sessionId: sessionId,
      host: '127.0.0.1',
      port: 1,
      authenticateToRvd: true,
      relayAuthMode: RelayAuthMode.escr,
      relayAuthAesKey: relayAuthAesKey,
      clientNonce: 'client-nonce',
      rvdNonce: 'rvd-nonce',
      encryptRvdTraffic: false,
      twinKeys: false,
      relayAtsign: null,
    ).toJson();

/// Sends [value] to the daemon as [client]'s notification of type [type].
Future<void> _send(AtClient client, String type, String value) =>
    client.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey()
          ..key = type
          ..namespace = '${NoPortsHarness.device}.${DefaultArgs.namespace}'
          ..sharedBy = client.getCurrentAtSign()
          ..sharedWith = NoPortsHarness.daemonAtSign
          ..metadata = (Metadata()..ttl = 10000),
        value: value,
      ),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );

class _MockAtClient extends Mock implements AtClient {}

/// An [AuthChecker] whose every check fails with an error.
class _FailingAuthChecker implements AuthChecker {
  @override
  Future<NPAAuthCheckResponse> mayConnect({required String clientAtsign}) =>
      Future.error(StateError('the policy service could not be asked'));
}

/// An sshnpd managed by no one, on an atClient that does nothing, logging at
/// every level.
SshnpdImpl _sshnpdOnMockAtClient({
  AuthChecker? authChecker,
  Future<void> Function(AtNotification)? notifPreProcessor,
}) {
  final atClient = _MockAtClient();
  when(
    () => atClient.getCurrentAtSign(),
  ).thenReturn(NoPortsHarness.daemonAtSign);
  return SshnpdImpl(
    atClient: atClient,
    username: 'harness',
    homeDirectory: '/home/harness',
    device: NoPortsHarness.device,
    managerAtsigns: [],
    sshClient: SupportedSshClient.openssh,
    ephemeralPermissions: '',
    sshAlgorithm: SupportedSshAlgorithm.ed25519,
    deviceGroup: 'default',
    version: '1.0.0',
    permitOpen: ['*:*'],
    authChecker: authChecker,
    notifPreProcessor: notifPreProcessor,
    strict: false,
    clientKeyCheckInterval: Duration.zero,
    requireEnrollmentSignature: false,
  )..logger.level = 'all';
}

/// The daemon's reply to [client] about [sessionId], waited for up to 10
/// seconds; call it before sending the request.
Future<String> _replyAbout(AtClient client, String sessionId) => client
    .notificationService
    .subscribe(
      regex: '${NoPortsHarness.device}\\.${DefaultArgs.namespace}',
      shouldDecrypt: true,
    )
    .where(
      (n) =>
          n.from == NoPortsHarness.daemonAtSign &&
          n.key.contains('$sessionId.'),
    )
    .first
    .then((n) => n.value!)
    .timeout(const Duration(seconds: 10));

void main() {
  final capture = LogCapture.install();

  group('Given sshnpd logging at every level', () {
    test('when it receives an npt or ssh session request carrying a relay-auth'
        ' key, whether accepted, refused as unauthorised, with a signature that'
        " doesn't verify, unreadable, or whose handling fails unexpectedly, then"
        " the log names the request's type and sender, and no log record"
        ' contains the key', () async {
      final harness = NoPortsHarness.create(
        atSigns: {
          _alice,
          _carol,
          NoPortsHarness.daemonAtSign,
          NoPortsHarness.relayAtSign,
        },
      );
      final daemon = await harness.startDaemon(
        permitOpen: ['127.0.0.1:22', 'localhost:22'],
        strict: true,
      );
      daemon.logger.level = 'all';
      final alice = await harness.openClient(
        _alice,
        namespace: DefaultArgs.namespace,
      );
      final carol = await harness.openClient(
        _carol,
        namespace: DefaultArgs.namespace,
      );

      final cases =
          <
            ({
              String type,
              String outcome,
              String sender,
              String key,
              List<LogRecord> records,
            })
          >[];

      for (final (type, payload) in [
        ('npt_request', _nptPayload),
        ('ssh_request', _sshPayload),
      ]) {
        Future<void> receive(
          String outcome,
          String sender,
          Future<void> Function(String sessionId, String key) send,
        ) async {
          final key = generateAes256Key();
          final from = capture.records.length;
          await send(Uuid().v4(), key);
          cases.add((
            type: type,
            outcome: outcome,
            sender: sender,
            key: key,
            records: capture.records.skip(from).toList(),
          ));
        }

        await receive('accepted', _alice, (sessionId, key) async {
          final reply = _replyAbout(alice, sessionId);
          await _send(
            alice,
            type,
            await signAndWrapAndJsonEncode(alice, payload(sessionId, key)),
          );
          expect(
            await reply,
            contains('Failed to start up the daemon side'),
            reason: 'the daemon accepts the $type and tries to start it',
          );
        });

        await receive('refused as unauthorised', _carol, (
          sessionId,
          key,
        ) async {
          bool refusal(LogRecord r) =>
              r.message.contains(_carol) &&
              r.message.contains('not authorized');
          final refusals = capture.records.where(refusal).length;
          await _send(
            carol,
            type,
            await signAndWrapAndJsonEncode(carol, payload(sessionId, key)),
          );
          await capture.waitFor(
            'refusing the $type from $_carol',
            (_) => capture.records.where(refusal).length > refusals,
          );
        });

        await receive("with a signature that doesn't verify", _alice, (
          sessionId,
          key,
        ) async {
          final reply = _replyAbout(alice, sessionId);
          final envelope = jsonDecode(
            await signAndWrapAndJsonEncode(alice, payload(sessionId, key)),
          );
          envelope['payload']['clientNonce'] = 'another-nonce';
          await _send(alice, type, jsonEncode(envelope));
          expect(
            await reply,
            contains('Signature not verified'),
            reason: 'the daemon checks the $type signature and refuses it',
          );
        });

        await receive('unreadable', _alice, (sessionId, key) async {
          final envelope = jsonDecode(
            await signAndWrapAndJsonEncode(alice, payload(sessionId, key)),
          )..remove('signature');
          await _send(alice, type, jsonEncode(envelope));
          await capture.waitFor(
            'handling the unreadable $type $sessionId',
            (r) => r.message.contains('acquired mutex $sessionId'),
          );
        });

        String whole(String value, String key) => value;
        for (final (failing, sshnpd, sent) in [
          (
            'its policy check throws',
            _sshnpdOnMockAtClient(authChecker: _FailingAuthChecker()),
            whole,
          ),
          (
            'a notification pre-processor throws',
            _sshnpdOnMockAtClient(
              notifPreProcessor: (_) async =>
                  throw StateError('the notification could not be read'),
            ),
            whole,
          ),
          (
            'a notification pre-processor cannot read it, cut short partway'
                ' through its key',
            _sshnpdOnMockAtClient(
              notifPreProcessor: (n) async => jsonDecode(n.value!),
            ),
            (String value, String key) =>
                value.substring(0, value.indexOf(key) + key.length - 4),
          ),
        ]) {
          await receive(
            'whose handling fails unexpectedly, as $failing',
            _alice,
            (sessionId, key) => sshnpd.clientRequestNotificationHandler(
              AtNotification(
                  Uuid().v4(),
                  '${NoPortsHarness.daemonAtSign}:$type.${NoPortsHarness.device}'
                      '.${DefaultArgs.namespace}$_alice',
                  _alice,
                  NoPortsHarness.daemonAtSign,
                  DateTime.now().millisecondsSinceEpoch,
                  'key',
                  true,
                )
                ..value = sent(
                  jsonEncode({
                    'payload': payload(sessionId, key),
                    'signature': 'signature',
                    'hashingAlgo': 'sha256',
                    'signingAlgo': 'rsa2048',
                  }),
                  key,
                ),
            ),
          );
        }
      }

      expect(
        {
          for (final c in cases)
            '${c.type} ${c.outcome}': recordsHoldingKey(c.records, c.key),
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: 'no record holds the relay-auth key of any request',
      );
      for (final c in cases) {
        expect(
          c.records.map((r) => r.message),
          contains(allOf(contains(c.type), contains(c.sender))),
          reason: 'the log names the ${c.outcome} ${c.type} and its sender',
        );
      }
    });

    test('when it receives a legacy request, then no log record contains the'
        " request's private key", () async {
      final harness = NoPortsHarness.create();
      final daemon = await harness.startDaemon(permitOpen: ['127.0.0.1:1']);
      daemon.logger.level = 'all';
      final alice = await harness.openClient(
        _alice,
        namespace: DefaultArgs.namespace,
      );
      final sessionId = Uuid().v4();
      const privateKeyBody = 'bGVnYWN5LXJldmVyc2Utc2Vzc2lvbi1rZXk';
      const username = 'legacy-user';
      const remoteHost = '10.9.8.7';
      final request = '45678 22 $username $remoteHost $sessionId';
      final reply = _replyAbout(alice, sessionId);

      await _send(
        alice,
        'privatekey',
        '-----BEGIN OPENSSH PRIVATE KEY-----\n'
            '$privateKeyBody\n'
            '-----END OPENSSH PRIVATE KEY-----\n',
      );
      await _send(alice, 'sshd', request);

      expect(
        await reply,
        contains('Daemon does not permit connections'),
        reason: 'the daemon reads the legacy request and refuses it',
      );
      expect(
        recordsHolding(capture.records, [privateKeyBody]),
        isEmpty,
        reason: "no record holds the legacy request's private key",
      );
      expect(
        capture.records.map((r) => r.message),
        contains(contains('Private Key received from $_alice')),
        reason: 'the daemon read the private key',
      );
    });
  });
}
