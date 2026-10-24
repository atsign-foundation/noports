import 'package:at_commons/atsign.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:noports_core/src/npa/npa_rpcs.dart';

enum SessionState {
  requested, // daemon receives request from client
  approved, // daemon approves request
  denied, // daemon denies request
  daemonConnecting, // after daemon sends success response to client
  clientConnecting, // after client receives success response from daemon
  connected, // first connection of a socket pair by the relay for this session
  stillConnected, // may be sent by relay during long-running sessions
  done, // Sent by relay only if it had ever reached 'connected' state
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

  static Map<String, dynamic> daemonConnecting({required String sessionId}) => {
    "sessionId": sessionId,
    "state": SessionState.daemonConnecting.name,
    "lifecycle": {
      SessionState.daemonConnecting.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
    },
  };

  static Map<String, dynamic> clientConnecting({required String sessionId}) => {
    "sessionId": sessionId,
    "state": SessionState.clientConnecting.name,
    "lifecycle": {
      SessionState.clientConnecting.name: {
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

  static Map<String, dynamic> done({
    required String sessionId,
    required Stats stats,
  }) => {
    "sessionId": sessionId,
    "state": SessionState.done.name,
    "lifecycle": {
      SessionState.done.name: {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      },
      "stats": stats.toJson(),
    },
  };
}

enum PolicyEventType {
  clientAdmitted, // policy check authorised the client
  clientRejected, // policy check refused the client
  policyCheckFailed, // policy check threw; the client was refused
  requestRefused, // a daemon asked about another daemon; nothing was checked
  rulesLoaded, // the policy service loaded its rules and is answering checks
}

/// The events a policy service sends to its event logging Atsign: one for
/// each auth check it answers, and [rulesLoaded] once it has started. Every
/// event carries `event` (a [PolicyEventType] name), `timestamp` (UTC) and
/// `policyAtsign`. Each auth check event also carries `fromAtsign` (the
/// Atsign that sent the check) and the request's `clientAtsign`,
/// `daemonAtsign`, `daemonDeviceName` and `daemonDeviceGroupName`.
abstract class PolicyEvent {
  /// The policy check authorised the client, with the answer's `message` and
  /// `permitOpen`.
  static Map<String, dynamic> clientAdmitted({
    required Atsign policyAtsign,
    required Atsign fromAtsign,
    required NPAAuthCheckRequest request,
    required NPAAuthCheckResponse response,
  }) => {
    ..._policyCheckFields(
      PolicyEventType.clientAdmitted,
      policyAtsign,
      fromAtsign,
      request,
    ),
    "message": response.message,
    "permitOpen": response.permitOpen,
  };

  /// The policy check refused the client, with the answer's `message`.
  static Map<String, dynamic> clientRejected({
    required Atsign policyAtsign,
    required Atsign fromAtsign,
    required NPAAuthCheckRequest request,
    required NPAAuthCheckResponse response,
  }) => {
    ..._policyCheckFields(
      PolicyEventType.clientRejected,
      policyAtsign,
      fromAtsign,
      request,
    ),
    "message": response.message,
  };

  /// The policy check threw, so the client was refused; `error` says why.
  static Map<String, dynamic> policyCheckFailed({
    required Atsign policyAtsign,
    required Atsign fromAtsign,
    required NPAAuthCheckRequest request,
    required String error,
  }) => {
    ..._policyCheckFields(
      PolicyEventType.policyCheckFailed,
      policyAtsign,
      fromAtsign,
      request,
    ),
    "error": error,
  };

  /// A daemon asked about a different daemon, so the request was refused
  /// without a policy check and no client was evaluated. `fromAtsign` is the
  /// daemon that asked; `daemonAtsign` is the one it asked about.
  static Map<String, dynamic> requestRefused({
    required Atsign policyAtsign,
    required Atsign fromAtsign,
    required NPAAuthCheckRequest request,
    required NPAAuthCheckResponse response,
  }) => {
    ..._policyCheckFields(
      PolicyEventType.requestRefused,
      policyAtsign,
      fromAtsign,
      request,
    ),
    "message": response.message,
  };

  /// The policy service has loaded its rules and is answering checks.
  /// `persistenceMethod` is where the rules came from, and `rules` counts
  /// each kind of rule it holds; the rules themselves are not sent.
  static Map<String, dynamic> rulesLoaded({
    required Atsign policyAtsign,
    required String? persistenceMethod,
    required String binariesVersion,
    required Map<String, int> rules,
  }) => {
    "event": PolicyEventType.rulesLoaded.name,
    "timestamp": DateTime.now().toUtc().toIso8601String(),
    "policyAtsign": policyAtsign,
    "persistenceMethod": persistenceMethod,
    "binariesVersion": binariesVersion,
    "rules": rules,
  };

  /// The fields every policy check event carries.
  static Map<String, dynamic> _policyCheckFields(
    PolicyEventType event,
    Atsign policyAtsign,
    Atsign fromAtsign,
    NPAAuthCheckRequest request,
  ) => {
    "event": event.name,
    "timestamp": DateTime.now().toUtc().toIso8601String(),
    "policyAtsign": policyAtsign,
    "fromAtsign": fromAtsign,
    "clientAtsign": request.clientAtsign,
    "daemonAtsign": request.daemonAtsign,
    "daemonDeviceName": request.daemonDeviceName,
    "daemonDeviceGroupName": request.daemonDeviceGroupName,
  };
}
