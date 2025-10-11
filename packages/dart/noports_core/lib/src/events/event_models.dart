import 'package:at_commons/atsign.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event_models.g.dart';

@JsonSerializable()
class AtEventConfig {
  /// The atSign to which we will send the event log notifications
  final Atsign atSign;

  /// The topic for the notifications - e.g. `abcdefg.events.logging.sshnp`
  final String topic;

  String get topicListenRegex => topic.split('.').join('\\.');

  /// Since events are logged using ephemeral notifications, they will
  /// generally have a short lifetime, as the expectation is that the receiver
  /// will be up and running most of the time. However we don't want to
  /// hard-code a duration. Value is in milliseconds.
  final int ttln;

  AtEventConfig({
    required this.atSign,
    required this.topic,
    required this.ttln,
  });

  Map<String, dynamic> toJson() => _$AtEventConfigToJson(this);

  static AtEventConfig fromJson(Map<String, dynamic> json) =>
      _$AtEventConfigFromJson(json);

  @override
  String toString() => toJson().toString();
}
