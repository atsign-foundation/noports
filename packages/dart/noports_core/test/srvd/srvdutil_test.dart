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
        throwsA(isA<SrvdRequestRefused>().having(
            (e) => e.reason, 'reason', contains('authenticateSocketB'))),
        reason: 'authenticateSocketB $value is refused by name',
      );
    }
  });

  test(
      'A session request whose client-side or device-side Atsign is not a'
      ' valid Atsign is refused by name', () {
    final Map<String, Object?> request = {
      'sessionId': Uuid().v4(),
      'atSignA': '@alice',
      'atSignB': '@bob',
      'clientNonce': 'client nonce',
      'authenticateSocketA': false,
      'authenticateSocketB': false,
    };
    SrvdSessionParams parse(Map<String, Object?> r) =>
        (srvd as FakeSrvd).srvdSessionParamsFromJson(jsonEncode(r));

    expect(parse(request).atSignB, '@bob',
        reason: 'the control: a well-formed request is read');
    for (final (String value, String canonical) in [
      ('@Bob', '@bob'),
      ('bob', '@bob'),
      ('@${'d' * 55}', '@${'d' * 55}'),
    ]) {
      expect(parse({...request, 'atSignB': value}).atSignB, canonical,
          reason: '$value is a valid Atsign, read as $canonical');
    }
    for (final String side in ['atSignA', 'atSignB']) {
      for (final (String value, String why) in [
        ('@a@b', 'more than one @'),
        ('@${'d' * 56}', 'at most 55 characters'),
        ('@a b', 'whitespace'),
      ]) {
        expect(
          () => parse({...request, side: value}),
          throwsA(isA<SrvdRequestRefused>()
              .having((e) => e.reason, 'reason',
                  startsWith('Parameter $side is not a valid Atsign: '))
              .having((e) => e.reason, 'reason', contains(why))),
          reason: '$side $value is refused by name, saying why',
        );
      }
    }
  });

  test(
      'A refused session request names its session and whether its client'
      ' takes a NACK', () {
    SrvdRequestRefused refusal(Map<String, Object?> r) {
      try {
        (srvd as FakeSrvd).srvdSessionParamsFromJson(jsonEncode(r));
      } on SrvdRequestRefused catch (e) {
        return e;
      }
      fail('$r was not refused');
    }

    final String id = Uuid().v4();
    final Map<String, Object?> request = {
      'sessionId': id,
      'atSignA': '@alice',
      'atSignB': '@a@b',
      'clientNonce': 'client nonce',
      'authenticateSocketA': false,
      'authenticateSocketB': false,
    };

    expect(refusal(request).sessionId, id);
    expect(refusal(request).nackOk, isFalse);
    expect(refusal({...request, 'multipleAcksOk': true}).nackOk, isTrue);
    expect('${refusal(request)}', startsWith('session $id: '));
    final notUuid = refusal(
        {...request, 'sessionId': 'the-session', 'multipleAcksOk': true});
    expect(notUuid.nackOk, isFalse,
        reason: 'no NACK under a session id that is not a UUID');
    expect('$notUuid', isNot(contains('the-session')),
        reason: 'a session id that is not a UUID stays out of the log');
    expect(notUuid.reason, 'Parameter sessionId must be a UUID',
        reason: 'the session id is checked before any other field, so it is'
            ' the one named when another is wrong too');
    expect(
      refusal({
        ...request,
        'atSignB': '@bob',
        'sessionId': 'the-session',
        'multipleAcksOk': true,
      }).reason,
      'Parameter sessionId must be a UUID',
      reason: 'a request is refused for its session id alone, by name',
    );
    expect(
      () => (srvd as FakeSrvd).srvdSessionParamsFromJson(
          jsonEncode({...request}..remove('sessionId'))),
      throwsA(isA<ArgumentError>()),
      reason: 'a request with no session id names no session',
    );
  });

  test(
      'Given a session request whose session id is a UUID in upper case, when'
      ' it is read, then the session is held under the lower-case form and'
      ' keeps the id as sent', () {
    final String sent = Uuid().v4().toUpperCase();

    final SrvdSessionParams params =
        (srvd as FakeSrvd).srvdSessionParamsFromJson(jsonEncode({
      'sessionId': sent,
      'atSignA': '@alice',
      'atSignB': '@bob',
      'clientNonce': 'client nonce',
      'authenticateSocketA': true,
      'authenticateSocketB': true,
      'relayAuthMode': 'payload',
    }));

    expect(sent, isNot(sent.toLowerCase()), reason: 'the id has letters');
    expect(params.sessionId, sent.toLowerCase());
    expect(params.sessionIdAsSent, sent);
  });

  test(
      'A session request with a malformed field is refused naming the field,'
      ' never its value', () {
    final Map<String, Object?> request = {
      'sessionId': Uuid().v4(),
      'atSignA': '@alice',
      'atSignB': '@bob',
      'clientNonce': 'client nonce',
      'authenticateSocketA': false,
      'authenticateSocketB': false,
    };
    SrvdSessionParams parse(Map<String, Object?> r) =>
        (srvd as FakeSrvd).srvdSessionParamsFromJson(jsonEncode(r));

    expect(
        parse({
          ...request,
          'relayAuthMode': 'escr',
          'only443': true,
          'multipleAcksOk': true,
          'preFetch': ['x'],
          'sendJsonResponse': true,
          'relayAuthAesKey': 'key',
        }).preFetch,
        ['x'],
        reason: 'the control: every optional field well formed is read');
    for (final (String field, Object value) in [
      ('atSignA', 12345),
      ('clientNonce', 12345),
      ('relayAuthMode', 12345),
      ('relayAuthMode', 'bogus12345'),
      ('only443', 'yes12345'),
      ('multipleAcksOk', 'yes12345'),
      ('preFetch', 'abc12345'),
      ('preFetch', [12345]),
      ('sendJsonResponse', 'yes12345'),
      ('relayAuthAesKey', 12345),
    ]) {
      expect(
        () => parse({...request, field: value}),
        throwsA(isA<SrvdRequestRefused>()
            .having((e) => e.reason, 'reason', startsWith('Parameter $field '))
            .having((e) => e.reason, 'reason', isNot(contains('12345')))),
        reason: '$field $value is refused by name, without its value',
      );
    }
  });
}
