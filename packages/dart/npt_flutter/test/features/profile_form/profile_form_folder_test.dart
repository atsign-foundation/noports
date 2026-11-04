import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';

class FakeProfileRepository extends ProfileRepository {
  final List<Profile> puts = <Profile>[];
  bool saveSucceeds = true;

  /// Holds each save until the test completes it, when set.
  Completer<void>? saveGate;

  @override
  Future<Profile?> getProfile(String uuid, {bool useCache = true}) async =>
      Profile(
        uuid,
        displayName: 'Connection',
        sshnpdAtsign: '@device'.toAtsign(),
        relayAtsign: '@rv_am'.toAtsign(),
        deviceName: 'device',
        remotePort: 22,
        localPort: 2222,
      );

  @override
  Future<bool> putProfile(Profile profile) async {
    puts.add(profile);
    await saveGate?.future;
    return saveSucceeds;
  }
}

class FakeProfileFolderRepository extends ProfileFolderRepository {
  ProfileFolderData stored = const ProfileFolderData();
  final List<ProfileFolderData> puts = <ProfileFolderData>[];

  /// Completes when the test says the local copy has caught up.
  final Completer<bool> caughtUp = Completer<bool>();

  @override
  Future<ProfileFolderData?> getProfileFolders() async => stored;

  @override
  Future<bool> putProfileFolders(ProfileFolderData data) async {
    puts.add(data);
    stored = data;
    return true;
  }

  @override
  Future<bool> waitForSync({Duration timeout = const Duration(seconds: 30)}) =>
      caughtUp.future;

  @override
  void watchSync(void Function(bool caughtUp) onRound) {}

  @override
  void stopWatching() {}
}

class RecordingProfileFolderBloc extends ProfileFolderBloc {
  final List<ProfileFolderEvent> events = <ProfileFolderEvent>[];

  RecordingProfileFolderBloc(super.repo);

