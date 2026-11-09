import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/authorisation/cubit/pending_requests_count_cubit.dart';
import 'package:npt_flutter/features/authorisation/view/authorisation_view.dart';

import 'authorisation_hub_controller_test.mocks.dart';
import 'window_events.dart';

void main() {
  testWidgets('Given the Authenticator showing a request decided elsewhere, '
      'when the window regains focus, then the list and the badge drop it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final MockAtClient client = MockAtClient();
    final MockEnrollments enrollments = MockEnrollments();
    final List<List<Enrollment>> answers = <List<Enrollment>>[
      <Enrollment>[
        Enrollment()
          ..enrollmentId = 'decided-elsewhere'
          ..appName = 'repro2919'
          ..deviceName = 'linux'
          ..status = EnrollmentStatus.pending.name,
      ],
      <Enrollment>[],
    ];
    when(client.getCurrentAtSign()).thenReturn('@alice');
    when(
      enrollments.requests,
    ).thenAnswer((_) => const Stream<Enrollment>.empty());
    when(enrollments.pending()).thenAnswer((_) async => answers.removeAt(0));
    when(enrollments.otp()).thenAnswer((_) async => Passcode('ABC123', null));
    // Not started, so only the hub's reads can change the badge.
    final PendingRequestsCountCubit badge = PendingRequestsCountCubit(
      enrollments: () => enrollments,
    );
    addTearDown(badge.close);

    await tester.pumpWidget(
      MaterialApp(
        // NOTE: the test font draws every glyph a full em wide, which
        // overflows the sidebar's fixed 340px; half-size text keeps the real
        // layout without the overflow.
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
        home: Scaffold(
          body: BlocProvider<PendingRequestsCountCubit>.value(
            value: badge,
            child: AuthorisationHub(
              client: client,
              enrollments: enrollments,
              keychain: MockKeychainStorage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('repro2919', findRichText: true), findsWidgets);
    expect(badge.state, const Count(1));

    await sendWindowEvent('focus');
    await tester.pumpAndSettle();

    expect(find.textContaining('repro2919', findRichText: true), findsNothing);
    expect(badge.state, const Count(0));
  });
}
