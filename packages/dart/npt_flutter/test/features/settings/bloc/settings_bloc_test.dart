import 'package:at_client/at_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/settings/bloc/settings_bloc.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/features/settings/repository/settings_repository.dart';
import 'package:npt_flutter/util/language.dart';

import 'settings_bloc_test.mocks.dart';

@GenerateMocks([SettingsRepository])
void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsBloc', () {
    late SettingsBloc settingsBloc;
    late MockSettingsRepository mockRepository;

    final testSettings = Settings(
      relayAtsign: '@rv_eu'.toAtsign(),
      overrideRelay: true,
      viewLayout: PreferredViewLayout.sshStyle,
      darkMode: true,
      language: Language.spanish,
    );

    final defaultSettings = Settings(
      relayAtsign: '@rv_am'.toAtsign(),
      overrideRelay: false,
      viewLayout: PreferredViewLayout.minimal,
      darkMode: false,
      language: Language.english,
    );

    setUp(() {
      mockRepository = MockSettingsRepository();
      settingsBloc = SettingsBloc(mockRepository);
    });

    tearDown(() {
      settingsBloc.close();
    });

    test('initial state is SettingsInitial', () {
      expect(settingsBloc.state, equals(const SettingsInitial()));
    });

    group('clear', () {
      test('should emit SettingsInitial when clear is called', () {
        // Arrange: Set bloc to a loaded state first
        settingsBloc.emit(SettingsLoaded(settings: testSettings));

        // Act
        settingsBloc.clear();

        // Assert
        expect(settingsBloc.state, equals(const SettingsInitial()));
      });
    });

    group('SettingsLoadEvent', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits [SettingsLoading, SettingsLoaded] when settings load successfully',
        build: () {
          when(
            mockRepository.getSettings(),
          ).thenAnswer((_) async => testSettings);
          return settingsBloc;
        },
        act: (bloc) => bloc.add(const SettingsLoadEvent()),
        expect: () => [
          const SettingsLoading(),
          SettingsLoaded(settings: testSettings),
        ],
        verify: (_) {
          verify(mockRepository.getSettings()).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [SettingsLoading, SettingsFailedLoad] when repository returns null',
        build: () {
          when(mockRepository.getSettings()).thenAnswer((_) async => null);
          when(mockRepository.defaultSettings).thenReturn(defaultSettings);
          return settingsBloc;
        },
        act: (bloc) => bloc.add(const SettingsLoadEvent()),
        expect: () => [
          const SettingsLoading(),
          SettingsFailedLoad(settings: defaultSettings),
        ],
        verify: (_) {
          verify(mockRepository.getSettings()).called(1);
          verify(mockRepository.defaultSettings).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [SettingsLoading, SettingsFailedLoad] when repository throws exception',
        build: () {
          when(
            mockRepository.getSettings(),
          ).thenThrow(Exception('Load failed'));
          when(mockRepository.defaultSettings).thenReturn(defaultSettings);
          return settingsBloc;
        },
        act: (bloc) => bloc.add(const SettingsLoadEvent()),
        expect: () => [
          const SettingsLoading(),
          SettingsFailedLoad(settings: defaultSettings),
        ],
        verify: (_) {
          verify(mockRepository.getSettings()).called(1);
          verify(mockRepository.defaultSettings).called(1);
        },
      );
    });

    group('SettingsEditEvent', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits [SettingsLoaded] when editing without saving',
        build: () => settingsBloc,
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: false)),
        expect: () => [SettingsLoaded(settings: testSettings)],
        verify: (_) {
          // Verify putSettings was never called
          verifyZeroInteractions(mockRepository);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [SettingsLoaded] when editing and saving successfully',
        build: () {
          when(
            mockRepository.putSettings(testSettings),
          ).thenAnswer((_) async => true);
          return settingsBloc;
        },
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: true)),
        expect: () => [SettingsLoaded(settings: testSettings)],
        verify: (_) {
          verify(mockRepository.putSettings(testSettings)).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [SettingsFailedSave] when editing and saving fails',
        build: () {
          when(
            mockRepository.putSettings(testSettings),
          ).thenAnswer((_) async => false);
          return settingsBloc;
        },
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: true)),
        expect: () => [SettingsFailedSave(settings: testSettings)],
        verify: (_) {
          verify(mockRepository.putSettings(testSettings)).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [SettingsFailedSave] when saving throws exception',
        build: () {
          when(
            mockRepository.putSettings(testSettings),
          ).thenThrow(Exception('Save failed'));
          return settingsBloc;
        },
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: true)),
        expect: () => [SettingsFailedSave(settings: testSettings)],
        verify: (_) {
          verify(mockRepository.putSettings(testSettings)).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'does not emit state when bloc is in loading state',
        build: () => settingsBloc,
        seed: () => const SettingsLoading(),
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: true)),
        expect: () => [],
        verify: (_) {
          // Verify putSettings was never called when in loading state
          verifyZeroInteractions(mockRepository);
        },
      );
    });

    group('State Transitions', () {
      blocTest<SettingsBloc, SettingsState>(
        'can transition from loaded to editing and back to loaded',
        build: () {
          when(
            mockRepository.putSettings(testSettings),
          ).thenAnswer((_) async => true);
          return settingsBloc;
        },
        seed: () => SettingsLoaded(settings: defaultSettings),
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: true)),
        expect: () => [SettingsLoaded(settings: testSettings)],
      );

      blocTest<SettingsBloc, SettingsState>(
        'can transition from failed load to editing',
        build: () {
          when(
            mockRepository.putSettings(testSettings),
          ).thenAnswer((_) async => true);
          return settingsBloc;
        },
        seed: () => SettingsFailedLoad(settings: defaultSettings),
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: true)),
        expect: () => [SettingsLoaded(settings: testSettings)],
      );

      blocTest<SettingsBloc, SettingsState>(
        'can transition from failed save to editing again',
        build: () {
          when(
            mockRepository.putSettings(testSettings),
          ).thenAnswer((_) async => true);
          return settingsBloc;
        },
        seed: () => SettingsFailedSave(settings: testSettings),
        act: (bloc) =>
            bloc.add(SettingsEditEvent(settings: testSettings, save: true)),
        expect: () => [SettingsLoaded(settings: testSettings)],
      );
    });

    group('Multiple Events', () {
      blocTest<SettingsBloc, SettingsState>(
        'handles multiple edit events in sequence',
        build: () {
          when(
            mockRepository.putSettings(defaultSettings),
          ).thenAnswer((_) async => true);
          return settingsBloc;
        },
        act: (bloc) async {
          bloc.add(SettingsEditEvent(settings: testSettings, save: false));
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(SettingsEditEvent(settings: defaultSettings, save: true));
        },
        expect: () => [
          SettingsLoaded(settings: testSettings),
          SettingsLoaded(settings: defaultSettings),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'handles load event followed by edit event',
        build: () {
          when(
            mockRepository.getSettings(),
          ).thenAnswer((_) async => testSettings);
          when(
            mockRepository.putSettings(defaultSettings),
          ).thenAnswer((_) async => true);
          return settingsBloc;
        },
        act: (bloc) async {
          bloc.add(const SettingsLoadEvent());
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(SettingsEditEvent(settings: defaultSettings, save: true));
        },
        expect: () => [
          const SettingsLoading(),
          SettingsLoaded(settings: testSettings),
          SettingsLoaded(settings: defaultSettings),
        ],
      );
    });

    group('Edge Cases', () {
      test('bloc can be closed without issues', () async {
        expect(() => settingsBloc.close(), returnsNormally);
      });

      blocTest<SettingsBloc, SettingsState>(
        'handles rapid successive events gracefully',
        build: () {
          when(
            mockRepository.putSettings(testSettings.copyWith(darkMode: true)),
          ).thenAnswer((_) async => true);
          when(
            mockRepository.putSettings(testSettings.copyWith(darkMode: false)),
          ).thenAnswer((_) async => true);
          return settingsBloc;
        },
        act: (bloc) {
          // Add multiple events rapidly
          for (int i = 0; i < 5; i++) {
            bloc.add(
              SettingsEditEvent(
                settings: testSettings.copyWith(darkMode: i % 2 == 0),
                save: false,
              ),
            );
          }
        },
        expect: () => [
          SettingsLoaded(settings: testSettings.copyWith(darkMode: true)),
          SettingsLoaded(settings: testSettings.copyWith(darkMode: false)),
          SettingsLoaded(settings: testSettings.copyWith(darkMode: true)),
          SettingsLoaded(settings: testSettings.copyWith(darkMode: false)),
          SettingsLoaded(settings: testSettings.copyWith(darkMode: true)),
        ],
      );
    });
  });
}
