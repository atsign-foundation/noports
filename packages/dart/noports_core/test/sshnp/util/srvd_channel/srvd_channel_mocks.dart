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
    String? rvdAuthString,
    String? sessionAESKeyString,
    String? sessionIVString,
    bool multi = false,
    bool detached = false,
  });
}

class SrvGeneratorStub<T> extends Mock implements SrvGeneratorCaller<T> {}

class MockSrv<T> extends Mock implements Srv<T> {}

/// Stubbed [SrvdChannel] which we are testing
class StubbedSrvdChannel<T> extends SrvdChannel<T> {
  final Future<void> Function(
    AtKey,
    String, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
  })? _notify;
  final Stream<AtNotification> Function({String? regex, bool shouldDecrypt})?
      _subscribe;

  StubbedSrvdChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.srvGenerator,
    Future<void> Function(
      AtKey,
      String, {
      required bool checkForFinalDeliveryStatus,
      required bool waitForFinalDeliveryStatus,
    })? notify,
    Stream<AtNotification> Function({String? regex, bool shouldDecrypt})?
        subscribe,
  })  : _notify = notify,
        _subscribe = subscribe;

  @override
  Future<void> notify(
    AtKey atKey,
    String value, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
  }) async {
    return _notify?.call(
      atKey,
      value,
      checkForFinalDeliveryStatus: checkForFinalDeliveryStatus,
      waitForFinalDeliveryStatus: waitForFinalDeliveryStatus,
    );
  }

  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) {
    return _subscribe?.call(regex: regex, shouldDecrypt: shouldDecrypt) ??
        Stream.empty();
  }
}
