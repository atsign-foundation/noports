import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/authorisation/cubit/pending_requests_count_cubit.dart';

import 'authorisation_hub_controller_test.mocks.dart';
import 'window_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  blocTest<PendingRequestsCountCubit, Count>(
    'Given reads that found 2 and then 0 pending requests, when each count is '
    'set, then the badge shows 2 and then 0',
    build: PendingRequestsCountCubit.new,
    act: (PendingRequestsCountCubit cubit) => cubit
      ..setCount(2)
      ..setCount(0),
    expect: () => <Count>[const Count(2), const Count(0)],
  );

  test(
    'Given a closed badge, when a count is set, then nothing is thrown',
    () async {
      final PendingRequestsCountCubit cubit = PendingRequestsCountCubit();
      await cubit.close();

      expect(() => cubit.setCount(1), returnsNormally);
    },
  );

  test('Given a started badge, when the window regains focus, then the '
      'pending requests are read again', () async {
    final MockEnrollments enrollments = MockEnrollments();
    final List<List<Enrollment>> answers = <List<Enrollment>>[
      <Enrollment>[Enrollment()..enrollmentId = 'decided-elsewhere'],
      <Enrollment>[],
    ];
    when(
      enrollments.requests,
    ).thenAnswer((_) => const Stream<Enrollment>.empty());
    when(enrollments.pending()).thenAnswer((_) async => answers.removeAt(0));
    final PendingRequestsCountCubit cubit = PendingRequestsCountCubit(
      enrollments: () => enrollments,
    );
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();
    expect(cubit.state, const Count(1));

    await sendWindowEvent('focus');
    await pumpEventQueue();

    expect(cubit.state, const Count(0));
  });
}
