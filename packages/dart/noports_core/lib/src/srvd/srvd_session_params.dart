import 'package:at_client/at_client.dart';
import 'package:noports_core/sshnp_foundation.dart';

/// A session request srvd refused, carrying what srvd needs to tell the
/// requester why.
class SrvdRequestRefused implements Exception {
  SrvdRequestRefused({
    required this.sessionId,
    required bool multipleAcksOk,
    required this.reason,
  }) : nackOk = multipleAcksOk && isValidSessionId(sessionId);

  final String sessionId;

  /// Whether to send the requester a NACK: its client takes one, and the
  /// session id is a UUID, so the NACK's key is well formed.
  final bool nackOk;

  /// Why, as a fixed text naming the field, never the field's value.
  final String reason;

  // NOTE: only a UUID session id is logged; any other text stays out of the
  // log.
  @override
  String toString() => isValidSessionId(sessionId)
      ? 'session $sessionId: $reason'
      : 'a session whose id is not a UUID: $reason';
}

/// One session as srvd relays it, between a client-side and a device-side
/// Atsign.
class SrvdSessionParams {
  /// The session id, in lower case.
  final String sessionId;

  /// The session id as the client sent it, which a payload-mode socket's
  /// signature covers.
  final String sessionIdAsSent;

  /// The client-side Atsign, canonical.
  final Atsign atSignA;

  /// The device-side Atsign, canonical, as the client named it.
  final Atsign atSignB;
  final bool authenticateSocketA;
  final bool authenticateSocketB;
  final String? publicKeyA;
  final String? publicKeyB;
  final String? clientNonce;
  final String rvdNonce;
  final RelayAuthMode relayAuthMode;
  final String? relayAuthAesKey;
  final bool only443;
  final bool multipleAcksOk;
  final List<String> preFetch;
  final bool sendJsonResponse;

  /// Throws [InvalidAtSignException] when [atSignA] or [atSignB] is not a
  /// valid Atsign.
  SrvdSessionParams({
    required this.sessionId,
    String? sessionIdAsSent,
    required String atSignA,
    required String atSignB,
    this.authenticateSocketA = false,
    this.authenticateSocketB = false,
    this.publicKeyA,
    this.publicKeyB,
    required this.rvdNonce,
    this.clientNonce,
    this.relayAuthMode = RelayAuthMode.payload,
    this.relayAuthAesKey,
    required this.only443,
    required this.multipleAcksOk,
    required this.preFetch,
    required this.sendJsonResponse,
  })  : sessionIdAsSent = sessionIdAsSent ?? sessionId,
        atSignA = atSignA.toAtsign(),
        atSignB = atSignB.toAtsign();

  /// These params for a log, with [relayAuthAesKey] redacted.
  @override
  String toString() => {
    ...toJson(),
    if (relayAuthAesKey != null) 'relayAuthAesKey': '(redacted)',
  }.toString();

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
    'multipleAcksOk': multipleAcksOk,
    'preFetch': preFetch,
    'sendJsonResponse': sendJsonResponse,
  };
}
