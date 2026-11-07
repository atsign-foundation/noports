import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';

import 'authorisation_hub_controller_test.mocks.dart';

Enrollment _request(String id) => Enrollment()
  ..enrollmentId = id
  ..status = EnrollmentStatus.pending.name;

@GenerateNiceMocks(<MockSpec<Object>>[
  MockSpec<AtClient>(),
  MockSpec<Enrollments>(),
  MockSpec<KeychainStorage>(),
])
void main() {
  late MockAtClient client;
  late MockEnrollments enrollments;
  late StreamController<Enrollment> requests;
  late List<int> counts;
  late AuthorisationHubController controller;

  setUp(() {
    client = MockAtClient();
    enrollments = MockEnrollments();
    requests = StreamController<Enrollment>.broadcast();
    counts = <int>[];
    when(client.getCurrentAtSign()).thenReturn('@alice');
    when(enrollments.requests).thenAnswer((_) => requests.stream);
    when(enrollments.pending()).thenAnswer((_) async => <Enrollment>[]);
    controller = AuthorisationHubController(
      client: client,
      enrollments: enrollments,
      keychain: MockKeychainStorage(),
      onPendingCount: counts.add,
    );
  });

  tearDown(() async {
    controller.dispose();
    await requests.close();
  });

  test('a new-request event shows only what the Atsign Server holds as '
      'pending', () async {
    await controller.init();

    requests.add(_request('decided-elsewhere'));
    await pumpEventQueue();

    expect(controller.pending, isEmpty);
  });

  test('a refused approval reads the list again, dropping a request decided '
      'elsewhere', () async {
    final Enrollment stale = _request('decided-elsewhere');
    final List<List<Enrollment>> answers = <List<Enrollment>>[
      <Enrollment>[stale],
      <Enrollment>[],
    ];
    when(enrollments.pending()).thenAnswer((_) async => answers.removeAt(0));
    when(
      enrollments.approve(any),
    ).thenThrow(Exception('Cannot approve a approved enrollment'));

    await controller.loadPendingRequests();
    expect(controller.pending, hasLength(1));

    final String? error = await controller.approveRequest(stale);
    await pumpEventQueue();

    expect(error, isNotNull);
    expect(controller.pending, isEmpty);
  });

  test('loads asked for during a load fold into one later read, so the '
      'newest answer stands', () async {
    final Completer<List<Enrollment>> first = Completer<List<Enrollment>>();
    final Completer<List<Enrollment>> second = Completer<List<Enrollment>>();
    final List<Future<List<Enrollment>>> answers = <Future<List<Enrollment>>>[
      first.future,
      second.future,
    ];
    when(enrollments.pending()).thenAnswer((_) => answers.removeAt(0));

    final Future<void> a = controller.loadPendingRequests();
    final Future<void> b = controller.loadPendingRequests();
    final Future<void> c = controller.loadPendingRequests();
    // The newer answer arrives before the older one.
    second.complete(<Enrollment>[]);
    first.complete(<Enrollment>[_request('since-decided')]);
    await Future.wait(<Future<void>>[a, b, c]);

    expect(controller.pending, isEmpty);
    verify(enrollments.pending()).called(2);
  });

  test(
    'each read tells onPendingCount how many requests await a decision',
    () async {
      final List<List<Enrollment>> answers = <List<Enrollment>>[
        <Enrollment>[_request('a'), _request('b')],
        <Enrollment>[],
      ];
      when(enrollments.pending()).thenAnswer((_) async => answers.removeAt(0));

      await controller.loadPendingRequests();
      await controller.loadPendingRequests();

      expect(counts, <int>[2, 0]);
    },
  );

  test('Given a request on the list, when a read of the pending requests '
      'fails, then the list and its count keep the request and the error is '
      'reported', () async {
    final List<Future<List<Enrollment>> Function()> answers =
        <Future<List<Enrollment>> Function()>[
          () async => <Enrollment>[_request('kept')],
          () async => throw Exception('connection dropped'),
        ];
    when(enrollments.pending()).thenAnswer((_) => answers.removeAt(0)());

    await controller.loadPendingRequests();
    await controller.loadPendingRequests();

    expect(controller.pending.map((Enrollment e) => e.enrollmentId), <String?>[
      'kept',
    ]);
    expect(controller.pendingError, contains('connection dropped'));
    expect(counts, <int>[1]);
  });
}