  @override
  void onEvent(ProfileFolderEvent event) {
    events.add(event);
    super.onEvent(event);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AppLocalizations strings = AppLocalizationsEn();

  const String uuid = 'p1';
  const ProfileFolder servers = ProfileFolder(
    uuid: 'g-servers',
    name: 'Servers',
    profileIds: <String>['s1'],
  );
  const ProfileFolder desktops = ProfileFolder(
    uuid: 'g-desktops',
    name: 'Desktops',
    profileIds: <String>['d1'],
  );
  const ProfileFolderData otherFolders = ProfileFolderData(
    folders: <ProfileFolder>[servers, desktops],
  );

  late FakeProfileRepository profileRepo;
  late FakeProfileFolderRepository folderRepo;
  late RecordingProfileFolderBloc folderBloc;
  late ProfileListBloc listBloc;
  late ProfileCacheCubit cache;
  late ProfilesRunningCubit running;

  Finder folderField() => find.descendant(
    of: find.byType(ProfileFolderSelector),
    matching: find.byType(TextField),
  );
  Finder menuEntry(String label) => find.widgetWithText(MenuItemButton, label);
  Finder submitButton() => find.widgetWithText(ElevatedButton, strings.submit);

  List<String> menuLabels() => find
      .descendant(of: find.byType(MenuItemButton), matching: find.byType(Text))
      .evaluate()
      .map((Element e) => (e.widget as Text).data!)
      .toList();

  ProfileFormFolderCubit formFolder(WidgetTester tester) => tester
      .element(find.byType(ProfileFolderSelector))
      .read<ProfileFormFolderCubit>();

  ProfileBloc savedBloc() => cache.getProfileBloc(uuid);

  /// The real blocs are created in the test body so that their streams run in
  /// the FakeAsync zone driven by [WidgetTester.pump].
  Future<void> pumpForm(
    WidgetTester tester, {
    ProfileFolderData folders = otherFolders,
    bool loadFolders = true,
    bool synced = true,
    String? folderId,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The test font is wider than the real one, so the device row overflows.
    final void Function(FlutterErrorDetails)? onError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('RenderFlex overflowed')) {
        return;
      }
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);

    profileRepo = FakeProfileRepository();
    folderRepo = FakeProfileFolderRepository()..stored = folders;
    folderBloc = RecordingProfileFolderBloc(folderRepo);
    listBloc = ProfileListBloc(profileRepo);
    cache = ProfileCacheCubit(profileRepo);
    running = ProfilesRunningCubit();
    addTearDown(() async {
      await savedBloc().close();
      await cache.close();
      await folderBloc.close();
      await listBloc.close();
      await running.close();
    });

    listBloc.add(
      const ProfileListUpdateEvent(<String>[uuid, 's1', 'd1', 'u1']),
    );
    if (loadFolders) {
      folderBloc.add(const ProfileFolderLoadEvent());
      await tester.pump();
      if (synced) {
        folderRepo.caughtUp.complete(true);
        await tester.pump();
      }
      expect(folderBloc.state.editable, synced);
    }
    folderBloc.events.clear();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<EnableLoggingCubit>(
            create: (_) => EnableLoggingCubit()..disable(),
          ),
          BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
          BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
          BlocProvider<ProfileListBloc>.value(value: listBloc),
          BlocProvider<ProfileCacheCubit>.value(value: cache),
          BlocProvider<ProfilesRunningCubit>.value(value: running),
        ],
        child: RepositoryProvider<ProfileRepository>.value(
          value: profileRepo,
          child: MaterialApp(
            navigatorKey: App.navState,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileFormView(uuid, folderId: folderId)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(folderField());
    await tester.pumpAndSettle();
  }

  Future<void> typeInField(WidgetTester tester, String text) async {
    await tester.enterText(folderField(), text);
    await tester.pumpAndSettle();
  }

  Future<void> pickEntry(WidgetTester tester, String label) async {
    await tester.tap(menuEntry(label));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(submitButton());
    await tester.pump();
    await tester.tap(submitButton());
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  List<ProfileFolderEvent> folderEvents() => folderBloc.events
      .where(
        (ProfileFolderEvent e) =>
            e is! ProfileFolderLoadEvent && e is! ProfileFolderRefreshEvent,
      )
      .toList();

  ProfileFolderData currentData() =>
      (folderBloc.state as ProfileFoldersLoaded).data;

  group('Folder field entries', () {
    testWidgets('lists No folder, New folder and then every folder', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);

      expect(menuLabels(), <String>[
        strings.folderNone,
        strings.folderNew,
        'Servers',
        'Desktops',
      ]);
    });

    testWidgets('shows No folder for a connection that is in no folder', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);

      expect(
        tester.widget<TextField>(folderField()).controller!.text,
        strings.folderNone,
      );
    });

    testWidgets('starts on the folder the connection is already in', (
      WidgetTester tester,
    ) async {
      await pumpForm(
        tester,
        folders: const ProfileFolderData(
          folders: <ProfileFolder>[
            servers,
            ProfileFolder(
              uuid: 'g-desktops',
              name: 'Desktops',
              profileIds: <String>[uuid],
            ),
          ],
        ),
      );

      expect(
        tester.widget<TextField>(folderField()).controller!.text,
        'Desktops',
      );
      expect(formFolder(tester).state.folderId, 'g-desktops');
    });

    testWidgets('starts on the folder it was opened from', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, folderId: 'g-servers');

