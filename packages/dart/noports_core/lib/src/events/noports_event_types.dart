import 'package:at_commons/atsign.dart';
import 'package:socket_connector/socket_connector.dart';

enum SessionState {
  requested, // daemon receives request from client
  approved, // daemon approves request
  denied, // daemon denies request
  daemonStarted, // daemon sends success response to client
  clientStarted, // client receives approval from daemon
  connected, // first connection of a socket pair by the relay for this session
  stillConnected, // may be sent by relay during long-running sessions
  ended, // Sent by relay only if it had ever reached 'connected' state
}

abstract class SessionEvent {
  static Map<String, dynamic> requested({
    required String sessionId,
    required Atsign clientAtsign,
    required Atsign daemonAtsign,
    required String device,
    required Atsign? policyAtsign,
    required Atsign? relayAtsign,
    required String host,
    required int port,
  }) => {
    "sessionId": sessionId,
    "timestamp": DateTime.now().toUtc().toIso8601String(),
    "clientAtsign": clientAtsign,
    "daemonAtsign": daemonAtsign,
    "device": device,
    "policyAtsign": policyAtsign,
    "relayAtsign": relayAtsign,
    "host": host,
    "port": port,
    "state": SessionState.requested.name,
    "lifecycle": {
      SessionState.requested.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> approved({
    required String sessionId,
    required String message,
    required Map<String, dynamic> authInfo,
  }) => {
    "sessionId": sessionId,
    "state": SessionState.approved.name,
    "lifecycle": {
      SessionState.approved.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "authInfo": authInfo,
      },
    },
  };

  static Map<String, dynamic> denied({
    required String sessionId,
    required Map<String, dynamic> authInfo,
  }) => {
    "sessionId": sessionId,
    "state": SessionState.denied.name,
    "lifecycle": {
      SessionState.denied.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "authInfo": authInfo,
      },
    },
  };

  static Map<String, dynamic> daemonStarted({required String sessionId}) => {
    "sessionId": sessionId,
    "state": SessionState.daemonStarted.name,
    "lifecycle": {
      SessionState.daemonStarted.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> clientStarted({required String sessionId}) => {
    "sessionId": sessionId,
    "state": SessionState.clientStarted.name,
    "lifecycle": {
      SessionState.clientStarted.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> connected({
    required String sessionId,
    required Stats stats,
  }) => {
    "sessionId": sessionId,
    "state": SessionState.connected.name,
    "lifecycle": {
      SessionState.connected.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
      "stats": stats.toJson(),
    },
  };

  static Map<String, dynamic> stillConnected({
    required String sessionId,
    required Stats stats,
  }) => {
    "sessionId": sessionId,
    "state": SessionState.stillConnected.name,
    "lifecycle": {
      SessionState.stillConnected.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
      "stats": stats.toJson(),
    },
  };

  static Map<String, dynamic> ended({
    required String sessionId,
    required Stats stats,
  }) => {
    "sessionId": sessionId,
    "state": SessionState.ended.name,
    "lifecycle": {
      SessionState.ended.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
      "stats": stats.toJson(),
    },
  };
}
