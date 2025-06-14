import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';

abstract class HandleSshnpdPayloadCaller {
  Future<SshnpdAck> call(AtNotification notification);
}

class HandleSshnpdPayloadStub extends Mock
    implements HandleSshnpdPayloadCaller {}

class StubbedSshnpdChannel extends SshnpdChannel {
  final Future<NotificationResult> Function(
    AtKey,
    String, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
    required Duration ttln,
    int maxTries,
  }) _notify;
  final Stream<AtNotification> Function({String? regex, bool shouldDecrypt})
      _subscribe;
  final Future<SshnpdAck> Function(AtNotification notification)?
      _handleSshnpdPayload;

  StubbedSshnpdChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.namespace,
    required Future<NotificationResult> Function(
      AtKey,
      String, {
      required bool checkForFinalDeliveryStatus,
      required bool waitForFinalDeliveryStatus,
      required Duration ttln,
      int maxTries,
    }) notify,
    required Stream<AtNotification> Function({
      String? regex,
      bool shouldDecrypt,
    }) subscribe,
    Future<SshnpdAck> Function(AtNotification notification)?
        handleSshnpdPayload,
  })  : _notify = notify,
        _subscribe = subscribe,
        _handleSshnpdPayload = handleSshnpdPayload;

  @override
  Future<SshnpdAck> handleSshnpdPayload(AtNotification notification) async {
    return await _handleSshnpdPayload?.call(notification) ??
        SshnpdAck.notAcknowledged;
  }

  @override
  Future<NotificationResult> notify(
    AtKey atKey,
    String value, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
    required Duration ttln,
    int maxTries = 3,
  }) async {
    return _notify.call(
      atKey,
      value,
      checkForFinalDeliveryStatus: checkForFinalDeliveryStatus,
      waitForFinalDeliveryStatus: waitForFinalDeliveryStatus,
      ttln: ttln,
      maxTries: maxTries,
    );
  }

  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) {
    return _subscribe.call(regex: regex, shouldDecrypt: shouldDecrypt);
  }
}

class MockRemoteSecondary extends Mock implements RemoteSecondary {}

class StubbedSshnpdDefaultChannel extends SshnpdDefaultChannel {
  final Stream<AtNotification> Function({String? regex, bool shouldDecrypt})?
      _subscribe;

  StubbedSshnpdDefaultChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.namespace,
    Stream<AtNotification> Function({String? regex, bool shouldDecrypt})?
        subscribe,
  }) : _subscribe = subscribe;

  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) {
    return _subscribe?.call(regex: regex, shouldDecrypt: shouldDecrypt) ??
        Stream.empty();
  }
}
