import 'dart:isolate';

import 'package:noports_core/events.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:socket_connector/socket_connector.dart';

class SessionInfo {
  final SrvdSessionParams params;
  final SocketConnector? connector;
  final Map<String, String> lookups = {};

  /// The `_apsk` records this session's accepted ESCR sockets were signed
  /// with.
  final Set<String> signingKeys = {};

  /// Set once the relay has asked for this session to be ended.
  bool ending = false;

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
