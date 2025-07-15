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

    group('Initial State', () {
      test('has correct initial state', () {
        expect(cubit.state.selected, isEmpty);
        expect(cubit.state.selected, isA<Set<String>>());
      });

      test('initial state toString is correct', () {
        expect(cubit.state.toString(), equals('ProfilesSelectedState({})'));
      });

      test('initial state props are correct', () {
        expect(cubit.state.props, equals([<String>{}]));
      });
    });

    group('select', () {
      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'adds single UUID to selection',
        build: () => cubit,
        act: (cubit) => cubit.select('uuid1'),
        expect: () => [
          const ProfilesSelectedState({'uuid1'}),
        ],
      );

      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'adds multiple UUIDs to selection',
        build: () => cubit,
        act: (cubit) {
          cubit.select('uuid1');
          cubit.select('uuid2');
          cubit.select('uuid3');
        },
        expect: () => [
          const ProfilesSelectedState({'uuid1'}),
          const ProfilesSelectedState({'uuid1', 'uuid2'}),
          const ProfilesSelectedState({'uuid1', 'uuid2', 'uuid3'}),
        ],
      );

      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'does not duplicate UUIDs when selecting same UUID twice',
        build: () => cubit,
        act: (cubit) {
          cubit.select('uuid1');
          cubit.select('uuid1');
        },
        expect: () => [
          const ProfilesSelectedState({'uuid1'}),
          // No second emission because the state is the same
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
        'removes UUID from selection',
        build: () {
          cubit.select('uuid1');
          cubit.select('uuid2');
          return cubit;
        },
        act: (cubit) => cubit.deselect('uuid1'),
        expect: () => [
          const ProfilesSelectedState({'uuid2'}),
        ],
      );

      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'handles deselecting non-existent UUID gracefully',
        build: () {
          cubit.select('uuid1');
          return cubit;
        },
        act: (cubit) => cubit.deselect('uuid2'),
        expect: () => [
          // No state change because uuid2 was not selected
        ],
      );

      blocTest<ProfilesSelectedCubit, ProfilesSelectedState>(
        'removes multiple UUIDs from selection',
        build: () {
          cubit.select('uuid1');
          cubit.select('uuid2');
          cubit.select('uuid3');
          return cubit;
        },
        act: (cubit) {
          cubit.deselect('uuid1');
          cubit.deselect('uuid3');
        },
        expect: () => [
          const ProfilesSelectedState({'uuid2', 'uuid3'}),
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
        'clears all selections',
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

      test('results in empty set', () {
        cubit.select('uuid1');
        cubit.select('uuid2');
        cubit.deselectAll();

        expect(cubit.state.selected, isEmpty);
      });
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

    group('ProfilesSelectedState', () {
      test('equality works correctly', () {
        const state1 = ProfilesSelectedState({'uuid1', 'uuid2'});
        const state2 = ProfilesSelectedState({'uuid1', 'uuid2'});
        const state3 = ProfilesSelectedState({'uuid1', 'uuid3'});
        const state4 = ProfilesSelectedState({'uuid2', 'uuid1'}); // Same items, different order

        expect(state1, equals(state2));
        expect(state1, equals(state4)); // Sets ignore order
        expect(state1, isNot(equals(state3)));
      });

      test('toString returns correct format', () {
        const state1 = ProfilesSelectedState({'uuid1', 'uuid2'});
        const state2 = ProfilesSelectedState({});

        expect(state1.toString(), equals('ProfilesSelectedState({uuid1, uuid2})'));
        expect(state2.toString(), equals('ProfilesSelectedState({})'));
      });

      test('props includes the selected set', () {
        const state = ProfilesSelectedState({'uuid1', 'uuid2'});
        expect(
            state.props,
            equals([
              {'uuid1', 'uuid2'}
            ]));
      });

      group('withAdded', () {
        test('adds new UUIDs to existing selection', () {
          const initialState = ProfilesSelectedState({'uuid1'});
          final newState = initialState.withAdded({'uuid2', 'uuid3'});

          expect(newState.selected, equals({'uuid1', 'uuid2', 'uuid3'}));
        });

        test('handles adding existing UUIDs (no duplicates)', () {
          const initialState = ProfilesSelectedState({'uuid1', 'uuid2'});
          final newState = initialState.withAdded({'uuid2', 'uuid3'});

          expect(newState.selected, equals({'uuid1', 'uuid2', 'uuid3'}));
          expect(newState.selected, hasLength(3));
        });

        test('handles adding empty set', () {
          const initialState = ProfilesSelectedState({'uuid1'});
          final newState = initialState.withAdded(<String>{});

          expect(newState.selected, equals({'uuid1'}));
        });

        test('creates new instance (immutability)', () {
          const initialState = ProfilesSelectedState({'uuid1'});
          final newState = initialState.withAdded({'uuid2'});

          expect(initialState.selected, equals({'uuid1'}));
          expect(newState.selected, equals({'uuid1', 'uuid2'}));
          expect(identical(initialState, newState), isFalse);
        });
      });

      group('withRemoved', () {
        test('removes specified UUIDs from selection', () {
          const initialState = ProfilesSelectedState({'uuid1', 'uuid2', 'uuid3'});
          final newState = initialState.withRemoved({'uuid1', 'uuid3'});

          expect(newState.selected, equals({'uuid2'}));
        });

        test('handles removing non-existent UUIDs gracefully', () {
          const initialState = ProfilesSelectedState({'uuid1', 'uuid2'});
          final newState = initialState.withRemoved({'uuid3', 'uuid4'});

          expect(newState.selected, equals({'uuid1', 'uuid2'}));
        });

        test('handles removing empty set', () {
          const initialState = ProfilesSelectedState({'uuid1', 'uuid2'});
          final newState = initialState.withRemoved(<String>{});

          expect(newState.selected, equals({'uuid1', 'uuid2'}));
        });

        test('can result in empty selection', () {
          const initialState = ProfilesSelectedState({'uuid1', 'uuid2'});
          final newState = initialState.withRemoved({'uuid1', 'uuid2'});

          expect(newState.selected, isEmpty);
        });

        test('creates new instance (immutability)', () {
          const initialState = ProfilesSelectedState({'uuid1', 'uuid2'});
          final newState = initialState.withRemoved({'uuid1'});

          expect(initialState.selected, equals({'uuid1', 'uuid2'}));
          expect(newState.selected, equals({'uuid2'}));
          expect(identical(initialState, newState), isFalse);
        });
      });
    });

    group('Complex Selection Scenarios', () {
      test('handles complex selection and deselection workflow', () {
        cubit.select('uuid1');
        expect(cubit.state.selected, equals({'uuid1'}));

        cubit.select('uuid2');
        expect(cubit.state.selected, equals({'uuid1', 'uuid2'}));

        cubit.select('uuid3');
        expect(cubit.state.selected, equals({'uuid1', 'uuid2', 'uuid3'}));

        cubit.deselect('uuid2');
        expect(cubit.state.selected, equals({'uuid1', 'uuid3'}));

        cubit.select('uuid4');
        expect(cubit.state.selected, equals({'uuid1', 'uuid3', 'uuid4'}));

        cubit.deselect('uuid1');
        expect(cubit.state.selected, equals({'uuid3', 'uuid4'}));
      });

      test('maintains selection state across multiple operations', () {
        cubit.select('uuid1');
        cubit.select('uuid2');
        expect(cubit.state.selected, hasLength(2));

        cubit.deselect('uuid1');
        expect(cubit.state.selected, hasLength(1));
        expect(cubit.state.selected, contains('uuid2'));

        cubit.deselectAll();
        expect(cubit.state.selected, isEmpty);
      });
    });

    group('Edge Cases', () {
      test('handles empty string UUID', () {
        cubit.select('');
        expect(cubit.state.selected, equals({''}));
      });

      test('handles very long UUID strings', () {
        final longUuid = 'a' * 1000;
        cubit.select(longUuid);
        expect(cubit.state.selected, equals({longUuid}));
      });

      test('handles special characters in UUID', () {
        cubit.select('uuid-with-dashes');
        expect(cubit.state.selected, contains('uuid-with-dashes'));

        cubit.select('uuid_with_underscores');
        expect(cubit.state.selected, contains('uuid_with_underscores'));

        cubit.select('uuid.with.dots');
        expect(cubit.state.selected, contains('uuid.with.dots'));

        expect(cubit.state.selected, hasLength(3));
      });

      testWidgets('selectAll handles null context gracefully', (tester) async {
        // Don't set up any widget tree, so App.navState.currentContext will be null
        cubit.selectAll();

        // Should not throw and selection should remain unchanged
        expect(cubit.state.selected, isEmpty);
      });
    });

    group('State Persistence', () {
      test('selection persists between different operations', () {
        cubit.select('uuid1');
        cubit.select('uuid2');

        final firstSelection = Set<String>.from(cubit.state.selected);

        cubit.select('uuid3');

        expect(cubit.state.selected, containsAll(firstSelection));
        expect(cubit.state.selected, contains('uuid3'));
      });

      test('deselect only affects specified items', () {
        cubit.select('uuid1');
        cubit.select('uuid2');
        cubit.select('uuid3');

        cubit.deselect('uuid2');

        expect(cubit.state.selected, contains('uuid1'));
        expect(cubit.state.selected, contains('uuid3'));
        expect(cubit.state.selected, isNot(contains('uuid2')));
      });
    });
  });
}
