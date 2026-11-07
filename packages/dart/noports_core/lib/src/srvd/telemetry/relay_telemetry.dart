import 'dart:async';
import 'dart:math';

import 'package:at_client/at_client.dart';
import 'package:at_telemetry/at_telemetry.dart';
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/telemetry/opted_in_list.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry_names.dart';
import 'package:uuid/uuid.dart';

/// Turns the relay's view of its sessions into telemetry records for the
/// sessions whose client, or verified device, is on the opted-in list, and
/// sends lifecycle records for the relay itself.
///
/// Every method is synchronous apart from [stop], and none throws: a failure
/// is logged and the relay carries on.
class RelayTelemetry {
  static const Duration defaultWindow = Duration(seconds: 2);
  static const Duration defaultMaxWindow = Duration(seconds: 60);
  static const int defaultMaxEntries = 100;
  static const int defaultBacklogThreshold = 10;
  static const Duration defaultHeartbeatInterval = Duration(seconds: 60);
  static const Duration defaultShutdownTimeout = Duration(seconds: 5);
  static const Duration defaultDropReportInterval = Duration(minutes: 1);
  static final RegExp _clientSessionIdShape = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  RelayTelemetry({
    required AtTelemetryLogRecordExporter exporter,
    required this.list,
    required String serviceVersion,
    int Function()? backlog,
    this.window = defaultWindow,
    this.maxWindow = defaultMaxWindow,
    this.maxEntries = defaultMaxEntries,
    this.backlogThreshold = defaultBacklogThreshold,
    this.heartbeatInterval = defaultHeartbeatInterval,
    this.shutdownTimeout = defaultShutdownTimeout,
    this.dropReportInterval = defaultDropReportInterval,
    AtSignLogger? logger,
    Random? random,
    String? instanceId,
  })  : _backlog = backlog ?? (() => 0),
        _logger = logger ?? AtSignLogger(' srvd telemetry '),
        _random = random ?? Random(),
        instanceId = instanceId ?? const Uuid().v4(),
        _currentWindow = window {
    _telemetry = AtTelemetry(
      serviceName: RelayTelemetryNames.serviceName,
      resourceAttributes: {
        AtTelemetryAttributes.serviceVersion: serviceVersion,
        AtTelemetryAttributes.serviceInstanceId: this.instanceId,
      },
      exporter: exporter,
      onError: _onError,
    );
  }

  final OptedInListPoller list;
  final Duration window;
  final Duration maxWindow;
  final int maxEntries;
  final int backlogThreshold;
  final Duration heartbeatInterval;
  final Duration shutdownTimeout;
  final Duration dropReportInterval;
  final String instanceId;
  final int Function() _backlog;
  final AtSignLogger _logger;
  final Random _random;

  late final AtTelemetry _telemetry;
  final Map<String, _Session> _sessions = {};
  Duration _currentWindow;
  Timer? _heartbeat;
  Timer? _dropReport;
  int _dropped = 0;
  bool _stopping = false;

  /// Sessions that have paired and not ended, reported or not.
  int get openSessions => _sessions.length;

  /// Whether the session [sessionId] is being reported; null when it has
  /// not paired or has ended.
  bool? reporting(String sessionId) => _sessions[sessionId]?.reported;

  /// Starts reading the opted-in list, sends the started record and starts
  /// the heartbeat.
  void start() {
    _guard('start', () {
      list.start();
      _lifecycle(RelayTelemetryNames.lifecycleStarted);
      _dropReport = Timer.periodic(dropReportInterval, (_) => _reportDrops());
      _heartbeat = Timer(
        Duration(
          microseconds:
              (heartbeatInterval.inMicroseconds * _random.nextDouble()).round(),
        ),
        () {
          _sendHeartbeat();
          _heartbeat = Timer.periodic(
            heartbeatInterval,
            (_) => _sendHeartbeat(),
          );
        },
      );
    });
  }

  /// A worker reported a connection of [sessionId] pairing. The first pair
  /// decides, once, whether the session is reported.
  void connectionOpened(
    String sessionId,
    SessionInfo si,
    Map<String, dynamic> payload,
  ) {
    _guard('newConnection', () {
      final int at = payload['at'] as int;
      final _Session s = _sessions.putIfAbsent(sessionId, () {
        final session = _Session(si, at, _decide(si));
        if (session.reported) {
          _event(session, RelayTelemetryNames.sessionStarted, at, {});
        }
        return session;
      });
      s.opened++;
      if (!s.reported) return;
      _add(s, {
        'i': payload['index'],
        'e': 'open',
        't': at,
        if (_peer(payload['client']) case final peer?) 'c': peer,
        if (_peer(payload['device']) case final peer?) 'd': peer,
      });
    });
  }

