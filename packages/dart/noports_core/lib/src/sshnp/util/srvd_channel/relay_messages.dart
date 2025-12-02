import 'dart:convert';

import 'package:noports_core/sshnp_foundation.dart';

class RelayResponse {
  final String address;
  final int portA;
  final int portB;
  final String rvdNonce;
  final bool supportsEventLogging;

  RelayResponse({
    required this.address,
    required this.portA,
    required this.portB,
    required this.rvdNonce,
    required this.supportsEventLogging,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    'portA': portA,
    'portB': portB,
    'rvdNonce': rvdNonce,
    'supportsEventLogging': supportsEventLogging,
  };

  factory RelayResponse.fromJson(Map<String, dynamic> json) {
    return RelayResponse(
      address: json['address'],
      portA: json['portA'],
      portB: json['portB'],
      rvdNonce: json['rvdNonce'],
      supportsEventLogging: json['supportsEventLogging'],
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
    'relayAuthAesKey': relayAuthAesKey,
    'only443': only443,
    'multipleAcksOk': multipleAcksOk,
    'preFetch': preFetch,
    'sendJsonResponse': sendJsonResponse,
  };

  @override
  String toString() => jsonEncode(toJson());
}
