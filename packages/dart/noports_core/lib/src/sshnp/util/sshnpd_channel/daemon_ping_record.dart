import 'dart:convert';

import 'package:noports_core/src/common/features.dart';

/// What a daemon's ping response says about how it authenticates to a relay.
class DaemonRelayAuthSupport {
  /// Whether the daemon advertised [DaemonFeature.supportsRamEscr].
  final bool supportsRamEscr;

  /// The URI of the daemon's public signing key, for the relay to prefetch.
  final String? publicSigningKeyUri;

  const DaemonRelayAuthSupport({
    required this.supportsRamEscr,
    required this.publicSigningKeyUri,
  });

  /// What [pingResponse] says; a response that names no features does not
  /// support ESCR.
  factory DaemonRelayAuthSupport.fromPingResponse(Map pingResponse) {
    final Object? features = pingResponse['supportedFeatures'];
    final Object? uri = pingResponse['publicSigningKeyUri'];
    return DaemonRelayAuthSupport(
      supportsRamEscr:
          features is Map &&
          features[DaemonFeature.supportsRamEscr.name] == true,
      publicSigningKeyUri: uri is String ? uri : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DaemonRelayAuthSupport &&
      other.supportsRamEscr == supportsRamEscr &&
      other.publicSigningKeyUri == publicSigningKeyUri;

  @override
  int get hashCode => Object.hash(supportsRamEscr, publicSigningKeyUri);

  @override
  String toString() => jsonEncode({
    'supportsRamEscr': supportsRamEscr,
    'publicSigningKeyUri': publicSigningKeyUri,
  });
}

/// A client's record, on its own atServer, of what a daemon device's last ping
/// response said about its relay authentication.
class DaemonPingRecord {
  /// When the client wrote the record.
  final DateTime storedAt;

  /// What the ping response said.
  final DaemonRelayAuthSupport support;

  const DaemonPingRecord({required this.storedAt, required this.support});

  /// The record [value] holds. Throws when [value] is not a record's JSON.
  factory DaemonPingRecord.decode(Object? value) {
    final Map json = jsonDecode(value as String) as Map;
    return DaemonPingRecord(
      storedAt: DateTime.parse(json['storedAt'] as String),
      support: DaemonRelayAuthSupport(
        supportsRamEscr: json['supportsRamEscr'] as bool,
        publicSigningKeyUri: json['publicSigningKeyUri'] as String?,
      ),
    );
  }

  /// The record's value: its three fields and nothing else.
  String encode() => jsonEncode({
    'storedAt': storedAt.toUtc().toIso8601String(),
    'supportsRamEscr': support.supportsRamEscr,
    'publicSigningKeyUri': support.publicSigningKeyUri,
  });
}
