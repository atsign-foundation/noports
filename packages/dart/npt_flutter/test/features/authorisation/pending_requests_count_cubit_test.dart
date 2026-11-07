import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/authorisation/cubit/pending_requests_count_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  blocTest<PendingRequestsCountCubit, Count>(
    'setCount shows the count a read of the pending requests found',
    build: PendingRequestsCountCubit.new,
    act: (PendingRequestsCountCubit cubit) => cubit
      ..setCount(2)
      ..setCount(0),
    expect: () => <Count>[const Count(2), const Count(0)],
  );

  test('setCount after close is ignored rather than throwing', () async {
    final PendingRequestsCountCubit cubit = PendingRequestsCountCubit();
    await cubit.close();

    expect(() => cubit.setCount(1), returnsNormally);
  });
}
