import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/handle_server_events.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/srvd/build_env.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/srvd.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';

import 'types.dart';

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

  static final String subscriptionRegex = '\\.${Srvd.namespace}@';

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

    handlePublicKeyChangedEvent(atClient, atSign);

    notificationService
        .subscribe(regex: subscriptionRegex, shouldDecrypt: true)
        .listen(_notificationHandler);
  }

  void _notificationHandler(AtNotification notification) async {
    if (!srvdUtil.accept(notification)) {
      return;
    }

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

    PortPair ports;
    // ignore: unused_local_variable
    Isolate spawned;
    SendPort sendToSpawned;

    try {
      if (sessionParams.only443) {
        logger.shout('only443 not yet handled');
        logger.shout('Sending to the 443 isolate');
        throw UnimplementedError('only443 not yet handled');
      } else {
        logger.shout('Acquiring next port pair');
        (ports, spawned, sendToSpawned) =
            await spawnNewPortPairIsolate(sessionParams);
      }
    } catch (e) {
      logger.shout('_spawnSocketConnector exception: $e');
      return;
    }

    var mutexKey = AtKey.fromString('${sessionParams.sessionId}'
        '.session_mutexes.${Srvd.namespace}'
        '${atClient.getCurrentAtSign()!}')
      ..metadata = (Metadata()
        ..immutable = true // only one srvd will succeed in doing this
        ..ttl = 30000); // expire after 30 seconds to keep datastore clean
    PutRequestOptions pro = PutRequestOptions()
      ..shouldEncrypt = false
      ..useRemoteAtServer = true;

    try {
      await atClient.put(
        mutexKey,
        'lock',
        putRequestOptions: pro,
      );
      logger.shout('😎 Will handle request from ${notification.from}'
          '; acquired mutex $mutexKey');
    } catch (err) {
      if (err.toString().toLowerCase().contains('immutable')) {
        logger.shout('🤷‍♂️ Will not handle request from ${notification.from}'
            '; did not acquire mutex $mutexKey');
        sendToSpawned.send({
          'req': 'stop',
          'payload': null,
        });
      } else {
        logger.shout('Will not handle; did not acquire mutex $mutexKey : $err');
      }
      return;
    }

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
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async {
    logger.shout('Acquiring port pair');

    /// Spawn an isolate and wait for it to send back the issued port numbers
    ReceivePort fromSpawned = ReceivePort(sessionParams.sessionId);

    ConnectorParams parameters = (
      fromSpawned.sendPort, // spawned will use this to communicate with main
      BuildEnv.enableSnoop && logTraffic,
      verbose,
      sessionParams.sessionId,
    );

    logger.info("Spawning socket connector isolate"
        " with parameters $parameters");

    Isolate spawned = await Isolate.spawn<ConnectorParams>(
      portPairIsolateEntryPoint,
      parameters,
    );

    Completer receivedSendToSpawned = Completer();
    late SendPort sendToSpawned;
    Completer receivedPortPair = Completer();
    late PortPair ports;

    logger.info('Waiting for isolate to send its port pair info');
    fromSpawned.listen((message) async {
      if (message is SendPort) {
        sendToSpawned = message;
        receivedSendToSpawned.complete();
        return;
      }
      if (message is PortPair) {
        ports = message;
        receivedPortPair.complete();
        return;
      }
      if (message is Map) {
        return;
      }

      // We only expect SendPort, PortPair or Map
      logger.shout('Unknown message from isolate -'
          ' type: ${message.runtimeType} message: $message');
    });

    // Wait to receive the SendPort from the spawned isolate
    try {
      await receivedSendToSpawned.future.timeout(
        Duration(milliseconds: isolateStartTimeoutMs),
      );
    } on TimeoutException catch (_) {
      throw TimeoutException(
          'No sendPort received after ${isolateStartTimeoutMs}ms');
    }

    // Ask the spawned isolate to start the session
    sendToSpawned.send({
      'req': 'start',
      'payload': sessionParams,
    });

    // Wait to receive the PortPair from the spawned isolate
    try {
      await receivedPortPair.future.timeout(
        Duration(milliseconds: isolateBindPortsTimeoutMs),
      );
    } on TimeoutException catch (_) {
      throw TimeoutException(
          'No sendPort received after ${isolateBindPortsTimeoutMs}ms');
    }

    logger.info('Received ports $ports in main isolate'
        ' for session ${sessionParams.sessionId}');

    return (ports, spawned, sendToSpawned);
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
  final String relayAuthMode;
  final String? relayAuthAesKey;
  final bool only443;

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
    this.relayAuthMode = 'v0',
    this.relayAuthAesKey,
    this.only443 = false,
  }) {
    if (relayAuthMode != 'v0' && relayAuthMode != 'v1') {
      throw ArgumentError('Invalid relayAuthMode "$relayAuthMode"');
    }
  }

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
        'relayAuthMode': relayAuthMode,
        'relayAuthAesKey': relayAuthAesKey,
        'only443': only443,
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
      relayAuthMode: json['relayAuthMode'] ?? 'v0',
      relayAuthAesKey: json['relayAuthAesKey'],
      only443: json['only443'] ?? false,
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
    return _processAncientClientRequest(notification);
  }

  /// Handles requests from ancient (v3) clients
  SrvdSessionParams _processAncientClientRequest(AtNotification notification) {
    return SrvdSessionParams(
      sessionId: notification.value!,
      atSignA: notification.from,
    );
  }

  /// Handles requests from all clients v4 onwards
  ///
  /// If session wants v0 authentication, fetch atSigns' public keys here
  ///
  /// When sessions want v1 authentication, we don't until auth time
  /// what signing keys are going to be used, so the spawned isolate
  /// will ask the main isolate to fetch public signing keys
  Future<SrvdSessionParams> _processJSONRequest(
      AtNotification notification) async {
    dynamic json = jsonDecode(notification.value ?? '');

    assertValidMapValue(json, 'sessionId', String);
    assertValidMapValue(json, 'atSignA', String);
    assertValidMapValue(json, 'atSignB', String);
    assertValidMapValue(json, 'clientNonce', String);
    assertValidMapValue(json, 'authenticateSocketA', bool);
    assertValidMapValue(json, 'authenticateSocketA', bool);

    final String sessionId = json['sessionId'];
    final String atSignA = json['atSignA'];
    final String atSignB = json['atSignB'];
    final String clientNonce = json['clientNonce'];
    final bool authenticateSocketA = json['authenticateSocketA'];
    final bool authenticateSocketB = json['authenticateSocketB'];

    String rvdSessionNonce = DateTime.now().toIso8601String();

    String relayAuthMode = json['relayAuthMode'] ?? 'v0';
    String? publicKeyA;
    String? publicKeyB;
    if (relayAuthMode == 'v0' && authenticateSocketA) {
      publicKeyA = await _fetchPublicKey(atSignA);
    }
    if (relayAuthMode == 'v0' && authenticateSocketB) {
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
      relayAuthMode: relayAuthMode,
      relayAuthAesKey: json['relayAuthAesKey'],
      only443: json['only443'] ?? false,
    );
  }

  Future<String?> _fetchPublicKey(String atSign) async {
    AtValue v = await atClient.get(AtKey.fromString('public:publickey$atSign'));
    return v.value;
  }
}
