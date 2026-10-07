import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart' show isA, startsWith;

/// A  [void Function()] stub
abstract class FunctionCaller<T> {
  T call();
}

class FunctionStub<T> extends Mock implements FunctionCaller<T> {}

abstract class NotifyCaller {
  Future<NotificationResult> call(
    AtKey key,
    String value, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
    required Duration ttln,
    int maxTries,
  });
}

class NotifyStub extends Mock implements NotifyCaller {}

abstract class SubscribeCaller {
  Stream<AtNotification> call({String? regex, bool shouldDecrypt});
}

class SubscribeStub extends Mock implements SubscribeCaller {}

/// The basic mocks that are repeated countless times throughout the test suite

class MockAtClient extends Mock implements AtClient {}

/// Gives [atClient] a key source holding [encryptionKeyPair] as [atSign]'s
/// encryption keypair, which is what [signAndWrapAndJsonEncode] signs with,
/// and [apkamKeyPair], when given, as its enrollment's signing keypair.
void stubEncryptionKeys(
  MockAtClient atClient,
  RsaKeyPair encryptionKeyPair, {
  String atSign = '@alice',
  RsaKeyPair? apkamKeyPair,
}) {
  when(() => atClient.atKeysIo).thenReturn(
    InMemoryAtKeysIo.holding(
      atSign,
      AtKeys.legacy(
        encryptionPublicKey: encryptionKeyPair.atPublicKey.publicKey,
        encryptionPrivateKey: encryptionKeyPair.atPrivateKey.privateKey,
        apkamPublicKey: apkamKeyPair?.atPublicKey.publicKey,
        apkamPrivateKey: apkamKeyPair?.atPrivateKey.privateKey,
      ),
    ),
  );
}

/// What publishing the client's APKAM signing key touches on [atClient]:
/// its atSign, and the `put` that writes the `_apsk` record. A channel's
/// `initialize` publishes before anything a test is about, so a mock that
/// answers neither fails there with a null where a `Future<bool>` was
/// expected. Any other `put` throws naming its key; a test that cares what
/// is published re-stubs `put`.
void stubSigningKeyPublish(MockAtClient atClient, {String atSign = '@alice'}) {
  registerFallbackValue(AtKey());
  registerFallbackValue(PutRequestOptions());
  when(() => atClient.getCurrentAtSign()).thenReturn(atSign);
  when(
    () => atClient.put(
      any(),
      any(),
      putRequestOptions: any(named: 'putRequestOptions'),
    ),
  ).thenAnswer((invocation) async => throw StateError(
      'unstubbed put of ${invocation.positionalArguments.first}'));
  when(
    () => atClient.put(
      any(
          that: isA<AtKey>().having(
              (key) => key.toString(), 'key', startsWith('public:_apsk.'))),
      any(),
      putRequestOptions: any(named: 'putRequestOptions'),
    ),
  ).thenAnswer((_) async => true);
}

class MockNotificationService extends Mock implements NotificationService {}

class MockSshnpParams extends Mock implements SshnpParams {
  @override
  Duration get daemonPingTimeout => DefaultArgs.daemonPingTimeoutDuration;

  @override
  RelayAuthMode get relayAuthMode => RelayAuthMode.payload;

  @override
  bool get relayAuthModeExplicit => false;

  @override
  bool get only443 => false;
}

class MockSshnpdChannel extends Mock implements SshnpdChannel {
  @override
  bool get daemonSupportsRelayAuthEscr => false;
}

class MockSrvdChannel extends Mock implements SrvdChannel {
  @override
  Future<void> sendDefinitiveAuthModes({required bool daemonSupportsEscr}) async {}

  @override
  bool get autoDetectsRelayAuth => false;

  @override
  RelayAuthMode daemonRelayAuthMode({required bool daemonSupportsEscr}) =>
      RelayAuthMode.payload;
}

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
