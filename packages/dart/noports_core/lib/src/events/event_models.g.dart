// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NPSessionEvent _$NPSessionEventFromJson(Map<String, dynamic> json) =>
    NPSessionEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String,
      sessionId: json['sessionId'] as String,
      sessionEventType: $enumDecode(
        _$NPSessionEventTypeEnumMap,
        json['sessionEventType'],
      ),
    );

Map<String, dynamic> _$NPSessionEventToJson(
  NPSessionEvent instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp.toIso8601String(),
  'message': instance.message,
  'sessionId': instance.sessionId,
  'sessionEventType': _$NPSessionEventTypeEnumMap[instance.sessionEventType]!,
};

const _$NPSessionEventTypeEnumMap = {
  NPSessionEventType.requested: 'requested',
  NPSessionEventType.started: 'started',
  NPSessionEventType.heartbeat: 'heartbeat',
  NPSessionEventType.ended: 'ended',
  NPSessionEventType.policyRequestSent: 'policyRequestSent',
  NPSessionEventType.policyRequestReceived: 'policyRequestReceived',
  NPSessionEventType.policyResponseSent: 'policyResponseSent',
  NPSessionEventType.policyResponseReceived: 'policyResponseReceived',
  NPSessionEventType.daemonResponseReceived: 'daemonResponseReceived',
  NPSessionEventType.sessionApproved: 'sessionApproved',
  NPSessionEventType.sessionDenied: 'sessionDenied',
};

NPLifecycleEvent _$NPLifecycleEventFromJson(Map<String, dynamic> json) =>
    NPLifecycleEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String,
      program: $enumDecode(_$NPProgramEnumMap, json['program']),
    );

Map<String, dynamic> _$NPLifecycleEventToJson(NPLifecycleEvent instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.toIso8601String(),
      'message': instance.message,
      'program': _$NPProgramEnumMap[instance.program]!,
    };

const _$NPProgramEnumMap = {
  NPProgram.client: 'client',
  NPProgram.daemon: 'daemon',
  NPProgram.relay: 'relay',
  NPProgram.policy: 'policy',
  NPProgram.events: 'events',
};
