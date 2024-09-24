import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/srvd/build_env.dart';
import 'package:noports_core/src/srvd/socket_connector.dart';
import 'package:noports_core/src/srvd/srvd.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';

@protected
class SrvdImpl implements Srvd {
  @override
  final AtSignLogger logger = AtSignLogger(' srvd ');
  @override
  AtClient atClient;
  @override
  final String atSign;
  @override
  final String homeDirectory;
  @override
  final String atKeysFilePath;
  @override
  final String managerAtsign;
  @override
  final String ipAddress;
  @override
  final bool logTraffic;
  @override
  bool verbose = false;

  @override
  @visibleForTesting
  bool initialized = false;

  static final String subscriptionRegex = '${Srvd.namespace}@';

  late final SrvdUtil srvdUtil;

  SrvdImpl({
    required this.atClient,
    required this.atSign,
    required this.homeDirectory,
    required this.atKeysFilePath,
    required this.managerAtsign,
    required this.ipAddress,
    required this.logTraffic,
    required this.verbose,
    SrvdUtil? srvdUtil,
  }) {
    this.srvdUtil = srvdUtil ?? SrvdUtil(atClient);
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<Srvd> fromCommandLineArgs(List<String> args,
      {AtClient? atClient,
      FutureOr<AtClient> Function(SrvdParams)? atClientGenerator,
      void Function(Object, StackTrace)? usageCallback}) async {
    try {
      SrvdParams p;
      try {
        p = await SrvdParams.fromArgs(args);
      } on FormatException catch (e) {
        throw ArgumentError(e.message);
      }

      if (!await File(p.atKeysFilePath).exists()) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      if (atClient == null && atClientGenerator == null) {
        throw StateError('atClient and atClientGenerator are both null');
      }

      atClient ??= await atClientGenerator!(p);

      var srvd = SrvdImpl(
        atClient: atClient,
        atSign: p.atSign,
        homeDirectory: p.homeDirectory,
        atKeysFilePath: p.atKeysFilePath,
        managerAtsign: p.managerAtsign,
        ipAddress: p.ipAddress,
        logTraffic: p.logTraffic,
        verbose: p.verbose,
      );

      if (p.verbose) {
        srvd.logger.logger.level = Level.INFO;
      }
      return srvd;
    } catch (e, s) {
      usageCallback?.call(e, s);
      rethrow;
    }
  }

  @override
  Future<void> init() async {
    if (initialized) {
      throw StateError('Cannot init() - already initialized');
    }

    initialized = true;
  }

  @override
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }
    NotificationService notificationService = atClient.notificationService;

    notificationService
        .subscribe(regex: subscriptionRegex, shouldDecrypt: true)
        .listen(_notificationHandler);
  }

  void _notificationHandler(AtNotification notification) async {
    if (!srvdUtil.accept(notification)) {
      return;
    }

    logger.shout('New session request from ${notification.from}');

    late SrvdSessionParams sessionParams;
    try {
      sessionParams = await srvdUtil.getParams(notification);

      if (managerAtsign != 'open' && managerAtsign != sessionParams.atSignA) {
        logger.shout('Session ${sessionParams.sessionId}'
            ' for ${sessionParams.atSignA}'
            ' is denied');
        return;
      }
    } catch (e) {
      logger.shout('Unable to provide the socket pair due to: $e');
      return;
    }

    logger.info('New session request params: $sessionParams');

    (int, int) ports = await _spawnSocketConnector(
      0,
      0,
      sessionParams,
      logTraffic,
      verbose,
    );
    var (portA, portB) = ports;
    logger.shout('Starting session ${sessionParams.sessionId}'
        ' for ${sessionParams.atSignA} to ${sessionParams.atSignB}'
        ' using ports $ports');

    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttl = 10000
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = sessionParams.sessionId
      ..sharedBy = atSign
      ..sharedWith = notification.from
      ..namespace = Srvd.namespace
      ..metadata = metaData;

    String data = '$ipAddress,$portA,$portB,${sessionParams.rvdNonce}';

    logger.shout('Sending response data'
        ' for requested session ${sessionParams.sessionId} :'
        ' [$data]');

    try {
      await atClient.notificationService.notify(
          NotificationParams.forUpdate(atKey,
              value: data, notificationExpiry: Duration(minutes: 1)),
          waitForFinalDeliveryStatus: false,
          checkForFinalDeliveryStatus: false);
    } catch (e) {
      stderr.writeln("Error writing session ${notification.value} atKey");
    }
  }

  /// This function spawns a new socketConnector in a background isolate
  /// once the socketConnector has spawned and is ready to accept connections
  /// it sends back the port numbers to the main isolate
  /// then the port numbers are returned from this function
  Future<PortPair> _spawnSocketConnector(
    int portA,
    int portB,
    SrvdSessionParams srvdSessionParams,
    bool logTraffic,
    bool verbose,
  ) async {
    /// Spawn an isolate and wait for it to send back the issued port numbers
    ReceivePort receivePort = ReceivePort(srvdSessionParams.sessionId);

    ConnectorParams parameters = (
      receivePort.sendPort,
      portA,
      portB,
      jsonEncode(srvdSessionParams),
      BuildEnv.enableSnoop && logTraffic,
      verbose,
    );

    logger
        .info("Spawning socket connector isolate with parameters $parameters");

    unawaited(Isolate.spawn<ConnectorParams>(socketConnector, parameters));

    PortPair ports = await receivePort.first;

    logger.info('Received ports $ports in main isolate'
        ' for session ${srvdSessionParams.sessionId}');

    return ports;
  }
}

