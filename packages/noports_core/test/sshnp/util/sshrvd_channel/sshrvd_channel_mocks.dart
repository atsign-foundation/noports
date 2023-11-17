import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/sshrv.dart';

/// Stubbing for [SshrvGenerator] typedef
abstract class SshrvGeneratorCaller<T> {
  Sshrv<T> call(String host, int port, {int localSshdPort});
}

class SshrvGeneratorStub<T> extends Mock implements SshrvGeneratorCaller<T> {}

class MockSshrv<T> extends Mock implements Sshrv<T> {}

/// Stubbed [SshrvdChannel] which we are testing
class StubbedSshrvdChannel<T> extends SshrvdChannel<T> {
  final Future<void> Function(AtKey, String)? _notify;
  StubbedSshrvdChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.sshrvGenerator,
    Future<void> Function(AtKey, String)? notify,
  }) : _notify = notify;

  @override
  Future<void> notify(
    AtKey atKey,
    String value,
  ) async {
    return _notify?.call(atKey, value);
  }
}
