import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:logging/logging.dart';
import 'package:noports_core/npt.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'log_capture.dart';
import 'noports_harness.dart';

const _alice = NoPortsHarness.clientAtSign;
const _bob = NoPortsHarness.daemonAtSign;

/// A daemon permit-open list which refuses every session in these tests.
const _refuseAll = ['127.0.0.1:1'];

/// An sshnp with the channels it talks to its daemon and its relay over.
typedef _Sshnp = ({
  SshnpCore sshnp,
  SshnpdChannel sshnpdChannel,
  SrvdChannel srvdChannel,
});

typedef _SshnpFactory = _Sshnp Function(AtClient atClient, SshnpParams params);

final Map<String, _SshnpFactory> _sshnpClients = {
  'openssh': (atClient, params) {
    final sshnp =
        Sshnp.openssh(atClient: atClient, params: params)
            as SshnpOpensshLocalImpl;
    return (
      sshnp: sshnp,
      sshnpdChannel: sshnp.sshnpdChannel,
      srvdChannel: sshnp.srvdChannel,
    );
  },
  'dart': (atClient, params) {
    final sshnp =
        Sshnp.dartPure(
              atClient: atClient,
              params: params,
              identityKeyPair: null,
            )
            as SshnpDartPureImpl;
    return (
      sshnp: sshnp,
      sshnpdChannel: sshnp.sshnpdChannel,
      srvdChannel: sshnp.srvdChannel,
    );
  },
};

/// An sshnp made by [create] from [atClient], the client atSign's, to the
/// harness device, with each of its loggers at every level.
_Sshnp _sshnp(AtClient atClient, _SshnpFactory create) {
  final client = create(
    atClient,
    SshnpParams(
      clientAtSign: _alice,
      sshnpdAtSign: _bob,
      srvdAtSign: NoPortsHarness.relayAtSign,
      device: NoPortsHarness.device,
      remoteUsername: 'harness',
      verbose: true,
    ),
  );
  for (final logger in [
    client.sshnp.logger,
    client.sshnpdChannel.logger,
    client.srvdChannel.logger,
  ]) {
    logger.level = 'all';
  }
  return client;
}

/// An inline npt from [atClient], the client atSign's, to [remotePort] on
/// the daemon's host, with its own logger at every level; closed after the
/// test.
Npt _npt(AtClient atClient, int remotePort) {
  final npt = Npt.create(
    params: NptParams(
      clientAtSign: _alice,
      sshnpdAtSign: _bob,
      srvdAtSign: NoPortsHarness.relayAtSign,
      remoteHost: '127.0.0.1',
      remotePort: remotePort,
      device: NoPortsHarness.device,
      localPort: 0,
      localHost: '127.0.0.1',
      inline: true,
      timeout: const Duration(seconds: 30),
      verbose: true,
    ),
    atClient: atClient,
  );
  addTearDown(npt.close);
  (npt as NptBase).logger.level = 'all';
  return npt;
}

void main() {
  final capture = LogCapture.install();

  group('Given sshnp logging at every level', () {
    test('when it sends its session request to the daemon, then the log says'
        " it sent the request, and no log record contains the request's"
        ' relay-auth key', () async {
      final harness = NoPortsHarness.create();
      await harness.startRelay();
      await harness.startDaemon(permitOpen: _refuseAll);
      final alice = await harness.openClient(
        _alice,
        namespace: DefaultArgs.namespace,
      );

      final sent = <String, ({_Sshnp sshnp, List<LogRecord> records})>{};
      for (final MapEntry(key: client, value: create)
          in _sshnpClients.entries) {
        final from = capture.records.length;
        final sshnp = _sshnp(alice, create);
        await expectLater(
          sshnp.sshnp.run(),
          throwsA(isA<SshnpError>()),
          reason: 'the daemon refuses the $client sshnp session',
        );
        sent[client] = (
          sshnp: sshnp,
          records: capture.records
              .skip(from)
              .where((r) => r.loggerName == 'Sshnp')
              .toList(),
        );
      }

      expect(
        {
          for (final MapEntry(key: client, value: (:sshnp, :records))
              in sent.entries)
            client: recordsHoldingKey(
              records,
              sshnp.srvdChannel.relayAuthAesKey!,
            ),
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: "no record from sshnp holds its request's relay-auth key",
      );
      for (final MapEntry(key: client, value: (:sshnp, :records))
          in sent.entries) {
        expect(
          records.map((r) => r.message),
          contains(
            'Sending ssh_request for session ${sshnp.sshnp.sessionId}'
            ' to $_bob',
          ),
          reason: 'the $client sshnp logs that it sent its request',
        );
      }
    });
  });

  group('Given npt logging at every level', () {
    test('when it sends its session request to the daemon, then the log says'
        " it sent the request, and no log record contains the request's"
        ' relay-auth key', () async {
      final harness = NoPortsHarness.create();
      final echo = await startEchoServer();
      final relay = await harness.startRelay();
      await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
      final npt = _npt(
        await harness.openClient(_alice, namespace: DefaultArgs.namespace),
        echo.port,
      );

      await npt.run();

      final key = relay.sessions[npt.sessionId]!.params.relayAuthAesKey!;
      final records = capture.from(' Npt ');
      expect(
        recordsHoldingKey(records, key),
        isEmpty,
        reason: "no record from npt holds its request's relay-auth key",
      );
      expect(
        records.map((r) => r.message),
        contains('Sending npt_request for session ${npt.sessionId} to $_bob'),
        reason: 'npt logs that it sent its request',
      );
    });
  });

  group('Given sshnp or npt logging at every level', () {
    test('when it sends its session request to the relay, then no log record'
        ' contains the relay-auth key', () async {
      final harness = NoPortsHarness.create();
      final relay = await harness.startRelay();
      await harness.startDaemon(permitOpen: _refuseAll);
      final alice = await harness.openClient(
        _alice,
        namespace: DefaultArgs.namespace,
      );

      final sshnp = _sshnp(alice, _sshnpClients['openssh']!);
      await expectLater(
        sshnp.sshnp.run(),
        throwsA(isA<SshnpError>()),
        reason: 'the daemon refuses the sshnp session',
      );
      final channelRecords = capture.from(' SrvdChannel ').toList();
      final npt = _npt(alice, 22);
      await expectLater(
        npt.run(),
        throwsA(isA<SshnpError>()),
        reason: 'the daemon refuses the npt session',
      );
      final keys = {
        'sshnp': sshnp.srvdChannel.relayAuthAesKey!,
        'npt': relay.sessions[npt.sessionId]!.params.relayAuthAesKey!,
      };

      expect(
        {
          'sshnp': recordsHoldingKey(channelRecords, keys['sshnp']!),
          'npt': recordsHoldingKey(
            capture.from(' SrvdChannel ').skip(channelRecords.length),
            keys['npt']!,
          ),
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: 'no record from the relay channel holds the relay-auth key',
      );
      expect(
        relay.sessions[sshnp.sshnp.sessionId]?.params.relayAuthAesKey,
        keys['sshnp'],
        reason: "the relay received sshnp's request with its key",
      );
    });
  });
}
