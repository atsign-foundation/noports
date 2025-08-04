import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';

void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingCubit', () {
    late OnboardingCubit cubit;

    setUp(() {
      cubit = OnboardingCubit();
    });

    tearDown(() {
      cubit.close();
    });

    group('Initial State', () {
      test('has correct initial state', () {
        expect(cubit.state.atSign, equals(''));
        expect(cubit.state.status, equals(OnboardingStatus.offboarded));
        expect(cubit.state.rootDomain, equals('root.atsign.org'));
      });

      test('initial state toString is correct', () {
        expect(cubit.state.toString(), equals('OnboardingState(, offboarded, root.atsign.org)'));
      });

      test('initial state props are correct', () {
        expect(cubit.state.props, equals(['', OnboardingStatus.offboarded, 'root.atsign.org']));
      });
    });

    group('setAtSign', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'emits new state with updated atSign',
        build: () => cubit,
        act: (cubit) => cubit.setAtSign('@test_user'),
        expect: () => [
          const OnboardingState(
            atSign: '@test_user',
            status: OnboardingStatus.offboarded,
            rootDomain: 'root.atsign.org',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'preserves existing status and rootDomain when setting atSign',
        build: () {
          final cubit = OnboardingCubit();
          cubit.setState(
            status: OnboardingStatus.onboarded,
            rootDomain: 'custom.domain.com',
          );
          return cubit;
        },
        act: (cubit) => cubit.setAtSign('@new_user'),
        expect: () => [
          const OnboardingState(
            atSign: '@new_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'custom.domain.com',
          ),
        ],
      );

      test('getAtSign returns current atSign', () {
        cubit.setAtSign('@test_user');
        expect(cubit.getAtSign(), equals('@test_user'));
      });
    });

    group('setStatus', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'emits new state with updated status',
        build: () => cubit,
        act: (cubit) => cubit.setStatus(OnboardingStatus.onboarded),
        expect: () => [
          const OnboardingState(
            atSign: '',
            status: OnboardingStatus.onboarded,
            rootDomain: 'root.atsign.org',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'preserves existing atSign and rootDomain when setting status',
        build: () {
          final cubit = OnboardingCubit();
          cubit.setState(
            atSign: '@existing_user',
            rootDomain: 'custom.domain.com',
          );
          return cubit;
        },
        act: (cubit) => cubit.setStatus(OnboardingStatus.onboarded),
        expect: () => [
          const OnboardingState(
            atSign: '@existing_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'custom.domain.com',
          ),
        ],
      );

      test('getStatus returns current status', () {
        cubit.setStatus(OnboardingStatus.onboarded);
        expect(cubit.getStatus(), equals(OnboardingStatus.onboarded));
      });
    });

    group('setRootDomain', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'emits new state with updated rootDomain',
        build: () => cubit,
        act: (cubit) => cubit.setRootDomain('test.domain.com'),
        expect: () => [
          const OnboardingState(
            atSign: '',
            status: OnboardingStatus.offboarded,
            rootDomain: 'test.domain.com',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'preserves existing atSign and status when setting rootDomain',
        build: () {
          final cubit = OnboardingCubit();
          cubit.setState(
            atSign: '@existing_user',
            status: OnboardingStatus.onboarded,
          );
          return cubit;
        },
        act: (cubit) => cubit.setRootDomain('custom.domain.com'),
        expect: () => [
          const OnboardingState(
            atSign: '@existing_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'custom.domain.com',
          ),
        ],
      );

      test('getRootDomain returns current rootDomain', () {
        cubit.setRootDomain('test.domain.com');
        expect(cubit.getRootDomain(), equals('test.domain.com'));
      });
    });

    group('setState', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'updates only atSign when only atSign is provided',
        build: () => cubit,
        act: (cubit) => cubit.setState(atSign: '@new_user'),
        expect: () => [
          const OnboardingState(
            atSign: '@new_user',
            status: OnboardingStatus.offboarded,
            rootDomain: 'root.atsign.org',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'updates only status when only status is provided',
        build: () => cubit,
        act: (cubit) => cubit.setState(status: OnboardingStatus.onboarded),
        expect: () => [
          const OnboardingState(
            atSign: '',
            status: OnboardingStatus.onboarded,
            rootDomain: 'root.atsign.org',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'updates only rootDomain when only rootDomain is provided',
        build: () => cubit,
        act: (cubit) => cubit.setState(rootDomain: 'custom.domain.com'),
        expect: () => [
          const OnboardingState(
            atSign: '',
            status: OnboardingStatus.offboarded,
            rootDomain: 'custom.domain.com',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'updates multiple fields when multiple parameters are provided',
        build: () => cubit,
        act: (cubit) => cubit.setState(
          atSign: '@test_user',
          status: OnboardingStatus.onboarded,
          rootDomain: 'test.domain.com',
        ),
        expect: () => [
          const OnboardingState(
            atSign: '@test_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'test.domain.com',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'preserves existing values when null is provided',
        build: () {
          final cubit = OnboardingCubit();
          cubit.setState(
            atSign: '@existing_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'existing.domain.com',
          );
          return cubit;
        },
        act: (cubit) => cubit.setState(atSign: '@new_user'), // Only update atSign
        expect: () => [
          const OnboardingState(
            atSign: '@new_user',
            status: OnboardingStatus.onboarded, // Preserved
            rootDomain: 'existing.domain.com', // Preserved
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'emits no state when no parameters are provided',
        build: () => cubit,
        act: (cubit) => cubit.setState(),
        expect: () => [
          const OnboardingState(
            atSign: '',
            status: OnboardingStatus.offboarded,
            rootDomain: 'root.atsign.org',
          ),
        ],
      );
    });

    group('Complex State Management', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'handles multiple state changes in sequence',
        build: () => cubit,
        act: (cubit) {
          cubit.setAtSign('@first_user');
          cubit.setStatus(OnboardingStatus.onboarded);
          cubit.setRootDomain('custom.domain.com');
          cubit.setAtSign('@second_user');
        },
        expect: () => [
          const OnboardingState(
            atSign: '@first_user',
            status: OnboardingStatus.offboarded,
            rootDomain: 'root.atsign.org',
          ),
          const OnboardingState(
            atSign: '@first_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'root.atsign.org',
          ),
          const OnboardingState(
            atSign: '@first_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'custom.domain.com',
          ),
          const OnboardingState(
            atSign: '@second_user',
            status: OnboardingStatus.onboarded,
            rootDomain: 'custom.domain.com',
          ),
        ],
      );

      test('getters return current state values after multiple changes', () {
        cubit.setAtSign('@test_user');
        cubit.setStatus(OnboardingStatus.onboarded);
        cubit.setRootDomain('test.domain.com');

        expect(cubit.getAtSign(), equals('@test_user'));
        expect(cubit.getStatus(), equals(OnboardingStatus.onboarded));
        expect(cubit.getRootDomain(), equals('test.domain.com'));
      });
    });

    group('OnboardingState', () {
      test('equality works correctly', () {
        const state1 = OnboardingState(
          atSign: '@test_user',
          status: OnboardingStatus.onboarded,
          rootDomain: 'test.domain.com',
        );
        const state2 = OnboardingState(
          atSign: '@test_user',
          status: OnboardingStatus.onboarded,
          rootDomain: 'test.domain.com',
        );
        const state3 = OnboardingState(
          atSign: '@different_user',
          status: OnboardingStatus.onboarded,
          rootDomain: 'test.domain.com',
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });

      test('toString and props work correctly', () {
        const state = OnboardingState(
          atSign: '@test_user',
          status: OnboardingStatus.onboarded,
          rootDomain: 'test.domain.com',
        );

        expect(state.toString(), equals('OnboardingState(@test_user, onboarded, test.domain.com)'));
        expect(state.props, equals(['@test_user', OnboardingStatus.onboarded, 'test.domain.com']));
      });
    });

    group('OnboardingStatus', () {
      test('enum properties work correctly', () {
        expect(OnboardingStatus.values, hasLength(2));
        expect(
            OnboardingStatus.values,
            allOf(
              contains(OnboardingStatus.onboarded),
              contains(OnboardingStatus.offboarded),
            ));
        expect(OnboardingStatus.onboarded.name, equals('onboarded'));
        expect(OnboardingStatus.offboarded.name, equals('offboarded'));
      });
    });

    group('Edge Cases', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'handles empty string atSign',
        build: () => cubit,
        act: (cubit) => cubit.setAtSign(''),
        expect: () => [
          const OnboardingState(
            atSign: '',
            status: OnboardingStatus.offboarded,
            rootDomain: 'root.atsign.org',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'handles empty string rootDomain',
        build: () => cubit,
        act: (cubit) => cubit.setRootDomain(''),
        expect: () => [
          const OnboardingState(
            atSign: '',
            status: OnboardingStatus.offboarded,
            rootDomain: '',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'handles very long atSign',
        build: () => cubit,
        act: (cubit) => cubit.setAtSign('@${'a' * 100}'),
        expect: () => [
          OnboardingState(
            atSign: '@${'a' * 100}',
            status: OnboardingStatus.offboarded,
            rootDomain: 'root.atsign.org',
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'handles very long rootDomain',
        build: () => cubit,
        act: (cubit) => cubit.setRootDomain('${'subdomain.' * 10}domain.com'),
        expect: () => [
          OnboardingState(
            atSign: '',
            status: OnboardingStatus.offboarded,
            rootDomain: '${'subdomain.' * 10}domain.com',
          ),
        ],
      );
    });
  });
}
