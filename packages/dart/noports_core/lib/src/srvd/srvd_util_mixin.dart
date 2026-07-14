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

  /// Handles requests from all clients v4 onwards
  ///
  /// If session wants v0 authentication, fetch atSigns' public keys here
  ///
  /// When sessions want v1 authentication, we don't until auth time
  /// what signing keys are going to be used, so the spawned isolate
  /// will ask the main isolate to fetch public signing keys
  Future<SrvdSessionParams> srvdSessionParamsFromNotification(
    String encodedJson,
  ) async {
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
      multipleAcksOk: json['multipleAcksOk'] ?? false,
      preFetch: List<String>.from(json['preFetch'] ?? []),
      sendJsonResponse: json['sendJsonResponse'] ?? false,
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
