import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/favorite/bloc/favorite_bloc.dart';
import 'package:npt_flutter/features/favorite/models/favorite.dart';
import 'package:npt_flutter/features/favorite/repository/favorite_repository.dart';

import 'favorite_bloc_test.mocks.dart';

@GenerateMocks([FavoriteRepository])
void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoriteBloc', () {
    late FavoriteBloc favoriteBloc;
    late MockFavoriteRepository mockRepository;

    const testFavorite1 = FavoriteProfile(uuid: 'test-uuid-1');
    const testFavorite2 = FavoriteProfile(uuid: 'test-uuid-2');
    const testFavorite3 = FavoriteProfile(uuid: 'test-uuid-3');

    final testFavorites = <String, Favorite>{
      testFavorite1.uuid: testFavorite1,
      testFavorite2.uuid: testFavorite2,
    };

    setUp(() {
      mockRepository = MockFavoriteRepository();
      favoriteBloc = FavoriteBloc(mockRepository);
    });

    tearDown(() {
      favoriteBloc.close();
    });

    test('initial state is FavoritesInitial', () {
      expect(favoriteBloc.state, equals(const FavoritesInitial()));
    });

    group('clearAll', () {
      test('should emit FavoritesInitial when clearAll is called', () {
        // Arrange: Set bloc to a loaded state first
        favoriteBloc.emit(
          const FavoritesLoaded([testFavorite1, testFavorite2]),
        );

        // Act
        favoriteBloc.clearAll();

        // Assert
        expect(favoriteBloc.state, equals(const FavoritesInitial()));
      });
    });

    group('FavoriteLoadEvent', () {
      blocTest<FavoriteBloc, FavoritesState>(
        'emits [FavoritesLoading, FavoritesLoaded] when favorites load successfully',
        build: () {
          when(
            mockRepository.getFavorites(),
          ).thenAnswer((_) async => testFavorites);
          return favoriteBloc;
        },
        act: (bloc) => bloc.add(const FavoriteLoadEvent()),
        expect: () => [
          const FavoritesLoading(),
          FavoritesLoaded(testFavorites.values),
        ],
        verify: (_) {
          verify(mockRepository.getFavorites()).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'emits [FavoritesLoading, FavoritesLoaded] with empty list when repository returns null',
        build: () {
          when(mockRepository.getFavorites()).thenAnswer((_) async => null);
          return favoriteBloc;
        },
        act: (bloc) => bloc.add(const FavoriteLoadEvent()),
        expect: () => [const FavoritesLoading(), const FavoritesLoaded([])],
        verify: (_) {
          verify(mockRepository.getFavorites()).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'emits [FavoritesLoading, FavoritesLoaded] with empty list when repository throws exception',
        build: () {
          when(
            mockRepository.getFavorites(),
          ).thenThrow(Exception('Load failed'));
          return favoriteBloc;
        },
        act: (bloc) => bloc.add(const FavoriteLoadEvent()),
        expect: () => [const FavoritesLoading(), const FavoritesLoaded([])],
        verify: (_) {
          verify(mockRepository.getFavorites()).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'emits [FavoritesLoading, FavoritesLoaded] with empty list when repository returns empty map',
        build: () {
          when(
            mockRepository.getFavorites(),
          ).thenAnswer((_) async => <String, Favorite>{});
          return favoriteBloc;
        },
        act: (bloc) => bloc.add(const FavoriteLoadEvent()),
        expect: () => [const FavoritesLoading(), const FavoritesLoaded([])],
        verify: (_) {
          verify(mockRepository.getFavorites()).called(1);
        },
      );
    });

    group('FavoriteAddEvent', () {
      blocTest<FavoriteBloc, FavoritesState>(
        'adds favorite to existing list when state is FavoritesLoaded',
        build: () {
          when(
            mockRepository.addFavorite(testFavorite3),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) => bloc.add(const FavoriteAddEvent(testFavorite3)),
        expect: () => [
          const FavoritesLoaded([testFavorite1, testFavorite2, testFavorite3]),
        ],
        verify: (_) {
          verify(mockRepository.addFavorite(testFavorite3)).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'adds favorite to empty list when state is FavoritesLoaded with no favorites',
        build: () {
          when(
            mockRepository.addFavorite(testFavorite1),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([]),
        act: (bloc) => bloc.add(const FavoriteAddEvent(testFavorite1)),
        expect: () => [
          const FavoritesLoaded([testFavorite1]),
        ],
        verify: (_) {
          verify(mockRepository.addFavorite(testFavorite1)).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'does not emit state when bloc is not in FavoritesLoaded state',
        build: () => favoriteBloc,
        seed: () => const FavoritesLoading(),
        act: (bloc) => bloc.add(const FavoriteAddEvent(testFavorite1)),
        expect: () => [],
        verify: (_) {
          // Repository should not be called when state is not FavoritesLoaded
          verifyZeroInteractions(mockRepository);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'does not emit state when bloc is in FavoritesInitial state',
        build: () => favoriteBloc,
        act: (bloc) => bloc.add(const FavoriteAddEvent(testFavorite1)),
        expect: () => [],
        verify: (_) {
          // Repository should not be called when state is FavoritesInitial
          verifyZeroInteractions(mockRepository);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'still emits state even when repository call fails',
        build: () {
          when(
            mockRepository.addFavorite(testFavorite3),
          ).thenThrow(Exception('Add failed'));
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) => bloc.add(const FavoriteAddEvent(testFavorite3)),
        expect: () => [
          const FavoritesLoaded([testFavorite1, testFavorite2, testFavorite3]),
        ],
        verify: (_) {
          verify(mockRepository.addFavorite(testFavorite3)).called(1);
        },
      );
    });

    group('FavoriteRemoveEvent', () {
      blocTest<FavoriteBloc, FavoritesState>(
        'removes single favorite from list when state is FavoritesLoaded',
        build: () {
          when(
            mockRepository.removeFavorites([testFavorite1.uuid]),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) => bloc.add(const FavoriteRemoveEvent([testFavorite1])),
        expect: () => [
          const FavoritesLoaded([testFavorite2]),
        ],
        verify: (_) {
          verify(
            mockRepository.removeFavorites([testFavorite1.uuid]),
          ).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'removes multiple favorites from list when state is FavoritesLoaded',
        build: () {
          when(
            mockRepository.removeFavorites([
              testFavorite1.uuid,
              testFavorite2.uuid,
            ]),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([
          testFavorite1,
          testFavorite2,
          testFavorite3,
        ]),
        act: (bloc) =>
            bloc.add(const FavoriteRemoveEvent([testFavorite1, testFavorite2])),
        expect: () => [
          const FavoritesLoaded([testFavorite3]),
        ],
        verify: (_) {
          verify(
            mockRepository.removeFavorites([
              testFavorite1.uuid,
              testFavorite2.uuid,
            ]),
          ).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'removes all favorites from list when removing all',
        build: () {
          when(
            mockRepository.removeFavorites([
              testFavorite1.uuid,
              testFavorite2.uuid,
            ]),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) =>
            bloc.add(const FavoriteRemoveEvent([testFavorite1, testFavorite2])),
        expect: () => [const FavoritesLoaded([])],
        verify: (_) {
          verify(
            mockRepository.removeFavorites([
              testFavorite1.uuid,
              testFavorite2.uuid,
            ]),
          ).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'does not emit state when bloc is not in FavoritesLoaded state',
        build: () => favoriteBloc,
        seed: () => const FavoritesLoading(),
        act: (bloc) => bloc.add(const FavoriteRemoveEvent([testFavorite1])),
        expect: () => [],
        verify: (_) {
          // Repository should not be called when state is not FavoritesLoaded
          verifyZeroInteractions(mockRepository);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'handles empty removal list gracefully',
        build: () {
          when(
            mockRepository.removeFavorites([]),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) => bloc.add(const FavoriteRemoveEvent([])),
        expect: () => [], // No state change expected since removing empty list
        verify: (_) {
          verify(mockRepository.removeFavorites([])).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'handles removing non-existent favorites gracefully',
        build: () {
          when(
            mockRepository.removeFavorites([testFavorite3.uuid]),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) => bloc.add(const FavoriteRemoveEvent([testFavorite3])),
        expect: () =>
            [], // No state change expected since favorite doesn't exist
        verify: (_) {
          verify(
            mockRepository.removeFavorites([testFavorite3.uuid]),
          ).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'still emits state even when repository call fails',
        build: () {
          when(
            mockRepository.removeFavorites([testFavorite1.uuid]),
          ).thenThrow(Exception('Remove failed'));
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) => bloc.add(const FavoriteRemoveEvent([testFavorite1])),
        expect: () => [
          const FavoritesLoaded([testFavorite2]),
        ],
        verify: (_) {
          verify(
            mockRepository.removeFavorites([testFavorite1.uuid]),
          ).called(1);
        },
      );
    });

    group('State Transitions', () {
      blocTest<FavoriteBloc, FavoritesState>(
        'can transition from initial to loaded to adding favorites',
        build: () {
          when(
            mockRepository.getFavorites(),
          ).thenAnswer((_) async => <String, Favorite>{});
          when(
            mockRepository.addFavorite(testFavorite1),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        act: (bloc) async {
          bloc.add(const FavoriteLoadEvent());
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const FavoriteAddEvent(testFavorite1));
        },
        expect: () => [
          const FavoritesLoading(),
          const FavoritesLoaded([]),
          const FavoritesLoaded([testFavorite1]),
        ],
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'can transition from loaded to adding then removing favorites',
        build: () {
          when(
            mockRepository.addFavorite(testFavorite3),
          ).thenAnswer((_) async => true);
          when(
            mockRepository.removeFavorites([testFavorite1.uuid]),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) async {
          bloc.add(const FavoriteAddEvent(testFavorite3));
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const FavoriteRemoveEvent([testFavorite1]));
        },
        expect: () => [
          const FavoritesLoaded([testFavorite1, testFavorite2, testFavorite3]),
          const FavoritesLoaded([testFavorite2, testFavorite3]),
        ],
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'can handle rapid successive add/remove operations',
        build: () {
          when(
            mockRepository.addFavorite(testFavorite3),
          ).thenAnswer((_) async => true);
          when(
            mockRepository.removeFavorites([testFavorite3.uuid]),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) {
          bloc.add(const FavoriteAddEvent(testFavorite3));
          bloc.add(const FavoriteRemoveEvent([testFavorite3]));
        },
        expect: () => [
          const FavoritesLoaded([testFavorite1, testFavorite2, testFavorite3]),
          const FavoritesLoaded([testFavorite1, testFavorite2]),
        ],
      );
    });

    group('Edge Cases', () {
      test('bloc can be closed without issues', () async {
        expect(() => favoriteBloc.close(), returnsNormally);
      });

      blocTest<FavoriteBloc, FavoritesState>(
        'handles duplicate favorites in add operations',
        build: () {
          when(
            mockRepository.addFavorite(testFavorite1),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) => bloc.add(const FavoriteAddEvent(testFavorite1)),
        expect: () => [
          const FavoritesLoaded([testFavorite1, testFavorite2, testFavorite1]),
        ],
        verify: (_) {
          verify(mockRepository.addFavorite(testFavorite1)).called(1);
        },
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'handles clearing all favorites and reloading',
        build: () {
          when(
            mockRepository.getFavorites(),
          ).thenAnswer((_) async => testFavorites);
          return favoriteBloc;
        },
        seed: () => const FavoritesLoaded([testFavorite1, testFavorite2]),
        act: (bloc) async {
          bloc.clearAll();
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const FavoriteLoadEvent());
        },
        expect: () => [
          const FavoritesInitial(),
          const FavoritesLoading(),
          FavoritesLoaded(testFavorites.values),
        ],
      );
    });

    group('Repository Error Handling', () {
      blocTest<FavoriteBloc, FavoritesState>(
        'handles repository getFavorites timeout gracefully',
        build: () {
          when(
            mockRepository.getFavorites(),
          ).thenThrow(TimeoutException('Request timeout'));
          return favoriteBloc;
        },
        act: (bloc) => bloc.add(const FavoriteLoadEvent()),
        expect: () => [const FavoritesLoading(), const FavoritesLoaded([])],
      );

      blocTest<FavoriteBloc, FavoritesState>(
        'continues to work after repository errors',
        build: () {
          when(
            mockRepository.getFavorites(),
          ).thenThrow(Exception('First call fails'));
          when(
            mockRepository.addFavorite(testFavorite1),
          ).thenAnswer((_) async => true);
          return favoriteBloc;
        },
        act: (bloc) async {
          bloc.add(const FavoriteLoadEvent());
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const FavoriteAddEvent(testFavorite1));
        },
        expect: () => [
          const FavoritesLoading(),
          const FavoritesLoaded([]),
          const FavoritesLoaded([testFavorite1]),
        ],
      );
    });
  });
}
