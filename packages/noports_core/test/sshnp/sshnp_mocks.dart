import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:socket_connector/socket_connector.dart';

/// A  [void Function()] stub
abstract class FunctionCaller<T> {
  T call();
}

class FunctionStub<T> extends Mock implements FunctionCaller<T> {}

abstract class SubscribeCaller {
  Stream<AtNotification> call({String? regex, bool shouldDecrypt});
}

class SubscribeStub extends Mock implements SubscribeCaller {}

/// The basic mocks that are repeated countless times throughout the test suite

class MockAtClient extends Mock implements AtClient {}

class MockNotificationService extends Mock implements NotificationService {}

class MockSshnpParams extends Mock implements SshnpParams {}

class MockSshnpdChannel extends Mock implements SshnpdChannel {}

class MockSshrvdChannel extends Mock implements SshrvdChannel {}

/// [dart:io] Mocks
class MockProcess extends Mock implements Process {}

class MockSocketConnector extends Mock implements SocketConnector {}

/// Stubbing for [Process.start]
abstract class StartProcessCaller {
  Future<Process> call(
    String executable,
    List<String> arguments, {
    bool runInShell,
    ProcessStartMode mode,
  });
}

class StartProcessStub extends Mock implements StartProcessCaller {}

