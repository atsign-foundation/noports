import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  const aliceKey = 'public:_apsk.alice-enrollment.a.__e@alice';
  const bobKey = 'public:_apsk.bob-enrollment.a.__e@bob';

  late MockAtClient atClient;
  late SshnpdImpl daemon;

  setUp(() {
    registerFallbackValue(AtKey());
    registerFallbackValue(GetRequestOptions());
    atClient = MockAtClient();
    when(() => atClient.getCurrentAtSign()).thenReturn('@device');
    when(
      () => atClient.get(
        any(),
        getRequestOptions: any(named: 'getRequestOptions'),
      ),
    ).thenAnswer((_) async => throw AtKeyNotFoundException('key not found'));
    daemon = SshnpdImpl(
      atClient: atClient,
      username: 'testuser',
      homeDirectory: '/home/testuser',
      device: 'testdevice',
      managerAtsigns: ['@manager'],
      policyManagerAtsign: null,
      sshClient: SupportedSshClient.openssh,
      makeDeviceInfoVisible: false,
      addSshPublicKeys: false,
      localSshdPort: 22,
      sshPublicKeyPermissions: '',
      ephemeralPermissions: '',
      sshAlgorithm: SupportedSshAlgorithm.rsa,
      deviceGroup: 'default',
      version: '1.0.0',
      permitOpen: ['*:*'],
      strict: false,
      clientKeyCheckInterval: Duration.zero,
      requireEnrollmentSignature: false,
      publicLookup: ClientPublicLookup(atClient),
    );
  });

  /// Answers a lookup of [key] with [answer].
  void lookupOf(String key, Future<AtValue> Function() answer) => when(
        () => atClient.get(
          any(that: predicate<AtKey>((k) => k.toString() == key)),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer((_) => answer());

  Future<AtValue> published() async => AtValue()..value = 'a public key';

  /// Withdraws [key] as an atServer does, moving its record from `a.__e` to
  /// [to].
  void withdraw(String key, {String to = 'r.__e'}) =>
      lookupOf(key.replaceFirst('.a.__e@', '.$to@'), published);

  /// Tracks [sessionId] as signed with [key], returning how often it has been
  /// ended and a completer that ends it from outside.
  ({List<String> ends, Completer<void> ended}) track(
    String sessionId,
    String key,
  ) {
    final ends = <String>[];
    final ended = Completer<void>();
    daemon.trackClientSession(
      sessionId,
      key,
      ended: ended.future,
      end: () => ends.add(sessionId),
    );
    return (ends: ends, ended: ended);
  }

  int lookups() => verify(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).callCount;

  test('a daemon built from command-line arguments takes both options',
      () async {
    final home = Directory.systemTemp.createTempSync('client_key_check');
    addTearDown(() => home.deleteSync(recursive: true));
    final keys = File('${home.path}/device_key.atKeys')..writeAsStringSync('{}');

    final built = await SshnpdImpl.fromCommandLineArgs(
      [
        ...['-a', '@device', '-m', '@manager', '-k', keys.path],
        ...['--client-key-check-secs', '3', '--require-enrollment-signature'],
      ],
      atClient: atClient,
      version: '1.0.0',
    );

    expect(built.clientKeyCheckInterval, const Duration(seconds: 3));
    expect(built.requireEnrollmentSignature, isTrue);
  });

  test('ends a session whose client key was revoked', () async {
    final session = track('s', aliceKey);
    withdraw(aliceKey);

    await daemon.checkClientKeys();

    expect(session.ends, ['s']);
  });

  test('ends a session whose client key was deleted', () async {
    final session = track('s', aliceKey);
    withdraw(aliceKey, to: 'd.__e');

    await daemon.checkClientKeys();

    expect(session.ends, ['s']);
  });

  test('ends only the sessions the withdrawn key signed', () async {
    final alices = track('alice', aliceKey);
    final bobs = track('bob', bobKey);
    withdraw(aliceKey);
    lookupOf(bobKey, published);

    await daemon.checkClientKeys();

    expect(alices.ends, ['alice']);
    expect(bobs.ends, isEmpty);
  });

  test('keeps a session whose client key is missing but was not withdrawn',
      () async {
    final session = track('s', aliceKey);

    await daemon.checkClientKeys();

    expect(session.ends, isEmpty);
  });

  test('keeps a session when its client key lookup fails another way',
      () async {
    final session = track('s', aliceKey);
    lookupOf(
      aliceKey,
      () async => throw SecondaryConnectException(
        'Unable to connect to secondary @alice',
      ),
    );

    await daemon.checkClientKeys();

    expect(session.ends, isEmpty);
  });

  test('keeps a session when its client key is missing and the lookup of'
      ' where it went fails', () async {
    final session = track('s', aliceKey);
    lookupOf(
      aliceKey.replaceFirst('.a.__e@', '.r.__e@'),
      () async => throw SecondaryConnectException(
        'Unable to connect to secondary @alice',
      ),
    );

    await daemon.checkClientKeys();

    expect(session.ends, isEmpty);
  });

  test('looks each client key up once, however many sessions it signed',
      () async {
    track('one', aliceKey);
    track('two', aliceKey);
    lookupOf(aliceKey, published);

    await daemon.checkClientKeys();

    expect(lookups(), 1);
  });

  test('ends a session once, however many passes find its key withdrawn',
      () async {
    final session = track('s', aliceKey);
    withdraw(aliceKey);

    await daemon.checkClientKeys();
    expect(lookups(), greaterThan(0));
    await daemon.checkClientKeys();

    expect(session.ends, ['s']);
    verifyNever(
      () => atClient.get(
        any(),
        getRequestOptions: any(named: 'getRequestOptions'),
      ),
    );
  });

  test("a key whose atServer doesn't answer delays no other key's re-check,"
      ' nor the next pass', () async {
    const malloryKey = 'public:_apsk.mallory-enrollment.a.__e@mallory';
    track('mallory', malloryKey);
    final alices = track('alice', aliceKey);
    final unanswered = Completer<AtValue>();
    lookupOf(malloryKey, () => unanswered.future);
    withdraw(aliceKey);

    unawaited(daemon.checkClientKeys());
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(alices.ends, ['alice'],
        reason: "alice's session ends while mallory's lookup hangs");
    await daemon.checkClientKeys().timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('the next pass waited on mallory'),
        );
    unanswered.complete(await published());
  });

  test("doesn't re-check a key while its last re-check is running",
      () async {
    track('s', aliceKey);
    final lookedUp = Completer<AtValue>();
    lookupOf(aliceKey, () => lookedUp.future);

    final first = daemon.checkClientKeys();
    final overlapping = daemon.checkClientKeys();
    lookedUp.complete(await published());
    await Future.wait([first, overlapping]);

    expect(lookups(), 1);
  });

  test('stops tracking a session once it ends by itself', () async {
    final session = track('s', aliceKey);
    expect(daemon.trackedClientSessions, 1);

    session.ended.complete();
    await Future<void>.delayed(Duration.zero);

    expect(daemon.trackedClientSessions, 0);
    await daemon.checkClientKeys();
    verifyNever(
      () => atClient.get(
        any(),
        getRequestOptions: any(named: 'getRequestOptions'),
      ),
    );
  });

  test('a session that fails to end does not stop the others ending',
      () async {
    daemon.trackClientSession(
      'broken',
      aliceKey,
      ended: Completer<void>().future,
      end: () => throw StateError('cannot end'),
    );
    final other = track('other', aliceKey);
    withdraw(aliceKey);

    await daemon.checkClientKeys();

    expect(other.ends, ['other']);
  });

  test('ends at once a session started under an id already being watched',
      () async {
    final first = track('s', aliceKey);
    final second = track('s', bobKey);

    expect(second.ends, ['s']);
    expect(first.ends, isEmpty);
    withdraw(aliceKey);
    await daemon.checkClientKeys();
    expect(first.ends, ['s'], reason: 'the first session is still watched');
  });

  test('watches a session started under the id of one that has ended',
      () async {
    final first = track('s', aliceKey);
    first.ended.complete();
    await Future<void>.delayed(Duration.zero);
    final second = track('s', bobKey);
    withdraw(bobKey);

    expect(daemon.trackedClientSessions, 1);
    await daemon.checkClientKeys();

    expect(second.ends, ['s']);
  });
}
