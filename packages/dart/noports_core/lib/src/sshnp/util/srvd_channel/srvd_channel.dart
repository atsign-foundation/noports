import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/notification_request_message.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/srv.dart';
import 'package:noports_core/srvd.dart';

@visibleForTesting
enum SrvdAck {
  /// srvd acknowledged our request
  acknowledged,

  /// srvd acknowledged our request and had errors
  acknowledgedWithErrors,

  /// srvd did not acknowledge our request
  notAcknowledged,
}

abstract class SrvdChannel<T> with AsyncInitialization, AtClientBindings {
  @override
  final logger = AtSignLogger(' SrvdChannel ');

  @override
  final AtClient atClient;

  final SrvGenerator<T> srvGenerator;
  final SshnpParams params;
  final String sessionId;
  final String clientNonce = DateTime.now().toIso8601String();

  // * Volatile fields which are set in [params] but may be overridden with
  // * values provided by srvd

  String? _host;
  int? _portA;

  String get host => _host ?? params.host;

  /// This is the port which the sshnp **client** will connect to
  int get port => _portA ?? params.port;

  // * Volatile fields set at runtime

  String? rvdNonce;
  String? sessionAESKeyString;
  String? sessionIVString;

  /// Whether srvd acknowledged our request
  @visibleForTesting
  SrvdAck srvdAck = SrvdAck.notAcknowledged;

  /// The port srvd is listening on
  int? _portB;

  /// This is the port which the sshnp **daemon** will connect to
  int? get srvdPort => _portB;

  SrvdChannel({
    required this.atClient,
    required this.params,
    required this.sessionId,
    required this.srvGenerator,
  }) {
    logger.level = params.verbose ? 'info' : 'shout';
  }

  @override
  Future<void> initialize() async {
    if (params.host.startsWith('@')) {
      await getHostAndPortFromSrvd();
    } else {
      _host = params.host;
      _portA = params.port;
    }
    completeInitialization();
  }

  Future<T?> runSrv({
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
    if (_portB == null) throw Exception('srvdPort is null');

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.

    late Srv<T> srv;
    if (directSsh) {
      srv = srvGenerator(
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
      srv = srvGenerator(
        host,
        _portB!,
        localPort: params.localSshdPort,
        bindLocalPort: false,
      );
    }

    return srv.run();
  }

  @protected
  Future<void> getHostAndPortFromSrvd() async {
    srvdAck = SrvdAck.notAcknowledged;
    subscribe(regex: '$sessionId.${Srvd.namespace}@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      logger.info('Received from srvd: $ipPorts');
      List results = ipPorts.split(',');
      _host = results[0];
      _portA = int.parse(results[1]);
      _portB = int.parse(results[2]);
      if (results.length >= 4) {
        rvdNonce = results[3];
      }
      logger.info('Received from srvd:'
          ' host:port $host:$port'
          ' rvdNonce: $rvdNonce');
      logger.info('Set srvdPort to: $_portB');
      srvdAck = SrvdAck.acknowledged;
    });
    logger.info('Started listening for srvd response');

    late AtKey rvdRequestKey;
    late String rvdRequestValue;

    if (params.authenticateClientToRvd || params.authenticateDeviceToRvd) {
      rvdRequestKey = AtKey()
        ..key = '${params.device}.request_ports.${Srvd.namespace}'
        ..sharedBy = params.clientAtSign // shared by us
        ..sharedWith = host // shared with the srvd host
        ..metadata = (Metadata()
          // as we are sending a notification to the srvd namespace,
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
        ..key = '${params.device}.${Srvd.namespace}'
        ..sharedBy = params.clientAtSign // shared by us
        ..sharedWith = host // shared with the srvd host
        ..metadata = (Metadata()
          // as we are sending a notification to the srvd namespace,
          // we don't want to append our namespace
          ..namespaceAware = false
          ..ttl = 10000);

      rvdRequestValue = sessionId;
    }

    logger.info(
        'Sending notification to srvd with key $rvdRequestKey and value $rvdRequestValue');
    await notify(
      rvdRequestKey,
      rvdRequestValue,
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );

    int counter = 1;
    while (srvdAck == SrvdAck.notAcknowledged) {
      if (counter % 20 == 0) {
        logger.info('Still waiting for srvd response');
      }
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter > 150) {
        logger.warning('Timed out waiting for srvd response');
        throw ('Connection timeout to srvd $host service\nhint: make sure host is valid and online');
      }
    }
  }
}
