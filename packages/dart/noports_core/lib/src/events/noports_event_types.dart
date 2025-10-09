import 'package:at_commons/atsign.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:socket_connector/socket_connector.dart';

enum NPSessionEventType {
  requested, // daemon receives request from client
  policyReqSent,
  policyReqRcvd,
  policyRespSent,
  policyRespRcvd,
  daemonRespRcvd, // DONE
  approved, // DONE
  denied, // DONE
  started, // daemon sends success response to client
  connected, // first 'Side' in the SocketConnector
  progress,
  ended,
}

/// ```
/// {
///   "atsign.noports.session":{
///     "sessionId":"foo",
///     "atsignA":"@alice", // client
///     "atsignB":"@bob", // daemon
///     "policyAtsign":"@policy",
///     "relayAtsign":"@relay",
///     "stats":{...} // SocketConnector.stats
///     "lifecycle":{
///       "requested":{"timestamp":<ts>, ...},
///       "policyReqSent":{"timestamp":<ts>, ...},
///       "policyReqRcvd":{"timestamp":<ts>, ...},
///       "policyRespSent":{"timestamp":<ts>, ...},
///       "policyRespRcvd":{"timestamp":<ts>, ...},
///       "approved":{"timestamp":<ts>, "message":"", ...},
///       "denied":{"timestamp":<ts>, "message":"", ...},
///       "started":{"timestamp":<ts>, ...},
///       "daemonResponseReceived":{"timestamp":<ts>, ...},
///       "connected":{"timestamp":<ts>, ...}, // first 'Side' in the SocketConnector
///       "progress":{"timestamp":<ts>, "stats":{...}}, // sent periodically for long-running sessions
///       "ended":{"timestamp":<ts>, ...},
///     }
///   }
/// }
/// ```
abstract class NPSessionEvent {
  static Map<String, dynamic> requested({
    required String sessionId,
    required Atsign atsignA,
    required Atsign atsignB,
    required Atsign? policyAtsign,
    required Atsign? relayAtsign,
  }) => {
    "sessionId": sessionId,
    "timestamp": DateTime.now().toUtc().toIso8601String(),
    "atsignA": atsignA,
    "atsignB": atsignB,
    "policyAtsign": policyAtsign,
    "relayAtsign": relayAtsign,
    "lifecycle": {
      "requested": {"timestamp": DateTime.now().toUtc().toIso8601String()},
    },
  };

  static Map<String, dynamic> policyReqSent() => throw UnimplementedError();

  static Map<String, dynamic> policyReqRcvd() => throw UnimplementedError();

  static Map<String, dynamic> policyRespSent() => throw UnimplementedError();

  static Map<String, dynamic> policyRespRcvd({
    required String sessionId,
    required Atsign policyAtsign,
  }) => {
    "sessionId": sessionId,
    "lifecycle": {
      "policyRespRcvd": {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "policyAtsign": policyAtsign,
      },
    },
  };

  static Map<String, dynamic> approved({
    required String sessionId,
    required String message,
  }) => {
    "sessionId": sessionId,
    "lifecycle": {
      "approved": {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "message": message,
      },
    },
  };

  static Map<String, dynamic> denied({
    required String sessionId,
    required String message,
  }) => {
    "sessionId": sessionId,
    "lifecycle": {
      "denied": {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "message": message,
      },
    },
  };

  static Map<String, dynamic> daemonRespRcvd({
    required String sessionId,
    required SshnpdAck ack,
  }) => {
    "sessionId": sessionId,
    "lifecycle": {
      "daemonRespRcvd": {"timestamp": DateTime.now().toUtc().toIso8601String()},
      "ack":ack.name,
    },
  };

  static Map<String, dynamic> started({required String sessionId}) => {
    "sessionId": sessionId,
    "lifecycle": {
      "started": {"timestamp": DateTime.now().toUtc().toIso8601String()},
    },
  };

  static Map<String, dynamic> progress() => throw UnimplementedError();

  static Map<String, dynamic> ended({
    required String sessionId,
    required Stats stats,
  }) => {
    "sessionId": sessionId,
    "stats": stats.toJson(),
    "lifecycle": {
      "ended": {"timestamp": DateTime.now().toUtc().toIso8601String()},
    },
  };
}
