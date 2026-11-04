import 'dart:async';
import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/repository/profile_folder_repository.dart';
import 'package:npt_flutter/util/constants.dart';

import '../../profile/repository/profile_repository_test.mocks.dart';

/// A sync service that keeps the listeners added to it, so a test can send
/// them sync progress.
class FakeSyncService extends Fake implements SyncService {
  final List<SyncProgressListener> listeners = <SyncProgressListener>[];
  int syncCalls = 0;

  @override
  void addProgressListener(SyncProgressListener listener) =>
      listeners.add(listener);

  @override
  void removeProgressListener(SyncProgressListener listener) =>
      listeners.remove(listener);

  @override
  void sync({Function? onDone, Function? onError}) => syncCalls++;

  void send(SyncProgress progress) {
    for (final SyncProgressListener listener in List.of(listeners)) {
      listener.onSyncProgressEvent(progress);
    }
  }
}

SyncProgress syncProgress(
  SyncStatus status, {
  int? local,
  int? server,
  int? pending,
}) => SyncProgress()
  ..syncStatus = status
  ..localCommitId = local
  ..serverCommitId = server
  ..pendingPushCount = pending;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileFolderRepository', () {
    late ProfileFolderRepository repository;
    late MockAtClient mockAtClient;

    const String testAtsign = '@test_user';
    const ProfileFolderData testData = ProfileFolderData(
      folders: <ProfileFolder>[
        ProfileFolder(uuid: 'g1', name: 'One', profileIds: <String>['a', 'b']),
      ],
    );

    setUp(() {
      mockAtClient = MockAtClient();
      repository = ProfileFolderRepository(atClient: mockAtClient);
      when(mockAtClient.getCurrentAtSign()).thenReturn(testAtsign);
    });

    AtKey expectedKey() =>
        ProfileFolderRepository.getProfileFolderAtKey(sharedBy: testAtsign);

    test('builds a self key in the noports namespace', () {
      final AtKey key = ProfileFolderRepository.getProfileFolderAtKey();
      expect(key.key, 'folders');
      expect(key.namespace, Constants.namespace);
      expect(key.sharedBy, '');

      final AtKey shared = expectedKey();
      expect(shared.sharedBy, testAtsign);
    });

    group('getProfileFolders', () {
      test('parses stored json', () async {
        final AtValue value = AtValue()..value = jsonEncode(testData.toJson());
        when(mockAtClient.get(expectedKey())).thenAnswer((_) async => value);

        final ProfileFolderData? result = await repository.getProfileFolders();

        expect(result, equals(testData));
      });

      test('returns empty data when the value is null', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenAnswer((_) async => AtValue());

        final ProfileFolderData? result = await repository.getProfileFolders();

        expect(result, equals(const ProfileFolderData()));
      });

      test('returns empty data when the key does not exist yet', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenThrow(AtKeyNotFoundException('missing'));

        final ProfileFolderData? result = await repository.getProfileFolders();

        expect(result, equals(const ProfileFolderData()));
      });

      test('returns null when the value is not a map', () async {
        final AtValue value = AtValue()..value = jsonEncode(<int>[1, 2, 3]);
        when(mockAtClient.get(expectedKey())).thenAnswer((_) async => value);

        expect(await repository.getProfileFolders(), isNull);
      });

      test('returns null on other failures', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenThrow(Exception('network down'));

        expect(await repository.getProfileFolders(), isNull);
      });

      testWidgets('returns null when the client has not answered after 30 '
          'seconds', (WidgetTester tester) async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenAnswer((_) => Completer<AtValue>().future);
        bool done = false;
        ProfileFolderData? result = testData;
        unawaited(
          repository.getProfileFolders().then((ProfileFolderData? value) {
            done = true;
            result = value;
          }),
        );

        await tester.pump(const Duration(seconds: 29));
        expect(done, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(done, isTrue);
        expect(result, isNull);
      });

      testWidgets('still returns a value that arrives just inside 30 seconds', (
        WidgetTester tester,
      ) async {
        final AtValue value = AtValue()..value = jsonEncode(testData.toJson());
        when(mockAtClient.get(expectedKey())).thenAnswer(
          (_) =>
              Future<AtValue>.delayed(const Duration(seconds: 29), () => value),
        );
        ProfileFolderData? result;
        unawaited(
          repository.getProfileFolders().then((ProfileFolderData? v) {
            result = v;
          }),
        );

        await tester.pump(const Duration(seconds: 29));
        await tester.pump();

        expect(result, equals(testData));
      });
    });

    group('putProfileFolders', () {
      test('writes the encoded json and returns the client result', () async {
        when(
          mockAtClient.put(expectedKey(), jsonEncode(testData.toJson())),
        ).thenAnswer((_) async => true);

        expect(await repository.putProfileFolders(testData), isTrue);
        verify(
          mockAtClient.put(expectedKey(), jsonEncode(testData.toJson())),
        ).called(1);
      });

      test('returns false when the client throws', () async {
        when(mockAtClient.put(any, any)).thenThrow(Exception('write failed'));

        expect(await repository.putProfileFolders(testData), isFalse);
      });

      testWidgets('returns false when the client has not answered after 30 '
          'seconds', (WidgetTester tester) async {
        when(
          mockAtClient.put(any, any),
        ).thenAnswer((_) => Completer<bool>().future);
        bool? result;
        unawaited(
          repository.putProfileFolders(testData).then((bool v) => result = v),
        );

        await tester.pump(const Duration(seconds: 29));
        expect(result, isNull);

        await tester.pump(const Duration(seconds: 1));
        expect(result, isFalse);
      });
    });

    group('waitForSync', () {
      test('is false when the sync service throws', () async {
        when(mockAtClient.syncService).thenThrow(StateError('no client'));

        expect(await repository.waitForSync(), isFalse);
      });

      test('is true once a round finds nothing left to pull', () async {
        final FakeSyncService sync = FakeSyncService();
        when(mockAtClient.syncService).thenReturn(sync);

        final Future<bool> result = repository.waitForSync();
        sync.send(syncProgress(SyncStatus.success));

        expect(await result, isTrue);
        expect(sync.syncCalls, 1);
      });

      testWidgets('is false when the local copy has not caught up by the '
          'timeout', (WidgetTester tester) async {
        final FakeSyncService sync = FakeSyncService();
        when(mockAtClient.syncService).thenReturn(sync);
        bool? result;
        unawaited(
          repository
              .waitForSync(timeout: const Duration(seconds: 10))
              .then((bool v) => result = v),
        );

        sync.send(syncProgress(SyncStatus.success, local: 3, server: 8));
        await tester.pump(const Duration(seconds: 9));
        expect(result, isNull);

        await tester.pump(const Duration(seconds: 1));
        expect(result, isFalse);
      });
    });

    group('watchSync', () {
      late FakeSyncService sync;
      late List<bool> rounds;

      setUp(() {
        sync = FakeSyncService();
        when(mockAtClient.syncService).thenReturn(sync);
        rounds = <bool>[];
        repository.watchSync(rounds.add);
      });

      test('a successful round that pulled up to the server is caught up', () {
        sync.send(syncProgress(SyncStatus.success, local: 8, server: 8));
        sync.send(syncProgress(SyncStatus.success, local: 9, server: 8));

        expect(rounds, <bool>[true, true]);
      });

      test(
        'pushes still waiting do not stop a round counting as caught up',
        () {
          sync.send(
            syncProgress(SyncStatus.success, local: 8, server: 8, pending: 3),
          );

          expect(rounds, <bool>[true]);
        },
      );

      test('a round with nothing to pull is caught up', () {
        sync.send(syncProgress(SyncStatus.success));

        expect(rounds, <bool>[true]);
      });

      test('a successful round that stopped short of the server is not '
          'caught up', () {
        sync.send(syncProgress(SyncStatus.success, local: 7, server: 8));

        expect(rounds, <bool>[false]);
      });

      test('a successful round that reports no local commit but a server '
          'one is not caught up', () {
        sync.send(syncProgress(SyncStatus.success, server: 8));

        expect(rounds, <bool>[false]);
      });

      test('a failed round is reported as not caught up, even if it reached '
          'the server commit', () {
        sync.send(syncProgress(SyncStatus.failure, local: 8, server: 8));
        sync.send(syncProgress(SyncStatus.failure));

        expect(rounds, <bool>[false, false]);
      });

      test('rounds still in progress, or not finished, report nothing', () {
        sync.send(syncProgress(SyncStatus.inProgress, local: 8, server: 8));
        sync.send(syncProgress(SyncStatus.started, local: 8, server: 8));
        sync.send(syncProgress(SyncStatus.notStarted, local: 8, server: 8));
        sync.send(SyncProgress());

        expect(rounds, isEmpty);
      });

      test('stopWatching removes the listener and reports nothing more', () {
        expect(sync.listeners, hasLength(1));

        repository.stopWatching();
        sync.send(syncProgress(SyncStatus.success, local: 8, server: 8));

        expect(sync.listeners, isEmpty);
        expect(rounds, isEmpty);
      });

      test('stopWatching removes the listener from the service it was added '
          'to', () {
        final FakeSyncService other = FakeSyncService();
        when(mockAtClient.syncService).thenReturn(other);

        repository.stopWatching();

        expect(sync.listeners, isEmpty);
        expect(other.listeners, isEmpty);
      });

      test('watching again replaces the earlier callback', () {
        final List<bool> later = <bool>[];

        repository.watchSync(later.add);
        sync.send(syncProgress(SyncStatus.success, local: 8, server: 8));

        expect(sync.listeners, hasLength(1));
        expect(rounds, isEmpty);
        expect(later, <bool>[true]);
      });

      test('a sync service that throws is skipped, not rethrown', () {
        when(mockAtClient.syncService).thenThrow(StateError('no client'));

        expect(() => repository.watchSync(rounds.add), returnsNormally);
        expect(sync.listeners, isEmpty);
        expect(() => repository.stopWatching(), returnsNormally);
      });
    });
  });
}
