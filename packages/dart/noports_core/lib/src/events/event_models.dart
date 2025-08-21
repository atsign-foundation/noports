import 'package:json_annotation/json_annotation.dart';

part 'event_models.g.dart';

@JsonEnum()
enum NPEventType { session, lifecycle }

abstract class NPEvent {
  final DateTime timestamp;
  final NPEventType eventType;
  final String message;

  NPEvent({
    required this.timestamp,
    required this.eventType,
    required this.message,
  });

  Map<String, dynamic> toJson();

  static NPEvent fromJson(Map<String, dynamic> json) {
    dynamic etStr = json['eventType'];
    if (etStr == null) {
      throw ArgumentError('Missing eventType in json: $json');
    }
    NPEventType et;
    try {
      et = NPEventType.values.byName(etStr);
    } catch (_) {
      throw ArgumentError('Invalid eventType $etStr in json: $json');
    }
    switch (et) {
      case NPEventType.session:
        return NPSessionEvent.fromJson(json);
      case NPEventType.lifecycle:
        return NPLifecycleEvent.fromJson(json);
    }
  }
}

@JsonEnum()
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

@JsonSerializable()
class NPSessionEvent extends NPEvent {
  final String sessionId;
  final NPSessionEventType sessionEventType;

  NPSessionEvent({
    required super.timestamp,
    required super.message,
    required this.sessionId,
    required this.sessionEventType,
  }) : super(eventType: NPEventType.session);

  @override
  Map<String, dynamic> toJson() => _$NPSessionEventToJson(this);

  static NPSessionEvent fromJson(Map<String, dynamic> json) =>
      _$NPSessionEventFromJson(json);
}

@JsonEnum()
enum NPProgram { client, daemon, relay, policy, events }

@JsonEnum()
enum NPLifecycleEventType { started, stopped }

@JsonSerializable()
class NPLifecycleEvent extends NPEvent {
  final NPProgram program;

  NPLifecycleEvent({
    required super.timestamp,
    required super.message,
    required this.program,
  }) : super(eventType: NPEventType.lifecycle);

  @override
  Map<String, dynamic> toJson() => _$NPLifecycleEventToJson(this);

  static NPLifecycleEvent fromJson(Map<String, dynamic> json) =>
      _$NPLifecycleEventFromJson(json);
}