  /// A worker reported a connection of [sessionId] closed.
  void connectionClosed(String sessionId, Map<String, dynamic> payload) {
    _guard('connectionClosed', () {
      final _Session? s = _sessions[sessionId];
      if (s == null) return;
      final int c2d = payload['bytesClientToDevice'] as int;
      final int d2c = payload['bytesDeviceToClient'] as int;
      s.closed++;
      s.bytesClientToDevice += c2d;
      s.bytesDeviceToClient += d2c;
      if (!s.reported) return;
      final int openedAt = payload['openedAt'] as int;
      final int closedAt = payload['closedAt'] as int;
      _add(s, {
        'i': payload['index'],
        'e': 'close',
        't': closedAt,
        'dur': max(0, closedAt - openedAt),
        'c2d': c2d,
        'd2c': d2c,
      });
    });
  }

  /// A worker reported [sessionId]'s progress; a reported session with no
  /// connections record since the last report gets a still-running record.
  void progress(String sessionId, Map<String, dynamic> payload) {
    _guard('progress', () {
      final _Session? s = _sessions[sessionId];
      if (s == null || !s.reported) return;
      final bool quiet = !s.connectionsSinceTick && s.pending.isEmpty;
      s.connectionsSinceTick = false;
      if (!quiet) return;
      _event(s, RelayTelemetryNames.sessionStillRunning, payload['at'] as int, {
        RelayTelemetryNames.openConnections: payload['openConnections'],
        RelayTelemetryNames.tcpConnections: payload['connections'],
        RelayTelemetryNames.bytesClientToDevice: payload['bytesClientToDevice'],
        RelayTelemetryNames.bytesDeviceToClient: payload['bytesDeviceToClient'],
      });
    });
  }

  /// A worker reported [sessionId] complete: pending entries go out, then
  /// the ended record, and the session is forgotten.
  void sessionCompleted(
    String sessionId,
    Map<String, dynamic> payload,
    RelaySessionEndReason reason,
  ) {
    _guard('sessionComplete', () {
      final _Session? s = _sessions.remove(sessionId);
      if (s == null) return;
      _ended(
        s,
        at: payload['at'] as int,
        connections: payload['connections'] as int? ?? s.opened,
        bytesClientToDevice:
            payload['bytesClientToDevice'] as int? ?? s.bytesClientToDevice,
        bytesDeviceToClient:
            payload['bytesDeviceToClient'] as int? ?? s.bytesDeviceToClient,
        unclosed: payload['connectionsUnclosed'] as int? ?? 0,
        reason: reason,
      );
    });
  }

