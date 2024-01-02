import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:at_client/at_client.dart';
import 'package:at_lookup/at_lookup.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/sshrvd/build_env.dart';
import 'package:noports_core/src/sshrvd/socket_connector.dart';
import 'package:noports_core/src/sshrvd/sshrvd.dart';
import 'package:noports_core/src/sshrvd/sshrvd_params.dart';

@protected
class SshrvdImpl implements Sshrvd {
  @override
  final AtSignLogger logger = AtSignLogger(' sshrvd ');
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
  final bool snoop;
  @override
  bool verbose = false;

  @override
  @visibleForTesting
  bool initialized = false;

  static final String subscriptionRegex = '${Sshrvd.namespace}@';

  SshrvdImpl({
    required this.atClient,
    required this.atSign,
    required this.homeDirectory,
    required this.atKeysFilePath,
    required this.managerAtsign,
    required this.ipAddress,
    required this.snoop,
    required this.verbose,
  }) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<Sshrvd> fromCommandLineArgs(List<String> args,
      {AtClient? atClient,
      FutureOr<AtClient> Function(SshrvdParams)? atClientGenerator,
      void Function(Object, StackTrace)? usageCallback}) async {
    try {
      var p = await SshrvdParams.fromArgs(args);

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

      var sshrvd = SshrvdImpl(
        atClient: atClient,
        atSign: p.atSign,
        homeDirectory: p.homeDirectory,
        atKeysFilePath: p.atKeysFilePath,
        managerAtsign: p.managerAtsign,
        ipAddress: p.ipAddress,
        snoop: p.snoop,
        verbose: p.verbose,
      );

      if (p.verbose) {
        sshrvd.logger.logger.level = Level.INFO;
      }
      return sshrvd;
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
    if (!SshrvdUtil.accept(notification)) {
      return;
    }
    late SshrvdSessionParams sessionParams;
    try {
      sessionParams = await SshrvdUtil.getParams(notification);

      if (managerAtsign != 'open' && managerAtsign != sessionParams.atSignA) {
        logger.shout(
            'Session ${sessionParams.sessionId} for ${sessionParams.atSignA} is denied');
        return;
      }
    } catch (e) {
      logger.shout('Unable to provide the socket pair due to: $e');
      return;
    }

    logger
        .info('New session request: $sessionParams from ${notification.from}');

    (int, int) ports = await _spawnSocketConnector(
      0,
      0,
      sessionParams,
      snoop,
      verbose,
    );
    var (portA, portB) = ports;
    logger.warning(
        'Starting session ${sessionParams.sessionId} for ${sessionParams.atSignA} to ${sessionParams.atSignB} using ports $ports');

    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttl = 10000
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = sessionParams.sessionId
      ..sharedBy = atSign
      ..sharedWith = notification.from
      ..namespace = Sshrvd.namespace
      ..metadata = metaData;

    String data = '$ipAddress,$portA,$portB,${sessionParams.rvdNonce}';

    logger.info(
        'Sending response data for session ${sessionParams.sessionId} : [$data]');

    try {
      await atClient.notificationService.notify(
          NotificationParams.forUpdate(atKey, value: data),
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
    SshrvdSessionParams sshrvdSessionParams,
    bool snoop,
    bool verbose,
  ) async {
    /// Spawn an isolate and wait for it to send back the issued port numbers
    ReceivePort receivePort = ReceivePort(sshrvdSessionParams.sessionId);

    ConnectorParams parameters = (
      receivePort.sendPort,
      portA,
      portB,
      jsonEncode(sshrvdSessionParams),
      BuildEnv.enableSnoop && snoop,
      verbose,
    );

    logger
        .info("Spawning socket connector isolate with parameters $parameters");

    unawaited(Isolate.spawn<ConnectorParams>(socketConnector, parameters));

    PortPair ports = await receivePort.first;

    logger.info('Received ports $ports in main isolate'
        ' for session ${sshrvdSessionParams.sessionId}');

    return ports;
  }
}

class SshrvdSessionParams {
  final String sessionId;
  final String atSignA;
  final String? atSignB;
  final bool authenticateSocketA;
  final bool authenticateSocketB;
  final String? publicKeyA;
  final String? publicKeyB;
  final String? clientNonce;
  final String? rvdNonce;

  SshrvdSessionParams({
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

  static SshrvdSessionParams fromJson(Map<String, dynamic> json) {
    return SshrvdSessionParams(
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

class SshrvdUtil {
  static bool accept(AtNotification notification) {
    return notification.key.contains(Sshrvd.namespace);
  }

  static Future<SshrvdSessionParams> getParams(
      AtNotification notification) async {
    if (notification.key.contains('.request_ports.${Sshrvd.namespace}')) {
      return await _processJSONRequest(notification);
    }
    return _processLegacyRequest(notification);
  }

  static SshrvdSessionParams _processLegacyRequest(
      AtNotification notification) {
    return SshrvdSessionParams(
      sessionId: notification.value!,
      atSignA: notification.from,
    );
  }

  static Future<SshrvdSessionParams> _processJSONRequest(
      AtNotification notification) async {
    dynamic jsonValue = jsonDecode(notification.value ?? '');

    assertValidValue(jsonValue, 'sessionId', String);
    assertValidValue(jsonValue, 'atSignA', String);
    assertValidValue(jsonValue, 'atSignB', String);
    assertValidValue(jsonValue, 'clientNonce', String);
    assertValidValue(jsonValue, 'authenticateSocketA', bool);
    assertValidValue(jsonValue, 'authenticateSocketA', bool);

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
    return SshrvdSessionParams(
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

  static Future<String?> _fetchPublicKey(String atSign,
      {int secondsToWait = 10}) async {
    String? publicKey;
    AtLookupImpl atLookupImpl = AtLookupImpl(atSign, 'root.atsign.org', 64);
    SecondaryAddress secondaryAddress =
        await atLookupImpl.secondaryAddressFinder.findSecondary(atSign);

    SecureSocket secureSocket = await SecureSocket.connect(
        secondaryAddress.host, secondaryAddress.port);

    secureSocket.listen((event) {
      String serverResponse = utf8.decode(event);
      if (serverResponse == '@') {
        secureSocket.write('lookup:publickey$atSign\n');
      } else if (serverResponse.startsWith('data:')) {
        publicKey = serverResponse.replaceFirst('data:', '');
        publicKey = publicKey?.substring(0, publicKey?.indexOf('\n')).trim();
      }
    });

    int totalSecondsWaited = 0;
    while (totalSecondsWaited < secondsToWait) {
      await Future.delayed(Duration(seconds: 1));
      totalSecondsWaited = totalSecondsWaited + 1;
      if (publicKey != null) {
        break;
      }
    }
    await secureSocket.close();
    return publicKey;
  }
}