class SrvdSessionParams {
  final String sessionId;
  final String atSignA;
  final String? atSignB;
  final bool authenticateSocketA;
  final bool authenticateSocketB;
  final String? publicKeyA;
  final String? publicKeyB;
  final String? clientNonce;
  final String? rvdNonce;

  SrvdSessionParams({
    required this.sessionId,
    required this.atSignA,
    this.atSignB,
    this.authenticateSocketA = false,
    this.authenticateSocketB = false,
    this.publicKeyA,
    this.publicKeyB,
    this.rvdNonce,
    this.clientNonce,
  });

  @override
  String toString() => toJson().toString();

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'atSignA': atSignA,
        'atSignB': atSignB,
        'authenticateSocketA': authenticateSocketA,
        'authenticateSocketB': authenticateSocketB,
        'publicKeyA': publicKeyA,
        'publicKeyB': publicKeyB,
        'rvdNonce': rvdNonce,
        'clientNonce': clientNonce,
      };

  static SrvdSessionParams fromJson(Map<String, dynamic> json) {
    return SrvdSessionParams(
      sessionId: json['sessionId'],
      atSignA: json['atSignA'],
      atSignB: json['atSignB'],
      authenticateSocketA: json['authenticateSocketA'],
      authenticateSocketB: json['authenticateSocketB'],
      publicKeyA: json['publicKeyA'],
      publicKeyB: json['publicKeyB'],
      rvdNonce: json['rvdNonce'],
      clientNonce: json['clientNonce'],
    );
  }
}

class SrvdUtil {
  final AtClient atClient;

  SrvdUtil(this.atClient);

  bool accept(AtNotification notification) {
    return notification.key.contains(Srvd.namespace);
  }

  Future<SrvdSessionParams> getParams(AtNotification notification) async {
    if (notification.key.contains('.request_ports.${Srvd.namespace}')) {
      return await _processJSONRequest(notification);
    }
    return _processLegacyRequest(notification);
  }

  SrvdSessionParams _processLegacyRequest(AtNotification notification) {
    return SrvdSessionParams(
      sessionId: notification.value!,
      atSignA: notification.from,
    );
  }

  Future<SrvdSessionParams> _processJSONRequest(
      AtNotification notification) async {
    dynamic jsonValue = jsonDecode(notification.value ?? '');

    assertValidMapValue(jsonValue, 'sessionId', String);
    assertValidMapValue(jsonValue, 'atSignA', String);
    assertValidMapValue(jsonValue, 'atSignB', String);
    assertValidMapValue(jsonValue, 'clientNonce', String);
    assertValidMapValue(jsonValue, 'authenticateSocketA', bool);
    assertValidMapValue(jsonValue, 'authenticateSocketA', bool);

    final String sessionId = jsonValue['sessionId'];
    final String atSignA = jsonValue['atSignA'];
    final String atSignB = jsonValue['atSignB'];
    final String clientNonce = jsonValue['clientNonce'];
    final bool authenticateSocketA = jsonValue['authenticateSocketA'];
    final bool authenticateSocketB = jsonValue['authenticateSocketB'];

    String rvdSessionNonce = DateTime.now().toIso8601String();

    String? publicKeyA;
    String? publicKeyB;
    if (authenticateSocketA) {
      publicKeyA = await _fetchPublicKey(atSignA);
    }
    if (authenticateSocketB) {
      publicKeyB = await _fetchPublicKey(atSignB);
    }
    return SrvdSessionParams(
      sessionId: sessionId,
      atSignA: atSignA,
      atSignB: atSignB,
      authenticateSocketA: authenticateSocketA,
      authenticateSocketB: authenticateSocketB,
      publicKeyA: publicKeyA,
      publicKeyB: publicKeyB,
      rvdNonce: rvdSessionNonce,
      clientNonce: clientNonce,
    );
  }

  Future<String?> _fetchPublicKey(String atSign) async {
    AtValue v = await atClient.get(AtKey.fromString('public:publickey$atSign'));
    return v.value;
  }
}
