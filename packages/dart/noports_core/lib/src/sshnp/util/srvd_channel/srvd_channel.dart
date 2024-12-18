import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/notification_request_message.dart';
import 'package:noports_core/srv.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';

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
  final SrvdChannelParams params;
  final String sessionId;
  final String clientNonce = DateTime.now().toIso8601String();

  bool fetched = false;
  late String _rvdHost;
  late int _rvdPortA;
  late int _rvdPortB;

  String get rvdHost {
    if (fetched) {
      return _rvdHost;
    } else {
      throw SshnpError('Not yet fetched from srvd');
    }
  }

  /// This is the port which the sshnp **daemon** will connect to
  int get daemonPort {
    if (fetched) {
      return _rvdPortB;
    } else {
      throw SshnpError('Not yet fetched from srvd');
    }
  }

  /// This is the port which the sshnp **client** will connect to
  int get clientPort {
    if (fetched) {
      return _rvdPortA;
    } else {
      throw SshnpError('Not yet fetched from srvd');
    }
  }

  // * Volatile fields set at runtime

  String? rvdNonce;
  String? sessionAESKeyString;
  String? sessionIVString;

  /// Whether srvd acknowledged our request
  @visibleForTesting
  SrvdAck srvdAck = SrvdAck.notAcknowledged;

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
    await getHostAndPortFromSrvd();

    completeInitialization();
  }

  Future<T?> runSrv({
    int? localRvPort,
    String? sessionAESKeyString,
    String? sessionIVString,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
  }) async {
    await callInitialization();

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.

    late Srv<T> srv;

    srv = srvGenerator(
      rvdHost,
      clientPort,
      localPort: localRvPort,
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
      multi: multi,
      detached: detached,
      timeout: timeout,
    );
    return srv.run();
  }

  @protected
  @visibleForTesting
  Future<void> getHostAndPortFromSrvd(
      {Duration timeout = DefaultArgs.relayResponseTimeoutDuration}) async {
    srvdAck = SrvdAck.notAcknowledged;
    subscribe(regex: '$sessionId.${Srvd.namespace}@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      logger.info('Received from srvd: $ipPorts');
      List results = ipPorts.split(',');
      _rvdHost = results[0];
      _rvdPortA = int.parse(results[1]);
      _rvdPortB = int.parse(results[2]);
      if (results.length >= 4) {
        rvdNonce = results[3];
      }
      fetched = true;
      logger.info('Received from srvd:'
          ' rvdHost:clientPort:daemonPort $rvdHost:$clientPort:$daemonPort'
          ' rvdNonce: $rvdNonce');
      logger.info('Daemon will connect to: $rvdHost:$daemonPort');
      srvdAck = SrvdAck.acknowledged;
    });
    logger.info('Started listening for srvd response');

    late AtKey rvdRequestKey;
    late String rvdRequestValue;

    if (params.authenticateClientToRvd || params.authenticateDeviceToRvd) {
      rvdRequestKey = AtKey()
        ..key = '${params.device}.request_ports.${Srvd.namespace}'
        ..sharedBy = params.clientAtSign // shared by us
        ..sharedWith = params.srvdAtSign // shared with the srvd host
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
        ..sharedWith = params.srvdAtSign // shared with the srvd host
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
      ttln: Duration(minutes: 1),
    );

    int counter = 1;
    int t = DateTime.now().add(timeout).millisecondsSinceEpoch;
    while (srvdAck == SrvdAck.notAcknowledged) {
      // we'll log a message every two seconds while we're waiting
      // (40 loops, 50 milliseconds sleep per loop)
      if (counter % 40 == 0) {
        logger.info('Still waiting for srvd response');
      }
      await Future.delayed(Duration(milliseconds: 50));
      counter++;
      if (DateTime.now().millisecondsSinceEpoch > t) {
        logger.warning('Timed out waiting for srvd response');
        throw TimeoutException(
            'Connection timeout to srvd ${params.srvdAtSign} service');
      }
    }
  }
}
