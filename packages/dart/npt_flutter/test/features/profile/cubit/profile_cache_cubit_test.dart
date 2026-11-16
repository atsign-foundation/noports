import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile/profile.dart';

import '../bloc/profile_bloc_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Given a profile cache holding a bloc', () {
    test('when the bloc is removed, then it is closed and no longer '
        'cached', () async {
      final cache = ProfileCacheCubit(MockProfileRepository());
      addTearDown(cache.close);
      final bloc = cache.getProfileBloc('profile-uuid');
      addTearDown(bloc.close);

      cache.remove('profile-uuid');

      expect(
        cache.state.profileBlocs.keys,
        isNot(contains('profile-uuid')),
        reason: 'a removed bloc must not be handed out again',
      );
      final closed = await bloc.stream
          .drain<void>()
          .then((_) => true)
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      expect(closed, isTrue, reason: 'remove must close the bloc it drops');
    });

    test('when the cache is cleared, then the bloc is closed', () async {
      final repository = MockProfileRepository();
      final cache = ProfileCacheCubit(repository);
      addTearDown(cache.close);
      final bloc = cache.getProfileBloc('profile-uuid');
      addTearDown(bloc.close);
      expect(bloc.isClosed, isFalse);

      cache.clear();

      expect(
        cache.state.profileBlocs,
        isEmpty,
        reason: 'the test must observe the cache after it was cleared',
      );
      final closed = await bloc.stream
          .drain<void>()
          .then((_) => true)
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      expect(
        closed,
        isTrue,
        reason:
            'clear must close the blocs it drops: once dropped, a bloc is no '
            'longer reachable through the cache',
      );
    });
  });
}
