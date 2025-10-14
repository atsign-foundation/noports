import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/srv.dart';

/// Stubbing for [SrvGenerator] typedef
abstract class SrvGeneratorCaller<T> {
  Srv<T> call(
    String streamingHost,
    int streamingPort, {
    int? localPort,
    bool? bindLocalPort,
    String? localHost,
    RelayAuthenticator? relayAuthenticator,
    String? aesC2D,
    String? ivC2D,
    String? aesD2C,
    String? ivD2C,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
    Duration? controlChannelHeartbeat,
  });
}

class SrvGeneratorStub<T> extends Mock implements SrvGeneratorCaller<T> {}

class MockSrv<T> extends Mock implements Srv<T> {}

/// Stubbed [SrvdChannel] which we are testing
class StubbedSrvdChannel<T> extends SrvdChannel<T> {
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

  StubbedSrvdChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.srvGenerator,
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
  })  : _notify = notify,
        _subscribe = subscribe;

  @override
  Future<NotificationResult> notify(
    AtKey atKey,
    String value, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
    required Duration ttln,

    /// maxTries must be a non-zero positive integer
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
