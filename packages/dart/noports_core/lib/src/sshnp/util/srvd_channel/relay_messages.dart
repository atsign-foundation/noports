import 'dart:convert';

import 'package:noports_core/sshnp_foundation.dart';

class RelayResponse {
  final String address;
  final int portA;
  final int portB;
  final String rvdNonce;
  final bool supportsEventLogging;

  /// Whether this relay authenticates each side by its own relay-auth mode,
  /// taking side B's from the client's auth_modes notification when the
  /// request leaves it open. Only such a relay can reconcile a client and
  /// daemon that use different modes; against a relay that does not (older
  /// releases, and the CSV response format), the client must fall back to
  /// legacy for both sides. Absent in older/CSV responses -> false.
  final bool autoDetectsRelayAuth;

  /// Whether this relay applied the per-side `relayAuthModes` of the request,
  /// ignoring its `relayAuthMode` and any auth_modes notification. Absent
  /// from the response when false.
  final bool appliedRelayAuthModes;

  RelayResponse({
    required this.address,
    required this.portA,
    required this.portB,
    required this.rvdNonce,
    required this.supportsEventLogging,
    this.autoDetectsRelayAuth = false,
    this.appliedRelayAuthModes = false,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    'portA': portA,
    'portB': portB,
    'rvdNonce': rvdNonce,
    'supportsEventLogging': supportsEventLogging,
    'autoDetectsRelayAuth': autoDetectsRelayAuth,
    if (appliedRelayAuthModes) 'appliedRelayAuthModes': true,
  };

  factory RelayResponse.fromJson(Map<String, dynamic> json) {
    return RelayResponse(
      address: json['address'],
      portA: json['portA'],
      portB: json['portB'],
      rvdNonce: json['rvdNonce'],
      supportsEventLogging: json['supportsEventLogging'],
      autoDetectsRelayAuth: json['autoDetectsRelayAuth'] ?? false,
      appliedRelayAuthModes: json['appliedRelayAuthModes'] == true,
    );
  }
}

class RelayRequest {
  final String sessionId;
  final String atSignA;
  final String atSignB;
  final bool authenticateSocketA;
  final bool authenticateSocketB;
  final String clientNonce;
  final RelayAuthMode relayAuthMode;

  /// Each side's mode, which a relay that reads it applies in place of
  /// [relayAuthMode].
  final RelayAuthModes relayAuthModes;
  final String? relayAuthAesKey;
  final bool only443;
  final bool multipleAcksOk;
  final List<String> preFetch;
  final bool sendJsonResponse;

  RelayRequest({
    required this.sessionId,
    required this.atSignA,
    required this.atSignB,
    required this.authenticateSocketA,
    required this.authenticateSocketB,
    required this.clientNonce,
    required this.relayAuthMode,
    required this.relayAuthModes,
    required this.relayAuthAesKey,
    required this.only443,
    required this.multipleAcksOk,
    required this.preFetch,
    required this.sendJsonResponse,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'atSignA': atSignA,
    'atSignB': atSignB,
    'authenticateSocketA': authenticateSocketA,
    'authenticateSocketB': authenticateSocketB,
    'clientNonce': clientNonce,
    'relayAuthMode': relayAuthMode.name,
    'relayAuthModes': {
      'sideA': relayAuthModes.sideA.name,
      'sideB': relayAuthModes.sideB.name,
    },
    'relayAuthAesKey': relayAuthAesKey,
    'only443': only443,
    'multipleAcksOk': multipleAcksOk,
    'preFetch': preFetch,
    'sendJsonResponse': sendJsonResponse,
  };

  @override
  String toString() => jsonEncode(toJson());
}
