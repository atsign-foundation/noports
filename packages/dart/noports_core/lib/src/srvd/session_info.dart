import 'dart:isolate';

import 'package:noports_core/events.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:socket_connector/socket_connector.dart';

class SessionInfo {
  final SrvdSessionParams params;
  final SocketConnector? connector;
  final Map<String, String> lookups = {};

  Stats? stats;

  final DateTime requestTime = DateTime.timestamp();

  String get atSignA => params.atSignA;

  String get atSignB => params.atSignB;

  AtEventConfig? eventLoggingConfig;

  /// SendPort to this session's port-pair worker isolate, used to forward
  /// later per-session messages (e.g. a definitive auth-modes notification).
  final SendPort? toWorker;

  SessionInfo({required this.params, required this.connector, this.toWorker});
}
