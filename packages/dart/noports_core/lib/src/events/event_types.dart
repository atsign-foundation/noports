enum NPEventType { session, lifecycle }

enum NPSessionEventType {
  requested, // by a client
  started, // by a daemon
  heartbeat,
  ended,
  policyRequestSent,
  policyRequestReceived,
  policyResponseSent,
  policyResponseReceived,
  daemonResponseReceived,
  sessionApproved,
  sessionDenied,
}

enum NPProgram { client, daemon, relay, policy, events }

enum NPLifecycleEventType { started, stopped }
