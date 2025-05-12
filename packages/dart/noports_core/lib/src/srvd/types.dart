import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/srvd.dart';

typedef ConnectorParams = (
  SendPort,
  bool, // logTraffic
  bool, // verbose
  String, // loggingTag
);
typedef PortPair = (int, int);

const int isolateStartTimeoutMs = 500;
const int isolateBindPortsTimeoutMs = 1500;

abstract class RelayWorker {
  final SendPort toMain;
  final bool logTraffic;
  final bool verbose;
  final String loggingTag;
  late final ReceivePort fromMain;
  late final AtSignLogger logger;

  RelayWorker({
    required this.toMain,
    required this.logTraffic,
    required this.verbose,
    required this.loggingTag,
  }) {
    AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
    AtSignLogger.root_level = verbose ? 'INFO' : 'WARNING';
    logger = AtSignLogger(' srvd / $runtimeType / $loggingTag ');

    // Make a ReceivePort so the main isolate can send messages to us
    // and send it to the main isolate
    fromMain = ReceivePort(loggingTag);
    toMain.send(fromMain.sendPort);
  }

  Future<void> run();

  Future<void> stop();
}

/// Wrapper for inter-isolate requests
class IIRequest {
  final int id;
  final String type;
  final dynamic payload;

  IIRequest({
    required this.id,
    required this.type,
    required this.payload,
  });

  factory IIRequest.create(
    String type,
    dynamic payload,
  ) =>
      IIRequest(
        id: DateTime.now().microsecondsSinceEpoch,
        type: type,
        payload: payload,
      );
}

/// Wrapper for responses to inter-isolate requests
class IIResponse {
  final int id;
  final bool isError;
  final dynamic payload;

  IIResponse({
    required this.id,
    required this.isError,
    required this.payload,
  });
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
