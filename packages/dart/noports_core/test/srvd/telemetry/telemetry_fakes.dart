import 'dart:async';

import 'package:at_telemetry/at_telemetry.dart';
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:noports_core/src/srvd/telemetry/opted_in_list.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry.dart';

/// Keeps every record it is given, answering [delivers] for each.
class RecordingExporter implements AtTelemetryLogRecordExporter {
  final List<AtTelemetryLogRecord> records = [];
  AtTelemetryResource? resource;
  bool delivers = true;
  bool shutDown = false;

  /// The records named [event], in order.
  List<AtTelemetryLogRecord> named(String event) =>
      records.where((r) => r.eventName == event).toList();

  @override
  Future<bool> export(
    AtTelemetryLogRecord logRecord,
    AtTelemetryResource resource,
  ) async {
    records.add(logRecord);
    this.resource = resource;
    return delivers;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> shutdown() async {
    shutDown = true;
  }
}

/// Answers each read with [list], or throws while [list] is null.
class ScriptedListSource implements OptedInListSource {
  OptedInList? list;
  int reads = 0;

  ScriptedListSource([this.list]);

  @override
  Future<OptedInList> read() async {
    reads++;
    final OptedInList? answer = list;
    if (answer == null) throw StateError('the list cannot be read');
    return answer;
  }
}

OptedInList listOf(Iterable<String> atsigns, {DateTime? builtAt}) =>
    OptedInList(
      builtAt: builtAt ?? DateTime.timestamp(),
      atsigns: atsigns.toSet(),
    );

SrvdSessionParams sessionParams({
  String sessionId = 'the-session',
  String client = '@alice',
  String device = '@carol',
  bool deviceVerified = true,
  bool clientVerified = true,
  bool only443 = false,
}) =>
    SrvdSessionParams(
      sessionId: sessionId,
      atSignA: client,
      atSignB: device,
      authenticateSocketA: clientVerified,
      authenticateSocketB: deviceVerified,
      rvdNonce: 'rvd nonce',
      only443: only443,
      multipleAcksOk: true,
      preFetch: const [],
      sendJsonResponse: true,
    );

SessionInfo sessionInfo(SrvdSessionParams params, {String? deviceName}) =>
    SessionInfo(params: params, connector: null)..deviceName = deviceName;

int nowMs() => DateTime.timestamp().millisecondsSinceEpoch;

Map<String, dynamic> opened(int index, {int? at}) => {
      'sessionId': 'the-session',
      'at': at ?? nowMs(),
      'index': index,
      'client': {'ip': '10.0.0.1', 'port': 40000 + index},
      'device': {'ip': '10.0.0.2', 'port': 50000 + index},
    };

Map<String, dynamic> closed(
  int index, {
  required int openedAt,
  int? closedAt,
  int c2d = 0,
  int d2c = 0,
}) {
  final int at = closedAt ?? nowMs();
  return {
    'sessionId': 'the-session',
    'at': at,
    'index': index,
    'openedAt': openedAt,
    'closedAt': at,
    'bytesClientToDevice': c2d,
    'bytesDeviceToClient': d2c,
  };
}

/// Telemetry over [exporter] whose list comes from [source], started and
/// holding its first good read when the source has one.
Future<RelayTelemetry> startedTelemetry(
  RecordingExporter exporter,
  ScriptedListSource source, {
  Duration window = const Duration(milliseconds: 100),
  Duration maxWindow = const Duration(milliseconds: 400),
  int maxEntries = RelayTelemetry.defaultMaxEntries,
  int Function()? backlog,
  Duration listInterval = const Duration(days: 1),
  Duration heartbeatInterval = const Duration(days: 1),
  void Function(String)? onWarning,
}) async {
  final telemetry = RelayTelemetry(
    exporter: exporter,
    serviceVersion: 'srvd 9.9.9 (core 9.9.9)',
    window: window,
    maxWindow: maxWindow,
    maxEntries: maxEntries,
    backlog: backlog,
    heartbeatInterval: heartbeatInterval,
    list: OptedInListPoller(
      source: source,
      interval: listInterval,
      firstRetryFrom: const Duration(milliseconds: 20),
      firstRetryTo: const Duration(milliseconds: 40),
      laterRetryFrom: const Duration(milliseconds: 20),
      onWarning: onWarning ?? (_) {},
    ),
  );
  telemetry.start();
  if (source.list != null) {
    await telemetry.list.firstGoodRead.timeout(const Duration(seconds: 2));
  }
  return telemetry;
}

/// Waits up to 5 seconds for [condition].
Future<void> until(bool Function() condition, {String? what}) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('waited for ${what ?? 'a condition'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
