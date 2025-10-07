import 'package:at_commons/atsign.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event_models.g.dart';

@JsonSerializable()
class AtEventLoggingConfig {
  /// The atSign to which we will send the event log notifications
  final Atsign atSign;

  /// The topic for the notifications - e.g. `abcdefg.events.logging.sshnp`
  final String topic;

  String get topicListenRegex => '\\.${topic.split('.').join('\\.')}';

  /// Since events are logged using ephemeral notifications, they will
  /// generally have a short lifetime, as the expectation is that the receiver
  /// will be up and running most of the time. However we don't want to
  /// hard-code a duration.
  final Duration ttln;

  AtEventLoggingConfig({
    required this.atSign,
    required this.topic,
    this.ttln = const Duration(hours: 1),
  });

  Map<String, dynamic> toJson() => _$AtEventLoggingConfigToJson(this);

  static AtEventLoggingConfig fromJson(Map<String, dynamic> json) =>
      _$AtEventLoggingConfigFromJson(json);

  @override
  String toString() => toJson().toString();
}

abstract class AtEvent {
  static Map<String, Function> fromJsonFunctions = {};
  final DateTime timestamp;
  final String traceId;
  final String eventType;
  final Map<String, dynamic>? payload;

  AtEvent({
    required this.timestamp,
    required this.traceId,
    required this.eventType,
    required this.payload,
  });

  Map<String, dynamic> toJson();

  static AtEvent fromJson(Map<String, dynamic> json) {
    var eventType = json['eventType'];
    if (eventType == null) {
      throw ArgumentError('Missing eventType in json: $json');
    }

    if (fromJsonFunctions.containsKey(eventType)) {
      return fromJsonFunctions[eventType]!(json);
    }

    throw StateError(
      'No fromJson function registered for eventType $eventType',
    );
  }
}

@JsonEnum()
enum NPEventType { session, lifecycle }

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
class NPSessionEvent extends AtEvent {
  final String sessionId;
  final NPSessionEventType sessionEventType;

  NPSessionEvent({
    required super.timestamp,
    required super.payload,
    required this.sessionId,
    required this.sessionEventType,
  }) : super(eventType: NPEventType.session.name, traceId: sessionId);

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
class NPLifecycleEvent extends AtEvent {
  final NPProgram program;

  NPLifecycleEvent({
    required super.timestamp,
    required super.traceId,
    required super.payload,
    required this.program,
  }) : super(eventType: NPEventType.lifecycle.name);

  @override
  Map<String, dynamic> toJson() => _$NPLifecycleEventToJson(this);

  static NPLifecycleEvent fromJson(Map<String, dynamic> json) =>
      _$NPLifecycleEventFromJson(json);
}
