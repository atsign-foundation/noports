import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:socket_connector/socket_connector.dart';

// Mock SocketConnector for testing
class MockSocketConnector extends Mock implements SocketConnector {}

void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfilesRunningCubit', () {
    late ProfilesRunningCubit cubit;
    late MockSocketConnector mockConnector1;
    late MockSocketConnector mockConnector2;

    setUp(() {
      cubit = ProfilesRunningCubit();
      mockConnector1 = MockSocketConnector();
      mockConnector2 = MockSocketConnector();
    });

    tearDown(() {
      cubit.close();
    });

    group('Initial State', () {
      test('has correct initial state, toString, and props', () {
        expect(cubit.state.socketConnectors, isEmpty);
        expect(
            cubit.state.socketConnectors, isA<Map<String, SocketConnector?>>());
        expect(cubit.state.toString(), equals('ProfilesRunningState({})'));
        expect(cubit.state.props, equals([<String, SocketConnector?>{}]));
      });
    });

    group('prepare', () {
      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'adds UUID with null connector to prepare slot',
        build: () => cubit,
        act: (cubit) => cubit.prepare('uuid1'),
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == null),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'prepares multiple UUIDs',
        build: () => cubit,
        act: (cubit) {
          cubit.prepare('uuid1');
          cubit.prepare('uuid2');
        },
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == null),
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == null &&
              state.socketConnectors.containsKey('uuid2') &&
              state.socketConnectors['uuid2'] == null),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'overwrites existing prepared slot',
        build: () => cubit,
        act: (cubit) {
          cubit.prepare('uuid1');
          cubit.prepare(
              'uuid1'); // Prepare again - won't emit since state is the same
        },
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == null),
          // Second prepare won't emit since the state is identical
        ],
      );
    });

    group('cache', () {
      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'caches connector for UUID',
        build: () => cubit,
        act: (cubit) => cubit.cache('uuid1', mockConnector1),
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == mockConnector1),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'caches multiple connectors',
        build: () => cubit,
        act: (cubit) {
          cubit.cache('uuid1', mockConnector1);
          cubit.cache('uuid2', mockConnector2);
        },
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == mockConnector1),
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == mockConnector1 &&
              state.socketConnectors.containsKey('uuid2') &&
              state.socketConnectors['uuid2'] == mockConnector2),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'overwrites existing connector',
        build: () => cubit,
        act: (cubit) {
          cubit.cache('uuid1', mockConnector1);
          cubit.cache(
              'uuid1', mockConnector2); // Replace with different connector
        },
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == mockConnector1),
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == mockConnector2 &&
              state.socketConnectors.length == 1),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'prepares UUID with null connector (preparation slot)',
        build: () => cubit,
        act: (cubit) => cubit.prepare('uuid1'),
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == null),
        ],
      );
    });

    group('invalidate', () {
      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'removes UUID and closes connector',
        build: () => cubit,
        seed: () => ProfilesRunningState({'uuid1': mockConnector1}),
        act: (cubit) => cubit.invalidate('uuid1'),
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => !state.socketConnectors.containsKey('uuid1')),
        ],
        verify: (_) {
          verify(mockConnector1.close()).called(
              2); // Called by both cubit.invalidate() and state.withoutConnector()
        },
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'handles invalidating non-existent UUID gracefully',
        build: () => cubit,
        act: (cubit) => cubit.invalidate('non-existent'),
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => state.socketConnectors.isEmpty),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'removes specific UUID while preserving others',
        build: () => cubit,
        seed: () => ProfilesRunningState({
          'uuid1': mockConnector1,
          'uuid2': mockConnector2,
        }),
        act: (cubit) => cubit.invalidate('uuid1'),
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              !state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors.containsKey('uuid2') &&
              state.socketConnectors['uuid2'] == mockConnector2),
        ],
        verify: (_) {
          verify(mockConnector1.close()).called(
              2); // Called by both cubit.invalidate() and state.withoutConnector()
          verifyNever(mockConnector2.close());
        },
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'handles invalidating UUID with null connector',
        build: () => cubit,
        seed: () => const ProfilesRunningState({'uuid1': null}),
        act: (cubit) => cubit.invalidate('uuid1'),
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => !state.socketConnectors.containsKey('uuid1')),
        ],
      );
    });

    group('stopAllAndClear', () {
      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'clears all connectors and closes them',
        build: () => cubit,
        seed: () => ProfilesRunningState({
          'uuid1': mockConnector1,
          'uuid2': mockConnector2,
          'uuid3': null,
        }),
        act: (cubit) => cubit.stopAllAndClear(),
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => state.socketConnectors.isEmpty),
        ],
        verify: (_) {
          verify(mockConnector1.close()).called(1);
          verify(mockConnector2.close()).called(1);
        },
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'works correctly when already empty',
        build: () => cubit,
        act: (cubit) => cubit.stopAllAndClear(),
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => state.socketConnectors.isEmpty),
        ],
      );
    });

    group('ProfilesRunningState', () {
      test('equality, toString, and props work correctly', () {
        final state1 = ProfilesRunningState({'uuid1': mockConnector1});
        final state2 = ProfilesRunningState({'uuid1': mockConnector1});
        final state3 = ProfilesRunningState({'uuid1': mockConnector2});
        final state4 = ProfilesRunningState({'uuid2': mockConnector1});

        // Equality
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state1, isNot(equals(state4)));

        // toString
        expect(state1.toString(), contains('ProfilesRunningState'));
        expect(state1.toString(), contains('uuid1'));

        // props
        final connectors = {'uuid1': mockConnector1};
        expect(state1.props, equals([connectors]));
      });
    });

    group('withConnector', () {
      test('adds new UUID with connector to existing state', () {
        final initialState = ProfilesRunningState({'uuid1': mockConnector1});
        final newState = initialState.withConnector('uuid2', mockConnector2);

        expect(newState.socketConnectors['uuid1'], equals(mockConnector1));
        expect(newState.socketConnectors['uuid2'], equals(mockConnector2));
        expect(newState.socketConnectors.length, equals(2));
      });

      test('handles adding existing UUID (overwrites)', () {
        final initialState = ProfilesRunningState({'uuid1': mockConnector1});
        final newState = initialState.withConnector('uuid1', mockConnector2);

        expect(newState.socketConnectors['uuid1'], equals(mockConnector2));
        expect(newState.socketConnectors.length, equals(1));
      });

      test('handles adding empty set', () {
        const initialState = ProfilesRunningState({});
        final newState = initialState.withConnector('uuid1', mockConnector1);

        expect(newState.socketConnectors['uuid1'], equals(mockConnector1));
        expect(newState.socketConnectors.length, equals(1));
      });

      test(
          'creates new instances (immutability) for both withConnector and withoutConnector',
          () {
        // Test withConnector immutability
        final initialState1 = ProfilesRunningState({'uuid1': mockConnector1});
        final newState1 = initialState1.withConnector('uuid2', mockConnector2);
        expect(newState1, isNot(same(initialState1)));
        expect(initialState1.socketConnectors.length, equals(1));
        expect(newState1.socketConnectors.length, equals(2));

        // Test withoutConnector immutability
        final initialState2 = ProfilesRunningState({
          'uuid1': mockConnector1,
          'uuid2': mockConnector2,
        });
        final newState2 = initialState2.withoutConnector('uuid1');
        expect(newState2, isNot(same(initialState2)));
        expect(initialState2.socketConnectors.length, equals(2));
        expect(newState2.socketConnectors.length, equals(1));
      });
    });

    group('withoutConnector', () {
      test('removes specified UUID from connectors', () {
        final mockConnector = MockSocketConnector();
        final initialState = ProfilesRunningState({
          'uuid1': mockConnector1,
          'uuid2': mockConnector,
        });
        final newState = initialState.withoutConnector('uuid1');

        expect(newState.socketConnectors.containsKey('uuid1'), isFalse);
        expect(newState.socketConnectors['uuid2'], equals(mockConnector));
        expect(newState.socketConnectors.length, equals(1));
        verify(mockConnector1.close()).called(1);
      });

      test('handles removing non-existent UUID gracefully', () {
        final initialState = ProfilesRunningState({'uuid1': mockConnector1});
        final newState = initialState.withoutConnector('non-existent');

        expect(newState, equals(initialState));
        expect(newState.socketConnectors['uuid1'], equals(mockConnector1));
        verifyNever(mockConnector1.close());
      });

      test(
          'handles removing from empty state and can result in empty connectors',
          () {
        // Test removing from empty state
        const initialEmptyState = ProfilesRunningState({});
        final newEmptyState = initialEmptyState.withoutConnector('uuid1');
        expect(newEmptyState, equals(initialEmptyState));
        expect(newEmptyState.socketConnectors.isEmpty, isTrue);

        // Test resulting in empty connectors
        final initialState = ProfilesRunningState({'uuid1': mockConnector1});
        final newState = initialState.withoutConnector('uuid1');
        expect(newState.socketConnectors.isEmpty, isTrue);
        verify(mockConnector1.close()).called(1);
      });

      test(
          'creates new instances (immutability) for both withConnector and withoutConnector',
          () {
        // Test withConnector immutability
        final initialState1 = ProfilesRunningState({'uuid1': mockConnector1});
        final newState1 = initialState1.withConnector('uuid2', mockConnector2);
        expect(newState1, isNot(same(initialState1)));
        expect(initialState1.socketConnectors.length, equals(1));
        expect(newState1.socketConnectors.length, equals(2));

        // Test withoutConnector immutability
        final initialState2 = ProfilesRunningState({
          'uuid1': mockConnector1,
          'uuid2': mockConnector2,
        });
        final newState2 = initialState2.withoutConnector('uuid1');
        expect(newState2, isNot(same(initialState2)));
        expect(initialState2.socketConnectors.length, equals(2));
        expect(newState2.socketConnectors.length, equals(1));
      });

      test('handles removing UUID with null connector', () {
        const initialState = ProfilesRunningState({'uuid1': null});
        final newState = initialState.withoutConnector('uuid1');

        expect(newState.socketConnectors.containsKey('uuid1'), isFalse);
        expect(newState.socketConnectors.isEmpty, isTrue);
      });
    });

    group('Complex Scenarios', () {
      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'complex workflow: prepare -> cache -> invalidate',
        build: () => cubit,
        act: (cubit) {
          cubit.prepare('uuid1');
          cubit.cache('uuid1', mockConnector1);
          cubit.invalidate('uuid1');
        },
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == null),
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == mockConnector1),
          predicate<ProfilesRunningState>(
              (state) => !state.socketConnectors.containsKey('uuid1')),
        ],
        verify: (_) {
          verify(mockConnector1.close()).called(
              2); // Called by both cubit.invalidate() and state.withoutConnector()
        },
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'connector state persists between different operations',
        build: () => cubit,
        act: (cubit) {
          cubit.cache('uuid1', mockConnector1);
          cubit.prepare('uuid2');
          cubit.cache('uuid3', mockConnector2);
        },
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => state.socketConnectors['uuid1'] == mockConnector1),
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors['uuid1'] == mockConnector1 &&
              state.socketConnectors['uuid2'] == null),
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors['uuid1'] == mockConnector1 &&
              state.socketConnectors['uuid2'] == null &&
              state.socketConnectors['uuid3'] == mockConnector2),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'invalidate only affects specified items',
        build: () => cubit,
        seed: () => ProfilesRunningState({
          'uuid1': mockConnector1,
          'uuid2': mockConnector2,
          'uuid3': null,
        }),
        act: (cubit) => cubit.invalidate('uuid2'),
        expect: () => [
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid1'] == mockConnector1 &&
              !state.socketConnectors.containsKey('uuid2') &&
              state.socketConnectors.containsKey('uuid3') &&
              state.socketConnectors['uuid3'] == null),
        ],
        verify: (_) {
          verifyNever(mockConnector1.close());
          verify(mockConnector2.close()).called(
              2); // Called by both cubit.invalidate() and state.withoutConnector()
        },
      );
    });

    group('Edge Cases', () {
      test('handles various UUID formats', () {
        // Empty string UUID
        cubit.prepare('');
        expect(cubit.state.socketConnectors.containsKey(''), isTrue);
        expect(cubit.state.socketConnectors[''], isNull);

        // Very long UUID
        final longUuid = 'a' * 1000;
        cubit.cache(longUuid, mockConnector1);
        expect(cubit.state.socketConnectors.containsKey(longUuid), isTrue);
        expect(cubit.state.socketConnectors[longUuid], equals(mockConnector1));

        // Special characters in UUID
        const specialUuid = 'uuid-with-special-chars_123!@#';
        cubit.cache(specialUuid, mockConnector2);
        expect(cubit.state.socketConnectors.containsKey(specialUuid), isTrue);
        expect(
            cubit.state.socketConnectors[specialUuid], equals(mockConnector2));
      });

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'stopAllAndClear handles only null connectors',
        build: () => cubit,
        seed: () => const ProfilesRunningState({
          'uuid1': null,
          'uuid2': null,
          'uuid3': null,
        }),
        act: (cubit) => cubit.stopAllAndClear(),
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => state.socketConnectors.isEmpty),
        ],
      );

      blocTest<ProfilesRunningCubit, ProfilesRunningState>(
        'connector operations maintain proper reference tracking',
        build: () => cubit,
        act: (cubit) {
          cubit.cache('uuid1', mockConnector1);
          cubit.cache(
              'uuid2', mockConnector1); // Same connector for different UUID
          cubit.invalidate('uuid1');
        },
        expect: () => [
          predicate<ProfilesRunningState>(
              (state) => state.socketConnectors['uuid1'] == mockConnector1),
          predicate<ProfilesRunningState>((state) =>
              state.socketConnectors['uuid1'] == mockConnector1 &&
              state.socketConnectors['uuid2'] == mockConnector1),
          predicate<ProfilesRunningState>((state) =>
              !state.socketConnectors.containsKey('uuid1') &&
              state.socketConnectors['uuid2'] == mockConnector1),
        ],
        verify: (_) {
          // Called twice: once by cubit.invalidate() and once by state.withoutConnector()
          verify(mockConnector1.close()).called(2);
        },
      );
    });
  });
}
