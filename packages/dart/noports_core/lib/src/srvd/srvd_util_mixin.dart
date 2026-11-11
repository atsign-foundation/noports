import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
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
              'unknown "$messageType" request received from ${n.from}',
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

  /// The device name a session request's key names, its first segment
  /// lower-cased as [wellFormedRequest] lower-cases the key, when it matches
  /// [sshnpDeviceNameRegex] in full; null otherwise.
  String? deviceNameFromRequestKey(AtNotification n) {
    final topicParts = n.key
        .replaceAll('${n.to}:', '')
        .replaceAll('.${Srvd.namespace}${n.from}', '')
        .toLowerCase()
        .split('.');
    if (topicParts.length != 2 || topicParts.last != 'request_ports') {
      return null;
    }
    final name = topicParts.first;
    return RegExp('^$sshnpDeviceNameRegex\$').hasMatch(name) ? name : null;
  }

  /// Reads a session request's fields, from clients v4 onwards, without
  /// looking anything up; [withPayloadKeys] adds the public keys a
  /// payload-mode session needs.
  ///
  /// Throws [FormatException] when [encodedJson] is not JSON, and
  /// [ArgumentError] when it is not a map with a string sessionId. Once the
  /// session id is read, throws [SrvdRequestRefused] when a field is missing
  /// or malformed, naming the field and why, including when the session id
  /// is not a UUID, or atSignA or atSignB is not a valid Atsign.
  SrvdSessionParams srvdSessionParamsFromJson(String encodedJson) {
    final Object? json = jsonDecode(encodedJson);
    if (json is! Map || json['sessionId'] is! String) {
      throw ArgumentError('A session request must be a map with a sessionId');
    }
    // NOTE: folded, so that every comparison and record key agrees on it
    final String sessionId = (json['sessionId'] as String).toLowerCase();

    Never refuse(String reason) => throw SrvdRequestRefused(
          sessionId: sessionId,
          multipleAcksOk: json['multipleAcksOk'] == true,
          reason: reason,
        );
    if (!isValidSessionId(sessionId)) {
      refuse('Parameter sessionId must be a UUID');
    }
    T required<T>(String name, String what) {
      final Object? v = json[name];
      return v is T ? v : refuse('Parameter $name must be $what');
    }

    T? optional<T>(String name, String what) {
      final Object? v = json[name];
      if (v is T?) return v;
      refuse('Parameter $name must be $what when present');
    }

    Atsign atsign(String name) {
      final String value = required<String>(name, 'a String');
      try {
        return value.toAtsign();
      } on InvalidAtSignException catch (e) {
        refuse('Parameter $name is not a valid Atsign: ${e.message}');
      }
    }

    final Atsign atSignA = atsign('atSignA');
    final Atsign atSignB = atsign('atSignB');
    final String clientNonce = required<String>('clientNonce', 'a String');
    final bool authenticateSocketA =
        required<bool>('authenticateSocketA', 'a bool');
    final bool authenticateSocketB =
        required<bool>('authenticateSocketB', 'a bool');
    final String relayAuthModeName =
        optional<String>('relayAuthMode', 'a String') ??
            RelayAuthMode.payload.name;
    final RelayAuthMode relayAuthMode =
        RelayAuthMode.values.asNameMap()[relayAuthModeName] ??
            refuse('Parameter relayAuthMode must name a relay auth mode');
    final List preFetch =
        optional<List>('preFetch', 'a list of strings') ?? const [];
    if (preFetch.any((e) => e is! String)) {
      refuse('Parameter preFetch must be a list of strings');
    }

    return SrvdSessionParams(
      sessionId: sessionId,
      atSignA: atSignA,
      atSignB: atSignB,
      authenticateSocketA: authenticateSocketA,
      authenticateSocketB: authenticateSocketB,
      rvdNonce: DateTime.now().toIso8601String(),
      clientNonce: clientNonce,
      relayAuthMode: relayAuthMode,
      relayAuthAesKey: optional<String>('relayAuthAesKey', 'a String'),
      only443: optional<bool>('only443', 'a bool') ?? false,
      multipleAcksOk: optional<bool>('multipleAcksOk', 'a bool') ?? false,
      preFetch: List<String>.from(preFetch),
      sendJsonResponse: optional<bool>('sendJsonResponse', 'a bool') ?? false,
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

  Future<String?> _fetchPublicKey(String atSign) =>
      getRemotePK(atClient: atClient, atSign: atSign);
}
