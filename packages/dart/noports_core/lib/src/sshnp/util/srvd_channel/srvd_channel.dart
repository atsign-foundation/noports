import 'dart:async';
import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_utils.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/relay_messages.dart';
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

abstract class SrvdChannel<T>
    with AsyncInitialization, AtClientBindings, ApkamSigning {
  @override
  final logger = AtSignLogger(' SrvdChannel ');

  @override
  final AtClient atClient;

  final SrvGenerator<T> srvGenerator;
  final SrvdChannelParams params;
  final String sessionId;
  final String clientNonce = DateTime.now().toIso8601String();

  String? cachedDaemonPublicSigningKeyUri;

  Completer acked = Completer();

  bool fetched = false;

  late RelayResponse _relayResponse;

  RelayResponse get relayResponse {
    if (fetched) {
      return _relayResponse;
    } else {
      throw SshnpError('Not yet fetched from srvd');
    }
  }

  /// The relay's address (ip address or fqdn)
  String get rvdHost => relayResponse.address;

  /// This is the port which the sshnp **daemon** will connect to
  int get daemonPort => relayResponse.portB;

  /// This is the port which the sshnp **client** will connect to
  int get clientPort => relayResponse.portA;

  String get rvdNonce => relayResponse.rvdNonce;

  bool get supportsEventLogging => relayResponse.supportsEventLogging;

  // * Volatile fields set at runtime

  String? aesKeyC2D;
  String? ivC2D;
  String? aesKeyD2C;
  String? ivD2C;
  String? _relayAuthAesKey;

  String? get relayAuthAesKey {
    switch (params.relayAuthMode) {
      case RelayAuthMode.payload:
        return null;
      case RelayAuthMode.escr:
        _relayAuthAesKey ??= AtChopsUtil.generateSymmetricKey(
          EncryptionKeyType.aes256,
        ).key;
        return _relayAuthAesKey;
    }
  }

  /// Whether srvd acknowledged our request
  @visibleForTesting
  SrvdAck srvdAck = SrvdAck.notAcknowledged;

  /// Will be set when we receive a NACK notification from srvd
  String srvdNackMessage = '';

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
    Future publishPSKFuture = publishPublicSigningKey();

    await getHostAndPortFromSrvd();

    await publishPSKFuture;

    completeInitialization();
  }

  Future<T?> runSrv({
    int? localRvPort,
    String? aesC2D,
    String? ivC2D,
    String? aesD2C,
    String? ivD2C,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
    Duration? controlChannelHeartbeat,
  }) async {
    await callInitialization();

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.

    late Srv<T> srv;

    RelayAuthenticator? relayAuthenticator;
    if (params.authenticateClientToRvd) {
      switch (params.relayAuthMode) {
        case RelayAuthMode.payload:
          relayAuthenticator = RelayAuthenticatorLegacy(
            signAndWrapAndJsonEncode(atClient, {
              'sessionId': sessionId,
              'clientNonce': clientNonce,
              'rvdNonce': rvdNonce,
            }),
          );
          break;
        case RelayAuthMode.escr:
          relayAuthenticator = RelayAuthenticatorESCR(
            sessionId: sessionId,
            relayAuthAesKey: relayAuthAesKey!,
            publicSigningKeyUri: publicSigningKeyUri,
            publicSigningKey: publicSigningKey,
            privateSigningKey: privateSigningKey,
            isSideA: true,
          );
          break;
      }
    }
    // Get the local host to bind to
    String? localHost;
    if (params is NptParams && (params as NptParams).localHost != null) {
      final nptParams = params as NptParams;
      localHost = nptParams.localHost;
      logger.info('Will bind to: $localHost');
    }

    srv = srvGenerator(
      rvdHost,
      clientPort,
      localPort: localRvPort,
      bindLocalPort: true,
      localHost: localHost,
      relayAuthenticator: relayAuthenticator,
      aesC2D: aesC2D,
      ivC2D: ivC2D,
      aesD2C: aesD2C,
      ivD2C: ivD2C,
      multi: multi,
      detached: detached,
      timeout: timeout,
      controlChannelHeartbeat: controlChannelHeartbeat,
    );
    return srv.run();
  }

  @protected
  @visibleForTesting
  Future<void> getHostAndPortFromSrvd({
    Duration timeout = DefaultArgs.relayResponseTimeoutDuration,
  }) async {
    srvdAck = SrvdAck.notAcknowledged;
    subscribe(
      regex: '$sessionId.${Srvd.namespace}@',
      shouldDecrypt: true,
    ).listen((notification) async {
      if (fetched) {
        logger.warning(
          'Got additional relay response ${notification.value} - ignoring',
        );
        return;
      }

      if (notification.key.contains('nack.$sessionId')) {
        logger.warning('Got NACK response from relay: ${notification.key}');
        srvdNackMessage = notification.value.toString();

        srvdAck = SrvdAck.acknowledgedWithErrors;
        acked.complete();

        return;
      }

      String notifVal = notification.value.toString();
      logger.info('Received from srvd: $notifVal');
      if (notifVal.startsWith('{')) {
        _relayResponse = RelayResponse.fromJson(jsonDecode(notifVal));
      } else {
        // legacy response format
        List results = notifVal.split(',');
        _relayResponse = RelayResponse(
          address: results[0],
          portA: int.parse(results[1]),
          portB: int.parse(results[2]),
          rvdNonce: results[3],
          supportsEventLogging: false,
        );
      }

      srvdAck = SrvdAck.acknowledged;
      fetched = true;
      acked.complete();

      logger.info(
        'Received from srvd:'
        ' rvdHost:clientPort:daemonPort $rvdHost:$clientPort:$daemonPort'
        ' rvdNonce: $rvdNonce',
      );
      logger.info('Daemon will connect to: $rvdHost:$daemonPort');
    });
    logger.info('Started listening for srvd response');

    late AtKey rvdRequestKey;
    late String rvdRequestValue;

    rvdRequestKey = AtKey()
      ..key = '${params.device}.request_ports.${Srvd.namespace}'
      ..sharedBy = params
          .clientAtSign // shared by us
      ..sharedWith = params
          .srvdAtSign // shared with the srvd host
      ..metadata = (Metadata()
        // as we are sending a notification to the srvd namespace,
        // we don't want to append our namespace
        ..namespaceAware = false
        ..ttl = 10000);

    List<String> preFetch = [];

    // Currently prefetch is only needed if auth mode is ESCR
    if (params.relayAuthMode == RelayAuthMode.escr) {
      preFetch.add(publicSigningKeyUri);
      if (cachedDaemonPublicSigningKeyUri != null) {
        preFetch.add(cachedDaemonPublicSigningKeyUri!);
      }
    }

    var message = RelayRequest(
      sessionId: sessionId,
      atSignA: params.clientAtSign,
      atSignB: params.sshnpdAtSign,
      authenticateSocketA: params.authenticateClientToRvd,
      authenticateSocketB: params.authenticateDeviceToRvd,
      clientNonce: clientNonce,
      relayAuthMode: params.relayAuthMode,
      relayAuthAesKey: relayAuthAesKey,
      only443: params.only443,
      multipleAcksOk: true,
      preFetch: preFetch,
      sendJsonResponse: true,
    );

    rvdRequestValue = jsonEncode(message.toJson());

    logger.info(
      'Sending notification to srvd with key $rvdRequestKey and value $rvdRequestValue',
    );
    await notify(
      rvdRequestKey,
      rvdRequestValue,
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    );

    logger.info(
      'Will wait for a response for up to ${timeout.inSeconds} seconds',
    );
    try {
      await acked.future.timeout(timeout);
    } on TimeoutException catch (_) {
      logger.warning(
        'Timed out waiting for srvd response after ${timeout.inSeconds} seconds',
      );
      throw TimeoutException(
        'Connection timeout to srvd ${params.srvdAtSign} service',
      );
    }

    if (srvdAck == SrvdAck.acknowledgedWithErrors) {
      throw SshnpError(srvdNackMessage);
    }
  }
}
