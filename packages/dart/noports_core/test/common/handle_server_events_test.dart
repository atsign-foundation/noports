import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart'
    show AtData, AtKeyValueStore, AtMetaData;
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/handle_server_events.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

class _MockLocalSecondary extends Mock implements LocalSecondary {}

class _MockKeyStore extends Mock
    implements AtKeyValueStore<String, AtData, AtMetaData?> {}

void main() {
  group("Given @alice listening for its atServer's public-key-changed events",
      () {
    late StreamController<AtNotification> events;
    late _MockKeyStore keyStore;
    late StreamSubscription<AtNotification> listener;

    setUp(() {
      events = StreamController<AtNotification>.broadcast();
      keyStore = _MockKeyStore();
      when(
        () => keyStore.remove(any(), skipCommit: any(named: 'skipCommit')),
      ).thenAnswer((_) async => null);
      final localSecondary = _MockLocalSecondary();
      when(() => localSecondary.keyStore).thenReturn(keyStore);
      final notificationService = MockNotificationService();
      // Delivers what the subscription's regex matches, as at_client does.
      when(
        () => notificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((invocation) {
        final regex = RegExp(invocation.namedArguments[#regex] as String);
        return events.stream.where((n) => regex.hasMatch(n.key));
      });
      final atClient = MockAtClient();
      when(() => atClient.notificationService).thenReturn(notificationService);
      when(() => atClient.getLocalSecondary()).thenReturn(localSecondary);
      listener = handlePublicKeyChangedEvent(atClient, '@alice'.toAtsign());
    });

    tearDown(() async {
      await listener.cancel();
      await events.close();
    });

    AtNotification keyChanged(String atSign, {required String from}) =>
        AtNotification(
          'event-id',
          '@alice:1234.events.__atserver$from',
          from,
          '@alice',
          1,
          'key',
          false,
          value: jsonEncode(AtSignPKChangedEvent(atSign).toJson()),
        );

    test(
        "when @alice's atServer reports that @bob's public key changed, then"
        " @alice's cached keys for @bob are removed", () async {
      events.add(keyChanged('@bob', from: '@alice'));
      await pumpEventQueue();

      expect(
        verify(() => keyStore.remove(captureAny(), skipCommit: true)).captured,
        [
          'shared_key.bob@alice',
          '@bob:shared_key@alice',
          'cached:public:publickey@bob',
        ],
      );
    });

    test(
        "when @alice2 sends an event saying @bob's public key changed, then"
        " @alice's cached keys for @bob are kept", () async {
      events.add(keyChanged('@bob', from: '@alice2'));
      await pumpEventQueue();

      verifyNever(
        () => keyStore.remove(any(), skipCommit: any(named: 'skipCommit')),
      );
    });
  });
}
