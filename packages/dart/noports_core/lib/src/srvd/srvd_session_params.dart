import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/srvd.dart';

class SrvdSessionParams {
  final String sessionId;
  final String? atSignA;
  final String? atSignB;
  final bool authenticateSocketA;
  final bool authenticateSocketB;
  final String? publicKeyA;
  final String? publicKeyB;
  final String? clientNonce;
  final String? rvdNonce;
  final RelayAuthMode relayAuthMode;
  final String? relayAuthAesKey;
  final bool only443;
  final bool sendNacks;

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
    this.relayAuthMode = RelayAuthMode.payload,
    this.relayAuthAesKey,
    required this.only443,
    required this.sendNacks,
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
        'relayAuthMode': relayAuthMode.name,
        'relayAuthAesKey': relayAuthAesKey,
        'only443': only443,
        'sendNacks': sendNacks,
      };
}

class SrvdUtil {
  final AtClient atClient;

  SrvdUtil(this.atClient);

  bool accept(AtNotification notification) {
    return notification.key.contains(Srvd.namespace);
  }

  Future<SrvdSessionParams> getParams(AtNotification notification) async {
    if (notification.key.contains('.request_ports.${Srvd.namespace}')) {
      return await _sessionParamsForJsonRequest(notification);
    }
    return _sessionParamsForAncientClientRequest(notification);
  }

  /// Handles requests from ancient (v3) clients
  SrvdSessionParams _sessionParamsForAncientClientRequest(
      AtNotification notification) {
    return SrvdSessionParams(
      sessionId: notification.value!,
      atSignA: notification.from,
      only443: false,
      sendNacks: false,
    );
  }

  /// Handles requests from all clients v4 onwards
  ///
  /// If session wants v0 authentication, fetch atSigns' public keys here
  ///
  /// When sessions want v1 authentication, we don't until auth time
  /// what signing keys are going to be used, so the spawned isolate
  /// will ask the main isolate to fetch public signing keys
  Future<SrvdSessionParams> _sessionParamsForJsonRequest(
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

    String relayAuthModeName =
        json['relayAuthMode'] ?? RelayAuthMode.payload.name;
    RelayAuthMode relayAuthMode =
        RelayAuthMode.values.byName(relayAuthModeName);
    String? publicKeyA;
    String? publicKeyB;
    if (relayAuthMode == RelayAuthMode.payload && authenticateSocketA) {
      publicKeyA = await _fetchPublicKey(atSignA);
    }
    if (relayAuthMode == RelayAuthMode.payload && authenticateSocketB) {
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
      sendNacks: json['sendNacks'] ?? false,
    );
  }

  Future<String?> _fetchPublicKey(String atSign) async {
    AtValue v = await atClient.get(AtKey.fromString('public:publickey$atSign'));
    return v.value;
  }
}
