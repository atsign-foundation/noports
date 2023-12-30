import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/sshrv.dart';

/// Stubbing for [SshrvGenerator] typedef
abstract class SshrvGeneratorCaller<T> {
  Sshrv<T> call(
    String host,
    int port, {
    required int localPort,
    required bool bindLocalPort,
    String? rvdAuthString,
  });
}

class SshrvGeneratorStub<T> extends Mock implements SshrvGeneratorCaller<T> {}

class MockSshrv<T> extends Mock implements Sshrv<T> {}

/// Stubbed [SshrvdChannel] which we are testing
class StubbedSshrvdChannel<T> extends SshrvdChannel<T> {
  final Future<void> Function(
    AtKey,
    String, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
  })? _notify;
  final Stream<AtNotification> Function({String? regex, bool shouldDecrypt})?
      _subscribe;

  StubbedSshrvdChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.sshrvGenerator,
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
