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

    test('enroll created and approved successfully', () async {
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.enroll,
        otp: testOtp,
        deviceName: testDeviceName,
        atKeysFilePath: 'dummy_keys_file',
        rootDomain: 'root.test.com',
      );
      activate = Activate(flows, params);

      when(() => flows.enroll(any(),
          otp: params.otp!,
          app: params.appName,
          device: params.deviceName!,
          namespaces: params.namespaces,
          keys: any(named: 'keys'),
          preference: any(named: 'preference'),
          storage: any(named: 'storage'))).thenAnswer((_) async => client);

      final result = await activate.enroll();
      expect(result, equals(0));
    });

    test('enroll not approved', () async {
      params = ActivateParams(
        atsign: testAtsign,
        type: ActivateType.enroll,
        otp: testOtp,
        deviceName: testDeviceName,
        atKeysFilePath: 'dummy_keys_file',
        rootDomain: 'root.test.com',
      );
      activate = Activate(flows, params);

      when(() => flows.enroll(any(),
              otp: params.otp!,
              app: params.appName,
              device: params.deviceName!,
              namespaces: params.namespaces,
              keys: any(named: 'keys'),
              preference: any(named: 'preference'),
              storage: any(named: 'storage')))
          .thenThrow(AtEnrollmentException('enrollment denied'));

      final result = await activate.enroll();
      expect(result, equals(1));
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
