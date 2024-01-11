import 'package:at_client/at_client.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import '../sshnp_mocks.dart';

void main() {
  group('ConfigKeyRepository', () {
    /// NB: other tests depend on [ConfigKeyRepository.atKeyFromProfileName]
    /// other tests may fail if this test fails
    test('ConfigKeyRepository.atKeyFromProfileName test', () {
      String profileName = 'myProfileName';
      String sharedBy = '@owner';

      expect(ConfigKeyRepository.fromProfileName(profileName), isA<AtKey>());
      expect(
          ConfigKeyRepository.fromProfileName(profileName, sharedBy: sharedBy)
              .sharedBy,
          equals(sharedBy));

      expect(ConfigKeyRepository.fromProfileName(profileName).key,
          equals('${ConfigKeyRepository.keyPrefix}$profileName'));
    });

    group('[depends on ConfigKeyRepository.atKeyFromProfileName]', () {
      late MockAtClient atClient;

      setUpAll(() {
        atClient = MockAtClient();

        registerFallbackValue(AtKey());

        /// Called by [ConfigKeyRepository.listProfiles]
        when(() =>
                atClient.getAtKeys(regex: ConfigKeyRepository.configNamespace))
            .thenAnswer(
          (_) => Future.value(<AtKey>[
            ConfigKeyRepository.fromProfileName('profileName1'),
            ConfigKeyRepository.fromProfileName('profileName2'),
            ConfigKeyRepository.fromProfileName('profileName3'),
          ]),
        );

        /// Called by [ConfigKeyRepository.getParams]
        when(() => atClient.getCurrentAtSign()).thenReturn('@owner');

        /// Called by [ConfigKeyRepository.getParams]
        when(() => atClient.get(
              ConfigKeyRepository.fromProfileName('profileName1',
                  sharedBy: '@owner'),
              getRequestOptions: any(named: 'getRequestOptions'),
            )).thenAnswer(
          (_) => Future.value(
            AtValue()
              ..value = SshnpParams(
                      clientAtSign: '@owner',
                      sshnpdAtSign: '@device',
                      host: '@host')
                  .toJson(),
          ),
        );

        /// Called by [ConfigKeyRepository.putParams]
        when(() => atClient.put(any<AtKey>(), any<dynamic>(),
                putRequestOptions: any(named: 'putRequestOptions')))
            .thenAnswer((_) => Future.value(true));

        /// Called by [ConfigKeyRepository.deleteParams]
        when(() => atClient.delete(any<AtKey>(),
                deleteRequestOptions: any(named: 'deleteRequestOptions')))
            .thenAnswer((_) => Future.value(true));
      });

      test('ConfigKeyRepository.atKeyToProfileName test', () {
        String profileName = 'my_profile_name';
        AtKey atKey = ConfigKeyRepository.fromProfileName(profileName);

        expect(ConfigKeyRepository.toProfileName(atKey),
            equals(profileName.replaceAll('_', ' ')));
        expect(ConfigKeyRepository.toProfileName(atKey, replaceSpaces: false),
            equals(profileName));
        expect(ConfigKeyRepository.toProfileName(atKey, replaceSpaces: true),
            equals(profileName.replaceAll('_', ' ')));
      });

      test('ConfigKeyRepository.listProfiles test', () async {
        expect(await ConfigKeyRepository.listProfiles(atClient),
            isA<Iterable<String>>());
        expect(await ConfigKeyRepository.listProfiles(atClient),
            equals(<String>['profileName1', 'profileName2', 'profileName3']));
      });

      test('ConfigKeyRepository.getParams test', () async {
        var params = await ConfigKeyRepository.getParams('profileName1',
            atClient: atClient);
        expect(params, isA<SshnpParams>());
        expect(params.clientAtSign, equals('@owner'));
        expect(params.sshnpdAtSign, equals('@device'));
        expect(params.host, equals('@host'));
      });

      test('ConfigKeyRepository.putParams test', () async {
        when(
          () => atClient.put(
            ConfigKeyRepository.fromProfileName('profileName2',
                sharedBy: '@owner'),
            any(),
            putRequestOptions: any(named: 'putRequestOptions'),
          ),
        ).thenAnswer((_) => Future.value(true));

        verifyNever(
          () => atClient.put(
            ConfigKeyRepository.fromProfileName('profileName2',
                sharedBy: '@owner'),
            any(),
            putRequestOptions: any(named: 'putRequestOptions'),
          ),
        );

        expect(
            ConfigKeyRepository.putParams(
              SshnpParams(
                  clientAtSign: '@owner',
                  sshnpdAtSign: '@device',
                  host: '@host',
                  profileName: 'profileName2'),
              atClient: atClient,
            ),
            completes);

        verify(
          () => atClient.put(
            ConfigKeyRepository.fromProfileName('profileName2',
                sharedBy: '@owner'),
            any(),
            putRequestOptions: any(named: 'putRequestOptions'),
          ),
        ).called(1);
      });

      test('ConfigKeyRepository.deleteParams test', () async {
        when(
          () => atClient.delete(
            ConfigKeyRepository.fromProfileName('profileName2',
                sharedBy: '@owner'),
            deleteRequestOptions: any(named: 'deleteRequestOptions'),
          ),
        ).thenAnswer((_) => Future.value(true));

        verifyNever(
          () => atClient.delete(
            ConfigKeyRepository.fromProfileName('profileName2',
                sharedBy: '@owner'),
            deleteRequestOptions: any(named: 'deleteRequestOptions'),
          ),
        );

        expect(
            ConfigKeyRepository.deleteParams(
              'profileName2',
              atClient: atClient,
            ),
            completes);

        verify(
          () => atClient.delete(
            ConfigKeyRepository.fromProfileName('profileName2',
                sharedBy: '@owner'),
            deleteRequestOptions: any(named: 'deleteRequestOptions'),
          ),
        ).called(1);
      });
    });
  });
}