  /// Ends every session still held as stopping, sends the stopped record,
  /// and gives the exporter at most [shutdownTimeout] to send what is left.
  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    _guard('stop', () {
      list.stop();
      _heartbeat?.cancel();
      _dropReport?.cancel();
      final int now = DateTime.timestamp().millisecondsSinceEpoch;
      for (final s in _sessions.values.toList()) {
        _ended(
          s,
          at: now,
          connections: s.opened,
          bytesClientToDevice: s.bytesClientToDevice,
          bytesDeviceToClient: s.bytesDeviceToClient,
          unclosed: s.opened - s.closed,
          reason: RelaySessionEndReason.relayStopping,
        );
      }
      _sessions.clear();
      _lifecycle(RelayTelemetryNames.lifecycleStopped);
    });
    try {
      await _telemetry.shutdown(timeout: shutdownTimeout);
    } catch (e) {
      _logger.warning('Telemetry shutdown failed: $e');
    }
    _reportDrops();
  }

  bool _decide(SessionInfo si) {
    if (list.listed(_canonical(si.params.atSignA))) return true;
    return si.params.authenticateSocketB &&
        list.listed(_canonical(si.params.atSignB));
  }

  void _add(_Session s, Map<String, Object?> entry) {
    s.pending.add(entry);
    if (s.pending.length >= maxEntries) {
      _flush(s);
      return;
    }
    s.window ??= Timer(_nextWindow(), () => _guard('window', () => _flush(s)));
  }

  /// The length of the next window: [window], doubled at each new window
  /// while the exporter holds more than [backlogThreshold] unsent batches,
  /// up to [maxWindow].
  Duration _nextWindow() {
    if (_backlog() > backlogThreshold) {
      _currentWindow = Duration(
        microseconds: min(
          _currentWindow.inMicroseconds * 2,
          maxWindow.inMicroseconds,
        ),
      );
    } else {
      _currentWindow = window;
    }
    return _currentWindow;
  }

  void _flush(_Session s) {
    s.window?.cancel();
    s.window = null;
    if (s.pending.isEmpty) return;
    final List<Map<String, Object?>> entries = s.pending;
    s.pending = [];
    final int opens = entries.where((e) => e['e'] == 'open').length;
    s.connectionsSinceTick = true;
    _event(
      s,
      RelayTelemetryNames.sessionConnections,
      DateTime.timestamp().millisecondsSinceEpoch,
      {
        RelayTelemetryNames.opens: opens,
        RelayTelemetryNames.closes: entries.length - opens,
        RelayTelemetryNames.openConnections: s.opened - s.closed,
        RelayTelemetryNames.bytesClientToDevice: s.bytesClientToDevice,
        RelayTelemetryNames.bytesDeviceToClient: s.bytesDeviceToClient,
      },
      body: entries,
    );
  }

  void _ended(
    _Session s, {
    required int at,
    required int connections,
    required int bytesClientToDevice,
    required int bytesDeviceToClient,
    required int unclosed,
    required RelaySessionEndReason reason,
  }) {
    if (!s.reported || s.endedSent) return;
    _flush(s);
    s.endedSent = true;
    _event(s, RelayTelemetryNames.sessionEnded, at, {
      RelayTelemetryNames.endedAtMs: at,
      RelayTelemetryNames.durationMs: max(0, at - s.establishedAt),
      RelayTelemetryNames.bytesClientToDevice: bytesClientToDevice,
      RelayTelemetryNames.bytesDeviceToClient: bytesDeviceToClient,
      RelayTelemetryNames.tcpConnections: connections,
      RelayTelemetryNames.connectionsUnclosed: unclosed,
      RelayTelemetryNames.endReason: reason.name,
    });
  }

  void _event(
    _Session s,
    String name,
    int at,
    Map<String, Object?> attributes, {
    Object? body,
  }) {
    _telemetry.event(
      name,
      timestamp: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      attributes: {..._sessionSet(s), ...attributes},
      body: body,
    );
  }

  Map<String, Object?> _sessionSet(_Session s) {
    final params = s.info.params;
    return {
      RelayTelemetryNames.relaySessionId: s.id,
      RelayTelemetryNames.sequence: ++s.seq,
      if (_clientSessionIdShape.hasMatch(params.sessionId))
        RelayTelemetryNames.clientSessionId: params.sessionId,
      RelayTelemetryNames.clientAtsign: _canonical(params.atSignA),
      RelayTelemetryNames.deviceAtsign: _canonical(params.atSignB),
      RelayTelemetryNames.deviceVerified: params.authenticateSocketB,
      RelayTelemetryNames.clientVerified: params.authenticateSocketA,
      RelayTelemetryNames.portMode: params.only443
          ? RelayTelemetryNames.portMode443
          : RelayTelemetryNames.portModePair,
      RelayTelemetryNames.requestedAtMs:
          s.info.requestTime.millisecondsSinceEpoch,
      RelayTelemetryNames.establishedAtMs: s.establishedAt,
      if (s.info.deviceName != null)
        RelayTelemetryNames.deviceName: s.info.deviceName,
    };
  }

  void _sendHeartbeat() =>
      _guard('heartbeat', () => _lifecycle(RelayTelemetryNames.lifecycleHeartbeat));

  void _lifecycle(String name) {
    final Duration? age = list.age;
    _telemetry.event(
      name,
      timestamp: DateTime.timestamp(),
      attributes: {
        RelayTelemetryNames.openSessions: _sessions.length,
        if (age != null) RelayTelemetryNames.optInListAgeSeconds: age.inSeconds,
      },
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (error is AtTelemetryDroppedException) {
      _dropped++;
      return;
    }
    if (_stopping && error is StateError) return;
    _logger.warning('Telemetry failed: $error');
  }

  void _reportDrops() {
    if (_dropped == 0) return;
    _logger.warning(
      'Lost $_dropped telemetry record(s) in the last minute: they could not'
      ' be sent to the collector and nothing retries them',
    );
    _dropped = 0;
  }

  void _guard(String what, void Function() action) {
    try {
      action();
    } catch (e, st) {
      _logger.warning('Telemetry failed in $what: $e\n$st');
    }
  }

  /// A peer's address as a plain map, or null when the worker sent none.
  static Map<String, Object?>? _peer(Object? value) {
    if (value is! Map) return null;
    return <String, Object?>{'ip': value['ip'], 'port': value['port']};
  }

  static String _canonical(String atsign) {
    try {
      return atsign.toAtsign().toString();
    } catch (_) {
      return atsign;
    }
  }
}

class _Session {
  _Session(this.info, this.establishedAt, this.reported);

  final SessionInfo info;
  final int establishedAt;
  final bool reported;
  final String id = const Uuid().v4();
  int seq = 0;
  int opened = 0;
  int closed = 0;
  int bytesClientToDevice = 0;
  int bytesDeviceToClient = 0;
  List<Map<String, Object?>> pending = [];
  Timer? window;
  bool connectionsSinceTick = false;
  bool endedSent = false;
}
