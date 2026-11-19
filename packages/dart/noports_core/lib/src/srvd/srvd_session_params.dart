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

/// The relay auth mode of each side of a session, as a session request names
/// them in its `relayAuthModes`.
typedef RelayAuthModes = ({RelayAuthMode sideA, RelayAuthMode sideB});

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

  /// Each side's mode as the request named it, or null when the request named
  /// none and [relayAuthMode] and [relayAuthAesKey] decide.
  final RelayAuthModes? relayAuthModes;
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
    required this.relayAuthModes,
    required this.only443,
    required this.multipleAcksOk,
    required this.preFetch,
    required this.sendJsonResponse,
  })  : sessionIdAsSent = sessionIdAsSent ?? sessionId,
        atSignA = atSignA.toAtsign(),
        atSignB = atSignB.toAtsign();

  /// The mode side A's sockets authenticate by: as [relayAuthModes] names it,
  /// otherwise legacy for a payload request with no [relayAuthAesKey], and
  /// ESCR for any other.
  RelayAuthMode get sideAMode =>
      relayAuthModes?.sideA ??
      (relayAuthMode == RelayAuthMode.payload && relayAuthAesKey == null
          ? RelayAuthMode.payload
          : RelayAuthMode.escr);

  /// The mode side B's sockets authenticate by, or null when the client names
  /// it in its auth_modes notification: as [relayAuthModes] names it,
  /// otherwise [relayAuthMode], except that a payload request with a
  /// [relayAuthAesKey] leaves it to the client.
  RelayAuthMode? get sideBMode {
    final RelayAuthModes? named = relayAuthModes;
    if (named != null) return named.sideB;
    if (relayAuthMode == RelayAuthMode.escr) return RelayAuthMode.escr;
    return relayAuthAesKey == null ? RelayAuthMode.payload : null;
  }

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
    'relayAuthModes': switch (relayAuthModes) {
      null => null,
      final m => {'sideA': m.sideA.name, 'sideB': m.sideB.name},
    },
    'only443': only443,
    'multipleAcksOk': multipleAcksOk,
    'preFetch': preFetch,
    'sendJsonResponse': sendJsonResponse,
  };
}
