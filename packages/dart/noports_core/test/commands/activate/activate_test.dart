import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/commands/activate/activate.dart';
import 'package:noports_core/src/commands/activate/activate_params.dart';
import 'package:test/test.dart';

class MockActivateFlows extends Mock implements ActivateFlows {}

class MockAtOnboardingPreference extends Mock
    implements AtOnboardingPreference {}

class MockAtClient extends Mock implements AtClient {}

class MockPendingEnrollment extends Mock implements PendingEnrollment {}

class _CapturedStdout implements Stdout {
  final written = <Object?>[];

  @override
  void write(Object? object) => written.add(object);

  @override
  void writeln([Object? object = '']) => written.add('$object\n');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SilentStdin implements Stdin {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Runs [body] with stderr captured and every prompt answered with nothing,
/// returning what [body] wrote to stderr. The [Activate] under test must be
/// built inside [body], since its logger writes where it was created.
Future<String> captureStderr(Future<void> Function() body) async {
  final err = _CapturedStdout();
  await IOOverrides.runZoned(body,
      stderr: () => err, stdin: () => _SilentStdin());
  return err.written.join();
}

void main() {
  late MockActivateFlows flows;
  late MockAtClient client;
  late ActivateParams params;
  late Activate activate;

  final testAtsign = '@test'.toAtsign();
  const testCramSecret = 'test_cram_secret';
  const testDeviceName = 'test_device';
  const testOtp = '123456';

  setUpAll(() {
    registerFallbackValue(InMemoryAtKeysIo());
    registerFallbackValue(AtClientPreference());
  });

  setUp(() {
    flows = MockActivateFlows();
    client = MockAtClient();
    when(() => client.stop()).thenAnswer((_) async {});

    AtSignLogger.root_level = 'WARNING';
  });

  group('Activate.fromArgs factory', () {
    test('assert empty args throws', () {
      expect(() => Activate.fromArgs([]), throwsA(isA<ArgumentError>()));
    });

    test('factory generates instance with valid cram args', () {
      List<String> testArgs = ['@alice:cram:secret'];
      expect(() => Activate.fromArgs(testArgs), returnsNormally);
    });

    test('factory generates instance with valid cram args', () {
      List<String> testArgs = ['@alice:cram:secret', '-t', 'path/to/keys'];
      expect(() => Activate.fromArgs(testArgs), returnsNormally);
    });

    test('factory generates instance with valid enroll args', () {
      List<String> testArgs = ['@alice:enroll:otp:123456:name:device'];
      expect(() => Activate.fromArgs(testArgs), returnsNormally);
    });

    test('factory generates instance with valid enroll args', () {
      List<String> testArgs = [
        '@alice:enroll:otp:123456:name:device',
        '-t',
        '/path/to/keys',
      ];
      expect(() => Activate.fromArgs(testArgs), returnsNormally);
    });

    test('factory throws with invalid activation string', () {
      List<String> testArgs = ['invalid_string'];
      expect(() => Activate.fromArgs(testArgs), throwsA(isA<ArgumentError>()));
    });
  });

  group('activate type: cram', () {
    test('throws ArgumentError when cramSecret is null', () {
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.cram,
        rootDomain: 'root.test.com',
      );
      activate = Activate(flows, params);

      expect(() => activate.cramAuthenticate(), throwsA(isA<ArgumentError>()));
    });

    test('case: onboarding succeeds', () async {
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.cram,
        cramSecret: testCramSecret,
        rootDomain: 'root.test.com',
      );
      activate = Activate(flows, params);

      when(() => flows.activate(any(),
          cramSecret: any(named: 'cramSecret'),
          keys: any(named: 'keys'),
          preference: any(named: 'preference'),
          storage: any(named: 'storage'))).thenAnswer((_) async => client);

      final result = await activate.cramAuthenticate();

      expect(result, equals(0));
    });

    test('case: onboarding failure', () async {
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.cram,
        cramSecret: testCramSecret,
        rootDomain: 'root.test.com',
      );
      activate = Activate(flows, params);

      when(() => flows.activate(any(),
              cramSecret: any(named: 'cramSecret'),
              keys: any(named: 'keys'),
              preference: any(named: 'preference'),
              storage: any(named: 'storage')))
          .thenThrow(Exception('cram authentication failed'));

      final result = await activate.cramAuthenticate();

      expect(result, equals(1));
    });
  });

  group('activate type: enroll', () {
    test('throws ArgumentError when otp is null', () {
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.enroll,
        deviceName: testDeviceName,
        rootDomain: 'root.test.com',
      );
      activate = Activate(flows, params);

      expect(() => activate.enroll(), throwsA(isA<ArgumentError>()));
    });

    ActivateParams enrollParams({String atKeysFilePath = 'dummy_keys_file'}) =>
        ActivateParams(
          atsign: testAtsign,
          type: ActivateType.enroll,
          otp: testOtp,
          deviceName: testDeviceName,
          atKeysFilePath: atKeysFilePath,
          rootDomain: 'root.test.com',
        );

    void stubResume(PendingEnrollment? found) =>
        when(() => flows.resumeEnrollment(any(),
                app: any(named: 'app'),
                device: any(named: 'device'),
                keys: any(named: 'keys'),
                preference: any(named: 'preference')))
            .thenAnswer((_) async => found);

    When<Future<PendingEnrollment>> whenSubmitted() =>
        when(() => flows.enroll(any(),
            otp: testOtp,
            app: any(named: 'app'),
            device: testDeviceName,
            namespaces: any(named: 'namespaces'),
            keys: any(named: 'keys'),
            preference: any(named: 'preference')));

    When<Future<AtClient>> whenDecided(MockPendingEnrollment pending) =>
        when(() => pending.client(any(), storage: any(named: 'storage')));

    late MockPendingEnrollment pending;

    setUp(() {
      pending = MockPendingEnrollment();
      when(() => pending.enrollmentId).thenReturn('e1');
    });

    test('a fresh enrollment is submitted and waited on', () async {
      stubResume(null);
      whenSubmitted().thenAnswer((_) async => pending);
      whenDecided(pending).thenAnswer((_) async => client);

      final result = await Activate(flows, enrollParams()).enroll();

      expect(result, equals(0));
      verify(() => client.stop()).called(1);
    });

    test(
        'an enrollment an earlier run left in the keyfile is resumed, '
        'not resubmitted', () async {
      final dir = Directory.systemTemp.createTempSync('activate_resume');
      addTearDown(() => dir.deleteSync(recursive: true));
      final keyfile = File('${dir.path}/test_key.atKeys')
        ..writeAsStringSync('{}');
      stubResume(pending);
      whenSubmitted().thenAnswer(
          (_) async => fail('the pending enrollment was submitted again'));
      whenDecided(pending).thenAnswer((_) async => client);

      late int result;
      final err = await captureStderr(() async {
        result =
            await Activate(flows, enrollParams(atKeysFilePath: keyfile.path))
                .enroll();
      });

      expect(result, equals(0));
      expect(err, contains('Resuming enrollment e1'));
      expect(err, isNot(contains('alternate location')),
          reason: 'the keyfile holding the request is the one to resume, '
              'not a collision to prompt about');
    });

    test('a keyfile that refuses a new enrollment is reported as not submitted',
        () async {
      stubResume(null);
      whenSubmitted().thenThrow(
          AtEnrollmentException('@test already holds live keys in this store'));

      late int result;
      final err = await captureStderr(() async {
        result = await Activate(flows, enrollParams()).enroll();
      });

      expect(result, equals(1));
      expect(err,
          contains('Enrollment not submitted: @test already holds live keys'));
      expect(err, isNot(contains('not approved')),
          reason: 'nothing reached an approver');
      verifyNever(() => pending.client(any(), storage: any(named: 'storage')));
    });

    test('a denial is reported as not approved', () async {
      stubResume(null);
      whenSubmitted().thenAnswer((_) async => pending);
      whenDecided(pending)
          .thenThrow(AtEnrollmentException('The enrollment: e1 is denied'));

      late int result;
      final err = await captureStderr(() async {
        result = await Activate(flows, enrollParams()).enroll();
      });

      expect(result, equals(1));
      expect(err,
          contains('Enrollment not approved: The enrollment: e1 is denied'));
    });
  });

  group('validate getKeysFile', () {
    test('keyfile path is null', () {
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.cram,
        cramSecret: testCramSecret,
        atKeysFilePath: null,
        rootDomain: 'root.test.com',
      );

      activate = Activate(flows, params);
      expect(activate.getKeysFile(), isNull);
    });

    test('keyfile path is not null', () {
      String testKeysPath =
          '${Directory.current.path}/tmp/test_keys_file.atKeys';
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.enroll,
        otp: testOtp,
        atKeysFilePath: testKeysPath,
        rootDomain: 'root.test.com',
      );

      activate = Activate(flows, params);
      expect(activate.getKeysFile()?.path, equals(File(testKeysPath).path));
    });
  });
}