      expect(
        tester.widget<TextField>(folderField()).controller!.text,
        'Servers',
      );
      expect(formFolder(tester).state.folderId, 'g-servers');
    });

    testWidgets('is not shown until the folders have loaded', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, loadFolders: false);

      expect(folderField(), findsNothing);
      expect(find.text(strings.profileFolder), findsNothing);
    });
  });

  group('Typing in the Folder field', () {
    testWidgets('offers to create a name that no folder has', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'Databases');

      expect(menuLabels(), <String>['${strings.folderNew}: Databases']);
    });

    testWidgets('offers the typed name without surrounding spaces', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, '  Databases  ');

      expect(menuLabels(), <String>['${strings.folderNew}: Databases']);
    });

    testWidgets('caps the offered name at the longest name a folder can have', (
      WidgetTester tester,
    ) async {
      final String tooLong = 'x' * (ProfileFolderNameDialog.maxLength + 6);
      final String capped = 'x' * ProfileFolderNameDialog.maxLength;
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, tooLong);

      expect(menuLabels(), <String>['${strings.folderNew}: $capped']);

      await pickEntry(tester, '${strings.folderNew}: $capped');

      expect(formFolder(tester).state.newName, capped);
    });

    testWidgets('keeps a name of exactly the longest length as typed', (
      WidgetTester tester,
    ) async {
      final String exact = 'y' * ProfileFolderNameDialog.maxLength;
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, exact);

      expect(menuLabels(), <String>['${strings.folderNew}: $exact']);
    });

    for (final String typed in <String>['Servers', 'servers', 'SERVERS']) {
      testWidgets('does not offer to create "$typed" when Servers exists', (
        WidgetTester tester,
      ) async {
        await pumpForm(tester);
        await openMenu(tester);
        await typeInField(tester, typed);

        expect(menuLabels(), <String>['Servers']);
      });
    }

    testWidgets('lists the folders that match before the offer to create', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'desk');

      expect(menuLabels(), <String>['Desktops', '${strings.folderNew}: desk']);
    });

    testWidgets('choosing the offered name selects it as a new folder', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'Databases');
      await pickEntry(tester, '${strings.folderNew}: Databases');

      final ProfileFormFolder chosen = formFolder(tester).state;
      expect(chosen.newName, 'Databases');
      expect(chosen.folderId, isNotNull);
      expect(chosen.folderId, isNot(anyOf('g-servers', 'g-desktops')));
      expect(
        tester.widget<TextField>(folderField()).controller!.text,
        'Databases',
      );
    });

    testWidgets('choosing an existing folder selects it without creating', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await pickEntry(tester, 'Servers');

      final ProfileFormFolder chosen = formFolder(tester).state;
      expect(chosen.folderId, 'g-servers');
      expect(chosen.newName, isNull);
    });
  });

  group('New folder dialog from the Folder field', () {
    testWidgets('asks for a name and selects it as a new folder', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await pickEntry(tester, strings.folderNew);

      expect(find.byType(ProfileFolderNameDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ProfileFolderNameDialog-TextFormField')),
        'Databases',
      );
      await tester.tap(find.text(strings.save));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileFolderNameDialog), findsNothing);
      expect(formFolder(tester).state.newName, 'Databases');
      expect(formFolder(tester).state.folderId, isNotNull);
    });

    testWidgets('refuses the name of an existing folder in any case', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await pickEntry(tester, strings.folderNew);
      await tester.enterText(
        find.byKey(const Key('ProfileFolderNameDialog-TextFormField')),
        'sErVeRs',
      );
      await tester.tap(find.text(strings.save));
      await tester.pumpAndSettle();

      expect(find.text(strings.folderNameTaken), findsOneWidget);
      expect(find.byType(ProfileFolderNameDialog), findsOneWidget);
      expect(formFolder(tester).state.newName, isNull);
    });

    testWidgets('keeps the previous choice when the dialog is cancelled', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, folderId: 'g-servers');
      await openMenu(tester);
      await pickEntry(tester, strings.folderNew);
      await tester.tap(find.text(strings.cancel));
      await tester.pumpAndSettle();

      expect(formFolder(tester).state.folderId, 'g-servers');
      expect(formFolder(tester).state.newName, isNull);
      expect(
        tester.widget<TextField>(folderField()).controller!.text,
        'Servers',
      );
    });
  });

  group('Submit applies the folder after the save', () {
    testWidgets('creates the new folder only once the save has succeeded', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'Databases');
      await pickEntry(tester, '${strings.folderNew}: Databases');
      final String newId = formFolder(tester).state.folderId!;

      profileRepo.saveGate = Completer<void>();
      await submit(tester);
      await settle(tester);

      expect(profileRepo.puts, hasLength(1));
      expect(folderEvents(), isEmpty);
      expect(currentData().folderById(newId), isNull);

      profileRepo.saveGate!.complete();
      await settle(tester);

      expect(folderEvents(), <ProfileFolderEvent>[
        ProfileFolderCreateEvent(
          uuid: newId,
          name: 'Databases',
          profileIds: const <String>[uuid],
        ),
      ]);
      final ProfileFolder created = currentData().folderById(newId)!;
      expect(created.name, 'Databases');
      expect(created.profileIds, <String>[uuid]);
      expect(folderRepo.puts, hasLength(1));
    });

    testWidgets('moves the connection into the chosen folder after the save', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await pickEntry(tester, 'Servers');

      profileRepo.saveGate = Completer<void>();
      await submit(tester);
      await settle(tester);

      expect(folderEvents(), isEmpty);
      expect(currentData().folderForProfile(uuid), isNull);

      profileRepo.saveGate!.complete();
      await settle(tester);

      expect(folderEvents(), <ProfileFolderEvent>[
        const ProfileFolderMoveProfilesEvent(
          profileIds: <String>[uuid],
          folderId: 'g-servers',
        ),
      ]);
      expect(currentData().folderForProfile(uuid)?.uuid, 'g-servers');
      expect(currentData().folderById('g-servers')!.profileIds, <String>[
        's1',
        uuid,
      ]);
    });

    testWidgets('takes the connection out of its folder when No folder is '
        'chosen', (WidgetTester tester) async {
      await pumpForm(
        tester,
        folders: const ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'g-servers',
              name: 'Servers',
              profileIds: <String>['s1', uuid],
            ),
            desktops,
          ],
          unfiled: <String>['u1'],
        ),
      );
      await openMenu(tester);
      await pickEntry(tester, strings.folderNone);

      await submit(tester);
      await settle(tester);

      expect(currentData().folderForProfile(uuid), isNull);
      expect(currentData().folderById('g-servers')!.profileIds, <String>['s1']);
      expect(currentData().unfiled, <String>['u1', uuid]);
    });

    testWidgets('files a connection opened from a folder into that folder', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, folderId: 'g-servers');

      await submit(tester);
      await settle(tester);

      expect(folderEvents(), <ProfileFolderEvent>[
        const ProfileFolderMoveProfilesEvent(
          profileIds: <String>[uuid],
          folderId: 'g-servers',
        ),
      ]);
      expect(currentData().folderForProfile(uuid)?.uuid, 'g-servers');
    });

    testWidgets('sends no folder event when the folder was not changed', (
      WidgetTester tester,
    ) async {
      await pumpForm(
        tester,
        folders: const ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'g-servers',
              name: 'Servers',
              profileIds: <String>['s1', uuid],
            ),
            desktops,
          ],
        ),
      );

      await submit(tester);
      await settle(tester);

      expect(profileRepo.puts, hasLength(1));
      expect(folderEvents(), isEmpty);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('saves the connection and sends no folder event when it stays '
        'in no folder', (WidgetTester tester) async {
      await pumpForm(tester);

      await submit(tester);
      await settle(tester);

      expect(profileRepo.puts, hasLength(1));
      expect(folderEvents(), isEmpty);
    });

    testWidgets('creates nothing when the save fails', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'Databases');
      await pickEntry(tester, '${strings.folderNew}: Databases');
      profileRepo.saveSucceeds = false;

      await submit(tester);
      await settle(tester);

      expect(profileRepo.puts, hasLength(1));
      expect(savedBloc().state, isA<ProfileFailedSave>());
      expect(folderEvents(), isEmpty);
      expect(currentData(), otherFolders);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('moves nothing when the save fails', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await pickEntry(tester, 'Servers');
      profileRepo.saveSucceeds = false;

      await submit(tester);
      await settle(tester);

      expect(savedBloc().state, isA<ProfileFailedSave>());
      expect(folderEvents(), isEmpty);
      expect(currentData(), otherFolders);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('keeps the new folder pending after a failed save and creates '
        'it once when a retry succeeds', (WidgetTester tester) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'Databases');
      await pickEntry(tester, '${strings.folderNew}: Databases');
      final String newId = formFolder(tester).state.folderId!;
      profileRepo.saveSucceeds = false;

      await submit(tester);
      await settle(tester);
      expect(folderEvents(), isEmpty);
      expect(formFolder(tester).state.folderId, newId);
      expect(formFolder(tester).state.newName, 'Databases');

      profileRepo.saveSucceeds = true;
      await submit(tester);
      await settle(tester);

      expect(profileRepo.puts, hasLength(2));
      expect(
        currentData().folders.where((ProfileFolder f) => f.uuid == newId),
        hasLength(1),
      );
      expect(currentData().folders, hasLength(3));
      expect(folderRepo.puts, hasLength(1));
    });

    testWidgets('a second Submit after a saved new folder does not create it '
        'again', (WidgetTester tester) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'Databases');
      await pickEntry(tester, '${strings.folderNew}: Databases');
      final String newId = formFolder(tester).state.folderId!;

      await submit(tester);
      await settle(tester);
      await submit(tester);
      await settle(tester);

      expect(profileRepo.puts, hasLength(2));
      expect(
        folderEvents().whereType<ProfileFolderCreateEvent>().map(
          (ProfileFolderCreateEvent e) => e.uuid,
        ),
        <String>[newId, newId],
      );
      expect(currentData().folders, hasLength(3));
      expect(currentData().folderById(newId)!.profileIds, <String>[uuid]);
      expect(folderRepo.puts, hasLength(1));
    });
  });

  group('Submit while saving', () {
    testWidgets('is disabled during the save so a double click saves once', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      expect(
        tester.widget<ElevatedButton>(submitButton()).onPressed,
        isNotNull,
      );

      profileRepo.saveGate = Completer<void>();
      await submit(tester);
      await tester.pump();

      expect(savedBloc().state, isA<ProfileLoading>());
      expect(tester.widget<ElevatedButton>(submitButton()).onPressed, isNull);

      await tester.tap(submitButton());
      await tester.pump();
      expect(profileRepo.puts, hasLength(1));

      profileRepo.saveGate!.complete();
      await settle(tester);

      expect(profileRepo.puts, hasLength(1));
      expect(
        tester.widget<ElevatedButton>(submitButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('is enabled again after a failed save', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      profileRepo.saveSucceeds = false;

      await submit(tester);
      await settle(tester);

      expect(savedBloc().state, isA<ProfileFailedSave>());
      expect(
        tester.widget<ElevatedButton>(submitButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('a double click with a new folder creates it once', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await openMenu(tester);
      await typeInField(tester, 'Databases');
      await pickEntry(tester, '${strings.folderNew}: Databases');
      profileRepo.saveGate = Completer<void>();

      await submit(tester);
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();
      profileRepo.saveGate!.complete();
      await settle(tester);

      expect(profileRepo.puts, hasLength(1));
      expect(
        folderEvents().whereType<ProfileFolderCreateEvent>(),
        hasLength(1),
      );
      expect(currentData().folders, hasLength(3));
    });
  });

  group('Folders that are not yet synced', () {
    testWidgets('disable the Folder field', (WidgetTester tester) async {
      await pumpForm(tester, synced: false);

      expect(folderBloc.state, isA<ProfileFoldersLoaded>());
      expect(tester.widget<TextField>(folderField()).enabled, isFalse);

      await tester.tap(folderField(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
    });

    testWidgets('enable the Folder field once they have synced', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, synced: false);
      expect(tester.widget<TextField>(folderField()).enabled, isFalse);

      folderRepo.caughtUp.complete(true);
      await tester.pumpAndSettle();

      expect(folderBloc.state.editable, isTrue);
      expect(tester.widget<TextField>(folderField()).enabled, isTrue);
    });

    testWidgets('save the connection and file it once the folders sync', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester, synced: false, folderId: 'g-servers');

      await submit(tester);
      await settle(tester);

      expect(profileRepo.puts, hasLength(1));
      expect(savedBloc().state, isA<ProfileLoaded>());
      expect(folderEvents(), hasLength(1));
      expect(folderRepo.puts, isEmpty);

      folderRepo.caughtUp.complete(true);
      await settle(tester);

      expect(folderRepo.puts, hasLength(1));
      expect(currentData().folderById('g-servers')!.profileIds, <String>[
        's1',
        uuid,
      ]);
    });
  });
}
