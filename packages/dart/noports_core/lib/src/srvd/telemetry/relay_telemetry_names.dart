/// The event and attribute names a relay's telemetry carries, which the
/// Control Center's collector and web service read.
abstract final class RelayTelemetryNames {
  /// The service every relay record names.
  static const String serviceName = 'srvd';

  // Events
  static const String sessionStarted = 'noports.relay.session.started';
  static const String sessionConnections = 'noports.relay.session.connections';
  static const String sessionStillRunning =
      'noports.relay.session.still_running';
  static const String sessionEnded = 'noports.relay.session.ended';
  static const String lifecycleStarted = 'noports.relay.lifecycle.started';
  static const String lifecycleHeartbeat = 'noports.relay.lifecycle.heartbeat';
  static const String lifecycleStopped = 'noports.relay.lifecycle.stopped';

  // The session set, on every session record
  static const String relaySessionId = 'noports.relay.session.id';
  static const String sequence = 'noports.relay.session.seq';
  static const String clientSessionId = 'noports.session.id';
  static const String clientAtsign = 'noports.client.atsign';
  static const String deviceAtsign = 'noports.device.atsign';
  static const String deviceVerified = 'noports.device.verified';
  static const String clientVerified = 'noports.client.verified';
  static const String portMode = 'noports.relay.port_mode';
  static const String requestedAtMs = 'noports.relay.session.requested_at_ms';
  static const String establishedAtMs =
      'noports.relay.session.established_at_ms';
  static const String deviceName = 'noports.device.name';

  // Counts and totals on session records
  static const String opens = 'noports.relay.session.opens';
  static const String closes = 'noports.relay.session.closes';
  static const String openConnections = 'noports.relay.session.open_connections';
  static const String tcpConnections = 'noports.relay.session.tcp_connections';
  static const String bytesClientToDevice = 'noports.bytes.client_to_device';
  static const String bytesDeviceToClient = 'noports.bytes.device_to_client';
  static const String endedAtMs = 'noports.relay.session.ended_at_ms';
  static const String durationMs = 'noports.relay.session.duration_ms';
  static const String connectionsUnclosed =
      'noports.relay.session.connections_unclosed';
  static const String endReason = 'noports.relay.session.end_reason';

  // The relay set, on lifecycle records
  static const String openSessions = 'noports.relay.open_sessions';
  static const String optInListAgeSeconds = 'noports.relay.optin_list.age_s';

  // Port modes
  static const String portModePair = 'pair';
  static const String portMode443 = '443';
}

/// Why a reported session ended.
enum RelaySessionEndReason {
  /// The session's connector finished on its own.
  connectionsClosed,

  /// The relay ended it because a signing key one of its sockets was
  /// accepted with has been withdrawn.
  signingKeyWithdrawn,

  /// The relay was stopping.
  relayStopping,
}
