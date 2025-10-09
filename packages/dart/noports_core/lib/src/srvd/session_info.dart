import 'package:noports_core/events.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:socket_connector/socket_connector.dart';

class SessionInfo {
  final SrvdSessionParams params;
  final SocketConnector? connector;
  final Map<String, String> lookups = {};

  final DateTime requestTime = DateTime.timestamp();

  String get atSignA => params.atSignA!;

  String get atSignB => params.atSignB!;

  AtEventLoggingConfig? eventLoggingConfig;

  SessionInfo({required this.params, required this.connector});
}
