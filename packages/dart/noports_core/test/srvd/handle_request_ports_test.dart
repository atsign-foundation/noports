import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

/// Records whether a request got as far as allocating ports, then stops it.
class RecordingSrvd extends SrvdImpl {
  RecordingSrvd({required super.managerAtsign})
      : super(
          atClient: MockAtClient(),
          atSign: '@relay'.toAtsign(),
          homeDirectory: Directory.current.path,
          atKeysFilePath: Directory.current.path,
          ipAddress: '127.0.0.1',
          logTraffic: false,
          verbose: false,
          bind443: false,
          localBindPort443: 443,
          relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        );

  bool allocated = false;

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async {
    allocated = true;
    throw StateError('stopped after the gate');
  }
}

void main() {
  group('SrvdImpl.handleRequestPorts', () {
    AtNotification requestPorts({required String from, required String atSignA}) =>
        AtNotification(
          'notif-id',
          '@relay:device.request_ports.sshrvd$from',
          from,
          '@relay',
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
          value: jsonEncode({
            'sessionId': 'the session',
            'atSignA': atSignA,
            'atSignB': '@device',
            'clientNonce': 'client nonce',
            'authenticateSocketA': false,
            'authenticateSocketB': false,
            'relayAuthMode': RelayAuthMode.escr.name,
          }),
        );

    Future<bool> allocates({
      required String manager,
      required String from,
      required String atSignA,
    }) async {
      final srvd = RecordingSrvd(managerAtsign: manager);
      await srvd.handleRequestPorts(requestPorts(from: from, atSignA: atSignA));
      return srvd.allocated;
    }

    test('lets the manager through', () async {
      expect(
        await allocates(manager: '@manager', from: '@manager', atSignA: '@manager'),
        isTrue,
      );
    });

    test('refuses a sender that is not the manager', () async {
      expect(
        await allocates(manager: '@manager', from: '@mallory', atSignA: '@mallory'),
        isFalse,
      );
    });

    test('refuses a sender naming the manager as atSignA', () async {
      expect(
        await allocates(manager: '@manager', from: '@mallory', atSignA: '@manager'),
        isFalse,
      );
    });

    test('refuses a sender naming another atSign on an open relay', () async {
      expect(
        await allocates(manager: 'open', from: '@mallory', atSignA: '@alice'),
        isFalse,
      );
    });

    test('compares the sender with the normalised atSignA', () async {
      expect(
        await allocates(manager: 'open', from: '@alice', atSignA: '@Alice'),
        isTrue,
      );
    });
  });
}
