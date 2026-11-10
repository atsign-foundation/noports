import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:noports_core/src/srvd/srvd_util_mixin.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class FakeSrvd extends Fake with SrvdUtilMixin implements Srvd {
  @override
  AtSignLogger logger = AtSignLogger('FakeSrvd');
}

void main() {
  late Srvd srvd;

  setUp(() {
    srvd = FakeSrvd();
  });

  test('test notification subscription regex', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty();
    notification.key = 'test.${Srvd.namespace}';
  });

  test('accept session logging config notification', () {
    AtNotification n = AtNotification.empty()
      ..id = Uuid().v4()
      ..key =
          '@relay:logging.de0dbd91-3c42-4cb8-8630-23e51e78c8d3.sessions.sshrvd@service'
      ..to = '@relay'
      ..from = '@service'
      ..value = '';
    expect(srvd.wellFormedRequest(n, throwIfFalse: true), true);
  });

  test('srvd should accept notification in new request_ports format', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty()
      ..id = Uuid().v4()
      ..to = '@relay'
      ..from = '@alice'
      ..key = '@relay:request_ports.${Srvd.namespace}@alice'
      ..value = '';
    expect(srvd.wellFormedRequest(notification, throwIfFalse: true), true);
  });

  test('A session request whose authenticateSocketB is not a bool is refused',
      () {
    final Map<String, Object?> request = {
      'sessionId': Uuid().v4(),
      'atSignA': '@alice',
      'atSignB': '@bob',
      'clientNonce': 'client nonce',
      'authenticateSocketA': true,
      'authenticateSocketB': true,
    };
    SrvdSessionParams parse(Map<String, Object?> r) =>
        (srvd as FakeSrvd).srvdSessionParamsFromJson(jsonEncode(r));

    expect(parse(request).authenticateSocketB, isTrue,
        reason: 'the control: a well-formed request is read');
    for (final Object? value in [null, 'true']) {
      expect(
        () => parse({...request, 'authenticateSocketB': value}),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('authenticateSocketB'))),
        reason: 'authenticateSocketB $value is refused by name',
      );
    }
  });
}
