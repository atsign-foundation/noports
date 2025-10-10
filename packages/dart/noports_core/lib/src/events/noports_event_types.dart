import 'package:at_commons/atsign.dart';
import 'package:socket_connector/socket_connector.dart';

enum SessionLifecycle {
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
    required Atsign atsignA,
    required Atsign atsignB,
    required Atsign? policyAtsign,
    required Atsign? relayAtsign,
    required String host,
    required int port,
  }) => {
    "sessionId": sessionId,
    "timestamp": DateTime.now().toUtc().toIso8601String(),
    "atsignA": atsignA,
    "atsignB": atsignB,
    "policyAtsign": policyAtsign,
    "relayAtsign": relayAtsign,
    "host": host,
    "port": port,
    "state": SessionLifecycle.requested.name,
    "lifecycle": {
      SessionLifecycle.requested.name: {
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
    "state": SessionLifecycle.approved.name,
    "lifecycle": {
      SessionLifecycle.approved.name: {
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
    "state": SessionLifecycle.denied.name,
    "lifecycle": {
      SessionLifecycle.denied.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "authInfo": authInfo,
      },
    },
  };

  static Map<String, dynamic> daemonStarted({required String sessionId}) => {
    "sessionId": sessionId,
    "state": SessionLifecycle.daemonStarted.name,
    "lifecycle": {
      SessionLifecycle.daemonStarted.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> clientStarted({required String sessionId}) => {
    "sessionId": sessionId,
    "state": SessionLifecycle.clientStarted.name,
    "lifecycle": {
      SessionLifecycle.clientStarted.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> connected({
    required String sessionId,
  }) => {
    "sessionId": sessionId,
    "state": SessionLifecycle.connected.name,
    "lifecycle": {
      SessionLifecycle.connected.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> stillConnected({
    required String sessionId,
    required Stats stats,
  }) => {
    "sessionId": sessionId,
    "stats": stats.toJson(),
    "state": SessionLifecycle.stillConnected.name,
    "lifecycle": {
      SessionLifecycle.stillConnected.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> ended({
    required String sessionId,
    required Stats stats,
  }) => {
    "sessionId": sessionId,
    "stats": stats.toJson(),
    "state": SessionLifecycle.ended.name,
    "lifecycle": {
      SessionLifecycle.ended.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };
}
