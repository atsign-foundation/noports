import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/npa/npa_rpcs.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../harness/log_capture.dart';

class _MockAtClient extends Mock implements AtClient {}

/// An [AuthChecker] whose every check fails with an error.
class _FailingAuthChecker implements AuthChecker {
  @override
  Future<NPAAuthCheckResponse> mayConnect({required String clientAtsign}) =>
      Future.error(StateError('the policy service could not be asked'));
}

void main() {
  final capture = LogCapture.install();
  const daemon = '@daemon';
  const client = '@client';
  const device = 'device';

  /// An sshnpd for [daemon] managed by no one, logging at every level.
  SshnpdImpl sshnpd({
    AuthChecker? authChecker,
    Future<void> Function(AtNotification)? notifPreProcessor,
  }) {
    final atClient = _MockAtClient();
    when(() => atClient.getCurrentAtSign()).thenReturn(daemon);
    return SshnpdImpl(
      atClient: atClient,
      username: 'testuser',
      homeDirectory: '/home/testuser',
      device: device,
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

  /// A request of [type] from [client] whose payload carries [key].
  AtNotification request(String type, String key) =>
      AtNotification(
          Uuid().v4(),
          '$daemon:$type.$device.${DefaultArgs.namespace}$client',
          client,
          daemon,
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
        )
        ..value = jsonEncode({
          'payload': {
            'sessionId': Uuid().v4(),
            'relayAuthMode': RelayAuthMode.escr.name,
            'relayAuthAesKey': key,
          },
          'signature': 'signature',
          'hashingAlgo': 'sha256',
          'signingAlgo': 'rsa2048',
        });

  group('Given sshnpd logging at every level', () {
    test('when handling an npt or ssh session request carrying a relay-auth key'
        ' fails unexpectedly, as when its policy check or a notification'
        " pre-processor throws, then the log names the request's type and"
        ' sender, and no log record contains the key', () async {
      final cases = <String, ({String type, String key, int from})>{};
      for (final type in ['npt_request', 'ssh_request']) {
        for (final (failing, handling) in [
          ('policy check', sshnpd(authChecker: _FailingAuthChecker())),
          (
            'pre-processor',
            sshnpd(
              notifPreProcessor: (_) async =>
                  throw StateError('the notification could not be read'),
            ),
          ),
        ]) {
          final key = generateAes256Key();
          final from = capture.records.length;
          await handling.clientRequestNotificationHandler(request(type, key));
          cases['$type whose $failing throws'] = (
            type: type,
            key: key,
            from: from,
          );
        }
      }

      List<String> messagesOf(int from) =>
          capture.records.skip(from).map((r) => r.message).toList();

      expect(
        {
          for (final MapEntry(key: name, value: c) in cases.entries)
            name: recordsHoldingKey(capture.records.skip(c.from), c.key),
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: 'no record holds the relay-auth key of any request',
      );
      for (final MapEntry(key: name, value: c) in cases.entries) {
        expect(
          messagesOf(c.from),
          contains(allOf(contains(c.type), contains(client))),
          reason: 'the log names the $name and its sender',
        );
      }
    });
  });
}
