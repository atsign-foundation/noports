import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
import 'package:noports_core/src/sshnp/util/sshrvd_channel/notification_request_message.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';
import 'package:noports_core/sshrvd.dart';

@visibleForTesting
enum SshrvdAck {
  /// sshrvd acknowledged our request
  acknowledged,

  /// sshrvd acknowledged our request and had errors
  acknowledgedWithErrors,

  /// sshrvd did not acknowledge our request
  notAcknowledged,
}

abstract class SshrvdChannel<T> with AsyncInitialization, AtClientBindings {
  @override
  final logger = AtSignLogger(' SshrvdChannel ');

  @override
  final AtClient atClient;

  final SshrvGenerator<T> sshrvGenerator;
  final SshnpParams params;
  final String sessionId;

  // * Volatile fields which are set in [params] but may be overridden with
  // * values provided by sshrvd

  String? _host;
  int? _port;

  String get host => _host ?? params.host;

  int get port => _port ?? params.port;
  // * Volatile fields set at runtime

  /// Whether sshrvd acknowledged our request
  @visibleForTesting
  SshrvdAck sshrvdAck = SshrvdAck.notAcknowledged;

  /// The port sshrvd is listening on
  int? _sshrvdPort;

  int? get sshrvdPort => _sshrvdPort;

  SshrvdChannel({
    required this.atClient,
    required this.params,
    required this.sessionId,
    required this.sshrvGenerator,
  }) {
    logger.level = params.verbose ? 'info' : 'shout';
  }

  @override
  Future<void> initialize() async {
    if (params.host.startsWith('@')) {
      await getHostAndPortFromSshrvd();
    } else {
      _host = params.host;
      _port = params.port;
    }
    completeInitialization();
  }

  Future<T?> runSshrv() async {
    await callInitialization();
    if (_sshrvdPort == null) throw Exception('sshrvdPort is null');

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    Sshrv<T> sshrv = sshrvGenerator(
      host,
      _sshrvdPort!,
      localSshdPort: params.localSshdPort,
    );
    return sshrv.run();
  }

  @protected
  Future<void> getHostAndPortFromSshrvd() async {
    sshrvdAck = SshrvdAck.notAcknowledged;
    subscribe(regex: '$sessionId.${Sshrvd.namespace}@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      List results = ipPorts.split(',');
      _host = results[0];
      _port = int.parse(results[1]);
      _sshrvdPort = int.parse(results[2]);
      logger.info('Received host and port from sshrvd: $host:$port');
      logger.info('Set sshrvdPort to: $_sshrvdPort');
      sshrvdAck = SshrvdAck.acknowledged;
    });
    logger.info('Started listening for sshrvd response');
    AtKey ourSshrvdIdKey = AtKey()
      ..key = '${params.device}.${Sshrvd.namespace}'
      ..sharedBy = params.clientAtSign // shared by us
      ..sharedWith = host // shared with the sshrvd host
      ..metadata = (Metadata()
        // as we are sending a notification to the sshrvd namespace,
        // we don't want to append our namespace
        ..namespaceAware = false
        ..ttl = 10000);
    logger.info('Sending notification to sshrvd: $ourSshrvdIdKey');

    String notificationValue = _getValue(sessionId);
    // We need to send not just the sessionId but other metaData
    // especially, the atSign on the other end
    // In the rvd we need to figure out backwards compatibility.
    await notify(ourSshrvdIdKey, notificationValue);

    int counter = 1;
    while (sshrvdAck == SshrvdAck.notAcknowledged) {
      if (counter % 20 == 0) {
        logger.info('Still waiting for sshrvd response');
      }
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter > 100) {
        logger.warning('Timed out waiting for sshrvd response');
        throw ('Connection timeout to sshrvd $host service\nhint: make sure host is valid and online');
      }
    }
  }

  String _getValue(String sessionId) {

      if(params.authenticateClient || params.authenticateDevice) {
         // Authentication is requested. Send the latest JSON message
         var message = AuthenticationEnablingMessage();
         message.sessionId = sessionId;
         message.atSignA = params.clientAtSign;
         message.atSignB = params.sshnpdAtSign;
         message.authenticateSocketA = params.authenticateClient;
         message.authenticateSocketA = params.authenticateDevice;
        return message.toString();
      }

    return (SessionIdMessage()..sessionId = sessionId).toString();
  }
}
