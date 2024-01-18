import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
import 'package:noports_core/src/common/validation_utils.dart';
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
  final String clientNonce = DateTime.now().toIso8601String();

  // * Volatile fields which are set in [params] but may be overridden with
  // * values provided by sshrvd

  String? _host;
  int? _portA;

  String get host => _host ?? params.host;

  /// This is the port which the sshnp **client** will connect to
  int get port => _portA ?? params.port;

  // * Volatile fields set at runtime

  String? rvdNonce;
  String? sessionAESKeyString;
  String? sessionIVString;

  /// Whether sshrvd acknowledged our request
  @visibleForTesting
  SshrvdAck sshrvdAck = SshrvdAck.notAcknowledged;

  /// The port sshrvd is listening on
  int? _portB;

  /// This is the port which the sshnp **daemon** will connect to
  int? get sshrvdPort => _portB;

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
      _portA = params.port;
    }
    completeInitialization();
  }

  Future<T?> runSshrv({
    required bool directSsh,
    int? localRvPort,
    String? sessionAESKeyString,
    String? sessionIVString,
  }) async {
    if (!directSsh && localRvPort != null) {
      throw Exception(
          'localRvPort must be null when using reverseSsh (legacy)');
    }
    if (directSsh && localRvPort == null) {
      throw Exception(
          'localRvPort must be non-null when using directSsh (default)');
    }
    await callInitialization();
    if (_portB == null) throw Exception('sshrvdPort is null');

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.

    late Sshrv<T> sshrv;
    if (directSsh) {
      sshrv = sshrvGenerator(
        host,
        _portA!,
        localPort: localRvPort!,
        bindLocalPort: true,
        rvdAuthString: params.authenticateClientToRvd
            ? signAndWrapAndJsonEncode(atClient, {
                'sessionId': sessionId,
                'clientNonce': clientNonce,
                'rvdNonce': rvdNonce,
              })
            : null,
        sessionAESKeyString: sessionAESKeyString,
        sessionIVString: sessionIVString,
      );
    } else {
      // legacy behaviour
      sshrv = sshrvGenerator(
        host,
        _portB!,
        localPort: params.localSshdPort,
        bindLocalPort: false,
      );
    }

    return sshrv.run();
  }

  @protected
  Future<void> getHostAndPortFromSshrvd() async {
    sshrvdAck = SshrvdAck.notAcknowledged;
    subscribe(regex: '$sessionId.${Sshrvd.namespace}@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      logger.info('Received from sshrvd: $ipPorts');
      List results = ipPorts.split(',');
      _host = results[0];
      _portA = int.parse(results[1]);
      _portB = int.parse(results[2]);
      rvdNonce = results[3];
      logger.info(
          'Received from sshrvd: host:port $host:$port and rvdNonce: $rvdNonce');
      logger.info('Set sshrvdPort to: $_portB');
      sshrvdAck = SshrvdAck.acknowledged;
    });
    logger.info('Started listening for sshrvd response');

    late AtKey rvdRequestKey;
    late String rvdRequestValue;

    if (params.authenticateClientToRvd || params.authenticateDeviceToRvd) {
      rvdRequestKey = AtKey()
        ..key = '${params.device}.request_ports.${Sshrvd.namespace}'
        ..sharedBy = params.clientAtSign // shared by us
        ..sharedWith = host // shared with the sshrvd host
        ..metadata = (Metadata()
        // as we are sending a notification to the sshrvd namespace,
        // we don't want to append our namespace
          ..namespaceAware = false
          ..ttl = 10000);

      var message = SocketRendezvousRequestMessage();
      message.sessionId = sessionId;
      message.atSignA = params.clientAtSign;
      message.atSignB = params.sshnpdAtSign;
      message.authenticateSocketA = params.authenticateClientToRvd;
      message.authenticateSocketB = params.authenticateDeviceToRvd;
      message.clientNonce = clientNonce;

      rvdRequestValue = message.toString();
    } else {
      // send a legacy message since no new rvd features are being used
      rvdRequestKey = AtKey()
        ..key = '${params.device}.${Sshrvd.namespace}'
        ..sharedBy = params.clientAtSign // shared by us
        ..sharedWith = host // shared with the sshrvd host
        ..metadata = (Metadata()
        // as we are sending a notification to the sshrvd namespace,
        // we don't want to append our namespace
          ..namespaceAware = false
          ..ttl = 10000);

      rvdRequestValue = sessionId;
    }

    logger.info(
        'Sending notification to sshrvd with key $rvdRequestKey and value $rvdRequestValue');
    await notify(
      rvdRequestKey,
      rvdRequestValue,
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );

    int counter = 1;
    while (sshrvdAck == SshrvdAck.notAcknowledged) {
      if (counter % 20 == 0) {
        logger.info('Still waiting for sshrvd response');
      }
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter > 150) {
        logger.warning('Timed out waiting for sshrvd response');
        throw ('Connection timeout to sshrvd $host service\nhint: make sure host is valid and online');
      }
    }
  }
}
