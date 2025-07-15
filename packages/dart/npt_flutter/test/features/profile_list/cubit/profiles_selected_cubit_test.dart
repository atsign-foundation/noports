import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_selected_cubit.dart';

void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfilesSelectedCubit', () {
    late ProfilesSelectedCubit cubit;

    setUp(() {
      cubit = ProfilesSelectedCubit();
    });

    tearDown(() {
      cubit.close();
    });

    group('Initial State and Properties', () {
      test('has correct initial state, properties, and immutability', () {
        // Initial state validation
        expect(cubit.state.selected, isEmpty);
        expect(cubit.state.selected, isA<Set<String>>());
        expect(cubit.state.toString(), equals('ProfilesSelectedState({})'));
        expect(cubit.state.props, equals([<String>{}]));

        // State equality and immutability
        const state1 = ProfilesSelectedState({'uuid1', 'uuid2'});
        const state2 = ProfilesSelectedState({'uuid1', 'uuid2'});
        const state3 = ProfilesSelectedState({'uuid1', 'uuid3'});
        const state4 = ProfilesSelectedState({'uuid2', 'uuid1'}); // Same items, different order

        expect(state1, equals(state2));
        expect(state1, equals(state4)); // Sets ignore order
        expect(state1, isNot(equals(state3)));

        // toString formatting
        expect(state1.toString(), equals('ProfilesSelectedState({uuid1, uuid2})'));

        // Props validation
        expect(
            state1.props,
            equals([
              {'uuid1', 'uuid2'}
            ]));
      });
    });

    group('select', () {
      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'handles single and multiple UUID selection with uniqueness',
        build: () => cubit,
        act: (cubit) {
          cubit.select('uuid1');
          cubit.select('uuid2');
          cubit.select('uuid3');
          cubit.select('uuid1'); // Duplicate - should not emit again
        },
        expect: () => [
          const ProfilesSelectedState({'uuid1'}),
          const ProfilesSelectedState({'uuid1', 'uuid2'}),
          const ProfilesSelectedState({'uuid1', 'uuid2', 'uuid3'}),
          // No fourth emission because uuid1 already selected
        ],
      );

      test('maintains set properties for uniqueness', () {
        cubit.select('uuid1');
        cubit.select('uuid1');

        expect(cubit.state.selected, hasLength(1));
        expect(cubit.state.selected, contains('uuid1'));
      });
    });

    group('deselect', () {
      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'handles deselection scenarios including non-existent UUIDs and empty state',
        build: () {
          cubit.select('uuid1');
          cubit.select('uuid2');
          cubit.select('uuid3');
          return cubit;
        },
        act: (cubit) {
          cubit.deselect('uuid1'); // Remove existing
          cubit.deselect('uuid4'); // Remove non-existent (should not emit)
          cubit.deselect('uuid3'); // Remove another existing
        },
        expect: () => [
          const ProfilesSelectedState({'uuid2', 'uuid3'}),
          // No emission for uuid4 deselection
          const ProfilesSelectedState({'uuid2'}),
        ],
      );

      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'results in empty set when deselecting all selected items',
        build: () {
          cubit.select('uuid1');
          return cubit;
        },
        act: (cubit) => cubit.deselect('uuid1'),
        expect: () => [
          const ProfilesSelectedState({}),
        ],
      );
    });

    group('deselectAll', () {
      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'clears all selections and handles empty state',
        build: () {
          cubit.select('uuid1');
          cubit.select('uuid2');
          cubit.select('uuid3');
          return cubit;
        },
        act: (cubit) => cubit.deselectAll(),
        expect: () => [
          const ProfilesSelectedState({}),
        ],
      );

      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'works correctly when already empty',
        build: () => cubit,
        act: (cubit) => cubit.deselectAll(),
        expect: () => [
          const ProfilesSelectedState({}),
        ],
      );
    });

    group('selectAll', () {
      test('does nothing when no context available', () {
        // Without setting up any widget tree, App.navState.currentContext will be null
        final initialState = cubit.state;

        cubit.selectAll();

        // Should not change state when no context is available
        expect(cubit.state, equals(initialState));
      });
    });

    group('ProfilesSelectedState Helper Methods', () {
      group('withAdded', () {
        test('handles adding UUIDs with immutability and edge cases', () {
          // Basic addition
          const initialState = ProfilesSelectedState({'uuid1'});
          final newState = initialState.withAdded({'uuid2', 'uuid3'});
          expect(newState.selected, equals({'uuid1', 'uuid2', 'uuid3'}));

          // Handle duplicates
          final duplicateState = initialState.withAdded({'uuid1', 'uuid2'});
          expect(duplicateState.selected, equals({'uuid1', 'uuid2'}));
          expect(duplicateState.selected, hasLength(2));

          // Handle empty set
          final emptyAddState = initialState.withAdded(<String>{});
          expect(emptyAddState.selected, equals({'uuid1'}));

          // Verify immutability
          expect(initialState.selected, equals({'uuid1'}));
          expect(identical(initialState, newState), isFalse);
        });
      });

      group('withRemoved', () {
        test('handles removing UUIDs with immutability and edge cases', () {
          const initialState = ProfilesSelectedState({'uuid1', 'uuid2', 'uuid3'});

          // Basic removal
          final removedState = initialState.withRemoved({'uuid1', 'uuid3'});
          expect(removedState.selected, equals({'uuid2'}));

          // Handle non-existent UUIDs
          final nonExistentState = initialState.withRemoved({'uuid4', 'uuid5'});
          expect(nonExistentState.selected, equals({'uuid1', 'uuid2', 'uuid3'}));

          // Handle empty set removal
          final emptyRemoveState = initialState.withRemoved(<String>{});
          expect(emptyRemoveState.selected, equals({'uuid1', 'uuid2', 'uuid3'}));

          // Can result in empty selection
          final emptyResult = initialState.withRemoved({'uuid1', 'uuid2', 'uuid3'});
          expect(emptyResult.selected, isEmpty);

          // Verify immutability
          expect(initialState.selected, equals({'uuid1', 'uuid2', 'uuid3'}));
          expect(identical(initialState, removedState), isFalse);
        });
      });
    });

    group('Complex Scenarios and Edge Cases', () {
      test('handles complex selection workflow and edge cases', () {
        // Complex workflow
        cubit.select('uuid1');
        expect(cubit.state.selected, equals({'uuid1'}));

        cubit.select('uuid2');
        expect(cubit.state.selected, equals({'uuid1', 'uuid2'}));

        cubit.deselect('uuid1');
        expect(cubit.state.selected, equals({'uuid2'}));

        cubit.select('uuid3');
        expect(cubit.state.selected, equals({'uuid2', 'uuid3'}));

        cubit.deselectAll();
        expect(cubit.state.selected, isEmpty);

        // Edge cases
        cubit.select(''); // Empty string UUID
        expect(cubit.state.selected, equals({''}));

        final longUuid = 'a' * 1000; // Very long UUID
        cubit.select(longUuid);
        expect(cubit.state.selected, contains(longUuid));

        // Special characters
        cubit.select('uuid-with-dashes');
        cubit.select('uuid_with_underscores');
        cubit.select('uuid.with.dots');
        expect(cubit.state.selected, containsAll(['uuid-with-dashes', 'uuid_with_underscores', 'uuid.with.dots']));
      });

      testWidgets('selectAll handles null context gracefully', (tester) async {
        // Don't set up any widget tree, so App.navState.currentContext will be null
        cubit.selectAll();
        expect(cubit.state.selected, isEmpty); // Should not throw and remain unchanged
      });
    });
  });
}
