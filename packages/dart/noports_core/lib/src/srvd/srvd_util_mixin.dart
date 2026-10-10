import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/relay_messages.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp_foundation.dart';

mixin SrvdUtilMixin {
  AtSignLogger get logger;

  AtClient get atClient;

  /// - `<device>.request_ports.sshrvd`
  /// - `logging.<sessionId>.sessions.sshrvd`
  bool wellFormedRequest(AtNotification n, {bool throwIfFalse = true}) {
    if (n.value == null) {
      if (throwIfFalse) {
        throw ArgumentError('No content in notification ${n.key}');
      }
      return false;
    }
    try {
      String topic;
      String messageType;
      try {
        final topicParts = n.key
            .replaceAll('${n.to}:', '')
            .replaceAll('.${Srvd.namespace}${n.from}', '')
            .toLowerCase()
            .split('.');
        messageType = topicParts.removeLast();
        topic = topicParts.join('.');
      } catch (e) {
        if (throwIfFalse) {
          throw ArgumentError('malformed notification key ${n.key}');
        }
        return false;
      }

      switch (messageType) {
        case 'request_ports':
          return topic.split('.').length == 1;
        case 'auth_modes':
          return topic.split('.').length == 1;
        case 'sessions':
          final parts = topic.split('.');
          if (parts.length != 2) {
            if (throwIfFalse) {
              throw ArgumentError('Invalid sessions sub-topic $topic');
            }
            return false;
          }
          String sessionsMessageType = parts[0];
          switch (sessionsMessageType) {
            case 'logging':
              return true;
            default:
              if (throwIfFalse) {
                throw ArgumentError('Invalid sessions sub-topic $topic');
              }
              return false;
          }
        case 'discover_request':
          return true;

        default:
          if (throwIfFalse) {
            throw ArgumentError(
              'unknown "$messageType" request received from ${n.from}'
              ' ( ${n.value} )',
            );
          }
          return false;
      }
    } catch (e, st) {
      logger.shout(
        'Exception $e while checking if notification should be accepted\n'
        'Stack Trace:\n'
        '$st',
      );
      if (throwIfFalse) {
        rethrow;
      }
      return false;
    }
  }

  /// Reads a session request's fields, from clients v4 onwards, without
  /// looking anything up; [withPayloadKeys] adds the public keys a
  /// payload-mode session needs.
  SrvdSessionParams srvdSessionParamsFromJson(String encodedJson) {
    dynamic json = jsonDecode(encodedJson);
    logger.info('Received session request JSON: $json');

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
    RelayAuthMode relayAuthMode = RelayAuthMode.values.byName(
      relayAuthModeName,
    );
    return SrvdSessionParams(
      sessionId: sessionId,
      atSignA: atSignA,
      atSignB: atSignB,
      authenticateSocketA: authenticateSocketA,
      authenticateSocketB: authenticateSocketB,
      rvdNonce: rvdSessionNonce,
      clientNonce: clientNonce,
      relayAuthMode: relayAuthMode,
      relayAuthAesKey: json['relayAuthAesKey'],
      only443: json['only443'] ?? false,
      multipleAcksOk: json['multipleAcksOk'] ?? false,
      preFetch: List<String>.from(json['preFetch'] ?? []),
      sendJsonResponse: json['sendJsonResponse'] ?? false,
    );
  }

  /// [params] with the public key of each side that authenticates, when the
  /// session is in payload mode; [params] itself otherwise. ESCR sessions
  /// look their signing keys up at socket-auth time instead.
  Future<SrvdSessionParams> withPayloadKeys(SrvdSessionParams params) async {
    if (params.relayAuthMode != RelayAuthMode.payload ||
        !(params.authenticateSocketA || params.authenticateSocketB)) {
      return params;
    }
    return SrvdSessionParams(
      sessionId: params.sessionId,
      atSignA: params.atSignA,
      atSignB: params.atSignB,
      authenticateSocketA: params.authenticateSocketA,
      authenticateSocketB: params.authenticateSocketB,
      publicKeyA: params.authenticateSocketA
          ? await _fetchPublicKey(params.atSignA)
          : null,
      publicKeyB: params.authenticateSocketB
          ? await _fetchPublicKey(params.atSignB)
          : null,
      rvdNonce: params.rvdNonce,
      clientNonce: params.clientNonce,
      relayAuthMode: params.relayAuthMode,
      relayAuthAesKey: params.relayAuthAesKey,
      only443: params.only443,
      multipleAcksOk: params.multipleAcksOk,
      preFetch: params.preFetch,
      sendJsonResponse: params.sendJsonResponse,
    );
  }

  String createResponseValue(
    String ipAddress,
    int portA,
    int portB,
    SrvdSessionParams sessionParams,
  ) {
    if (sessionParams.sendJsonResponse) {
      return jsonEncode(
        RelayResponse(
          address: ipAddress,
          portA: portA,
          portB: portB,
          rvdNonce: sessionParams.rvdNonce,
          supportsEventLogging: true,
          // This srvd auto-detects each socket's relay-auth mode per side, so
          // clients may safely use their strongest mode independently.
          autoDetectsRelayAuth: true,
        ),
      );
    } else {
      return '$ipAddress,$portA,$portB,${sessionParams.rvdNonce}';
    }
  }

  Future<String?> _fetchPublicKey(String atSign) async {
    AtValue v = await atClient.get(AtKey.fromString('public:publickey$atSign'));
    return v.value;
  }
}
