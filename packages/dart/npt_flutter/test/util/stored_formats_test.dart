import 'dart:convert';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/repository/profile_folder_repository.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/export.dart';
import 'package:npt_flutter/util/language.dart';

import '../features/profile/repository/profile_repository_test.mocks.dart';

// What a version of the app wrote to the atServer. These literals must not
// change when the code is renamed: older and newer versions read the same data.
const String _storedFolders = '''
{
  "folders": [
    {
      "uuid": "f1",
      "name": "Work",
      "profileIds": ["a", "b", "c"],
      "favorite": true,
      "collapsed": true,
      "skippedByStartAll": ["b"]
    },
    {
      "uuid": "f2",
      "name": "Home",
      "profileIds": ["d"]
    }
  ],
  "unfiled": ["e", "f"],
  "unfiledCollapsed": true
}
''';

const String _foldersFromNewerVersion = '''
{
  "folders": [
    {
      "uuid": "f1",
      "name": "Work",
      "profileIds": ["a"],
      "icon": "briefcase",
      "colour": {"red": 1, "green": 2}
    }
  ],
  "unfiled": ["b"],
  "layoutVersion": 3
}
''';

const String _storedSettings = '''
{
  "relayAtsign": "@rv_eu",
  "overrideRelay": true,
  "viewLayout": "ssh-style",
  "darkMode": true,
  "language": "es",
  "sortMode": "name-descending",
  "favoritesFirst": true
}
''';

const Map<ProfileSortMode, String> _sortModeLiterals =
    <ProfileSortMode, String>{
      ProfileSortMode.manual: 'manual',
      ProfileSortMode.nameAscending: 'name-ascending',
      ProfileSortMode.nameDescending: 'name-descending',
    };

const Map<ExportableProfileFiletype, String> _exportedDocuments =
    <ExportableProfileFiletype, String>{
      ExportableProfileFiletype.json: '''
{
  "profiles": [
    {
      "displayName": "Lab",
      "deviceName": "lab-device",
      "remotePort": 22,
      "localPort": 2222,
      "favorite": true
    },
    {
      "displayName": "Printer",
      "deviceName": "printer",
      "remotePort": 631,
      "localPort": 6310
    }
  ]
}
''',
      ExportableProfileFiletype.yaml: '''
profiles:
  - displayName: Lab
    deviceName: lab-device
    remotePort: 22
    localPort: 2222
    favorite: true
  - displayName: Printer
    deviceName: printer
    remotePort: 631
    localPort: 6310
''',
    };

const Profile _lab = Profile(
  'p1',
  displayName: 'Lab',
  deviceName: 'lab-device',
  remotePort: 22,
  localPort: 2222,
);
const Profile _printer = Profile(
  'p2',
  displayName: 'Printer',
  deviceName: 'printer',
  remotePort: 631,
  localPort: 6310,
);

Settings _settings({
  ProfileSortMode sortMode = ProfileSortMode.manual,
  bool favoritesFirst = false,
}) => Settings(
  relayAtsign: '@rv_am'.toAtsign(),
  overrideRelay: false,
  viewLayout: PreferredViewLayout.minimal,
  language: Language.english,
  sortMode: sortMode,
  favoritesFirst: favoritesFirst,
);

Map<String, dynamic> _settingsFromOlderVersion() => <String, dynamic>{
  'relayAtsign': '@rv_am',
  'overrideRelay': false,
  'viewLayout': 'minimal',
  'darkMode': false,
  'language': 'en',
};

final class _FakeProfileRepository extends ProfileRepository {
  final List<Profile> put = <Profile>[];

  @override
  Future<bool> putProfile(Profile profile) async {
    put.add(profile);
    return true;
  }
}

final class _FakeFavoriteRepository extends FavoriteRepository {
  final Map<String, Favorite> stored;

  _FakeFavoriteRepository(Iterable<String> profileUuids)
    : stored = <String, Favorite>{
        for (final String uuid in profileUuids)
          uuid: FavoriteProfile(uuid: uuid),
      };

  @override
  Future<Map<String, Favorite>?> getFavorites({bool useCache = true}) async =>
      Map<String, Favorite>.of(stored);

  @override
  Future<bool> addFavorite(Favorite favorite) async {
    stored[favorite.uuid] = favorite;
    return true;
  }
}

/// One installation of the app: its stored profiles and favorites, and the
/// blocs that export and import read from the widget tree.
final class _Installation {
  final _FakeProfileRepository profileRepository = _FakeProfileRepository();
  final _FakeFavoriteRepository favoriteRepository;
  late final ProfileListBloc profileListBloc = ProfileListBloc(
    profileRepository,
  );
  late final FavoriteBloc favoriteBloc = FavoriteBloc(favoriteRepository);

  _Installation({Set<String> favorites = const <String>{}})
    : favoriteRepository = _FakeFavoriteRepository(favorites);

  Set<String> get favoriteUuids => (favoriteBloc.state as FavoritesLoaded)
      .favorites
      .map((Favorite favorite) => favorite.uuid)
      .toSet();
}

void main() {
  group('ProfileFolderData stored format', () {
    test('every folder and data field is read from the stored JSON', () {
      final ProfileFolderData data = ProfileFolderData.fromJson(
        jsonDecode(_storedFolders),
      );

      expect(
        data,
        const ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'f1',
              name: 'Work',
              profileIds: <String>['a', 'b', 'c'],
              favorite: true,
              collapsed: true,
              skippedByStartAll: <String>['b'],
            ),
            ProfileFolder(uuid: 'f2', name: 'Home', profileIds: <String>['d']),
          ],
          unfiled: <String>['e', 'f'],
          unfiledCollapsed: true,
        ),
      );
    });

    test('a folder missing its optional fields is read with the defaults', () {
      final ProfileFolderData data = ProfileFolderData.fromJson(
        jsonDecode(_storedFolders),
      );
      final ProfileFolder home = data.folders.last;

      expect(home.favorite, isFalse);
      expect(home.collapsed, isFalse);
      expect(home.skippedByStartAll, isEmpty);
      expect(home.unknown, isEmpty);
      expect(
        ProfileFolderData.fromJson(<String, dynamic>{}).unfiledCollapsed,
        isFalse,
      );
    });

    test('every folder and data field is written with its stored name', () {
      const ProfileFolderData data = ProfileFolderData(
        folders: <ProfileFolder>[
          ProfileFolder(
            uuid: 'f1',
            name: 'Work',
            profileIds: <String>['a', 'b', 'c'],
            favorite: true,
            collapsed: true,
            skippedByStartAll: <String>['b'],
          ),
        ],
        unfiled: <String>['e'],
        unfiledCollapsed: true,
      );

      expect(data.toJson(), <String, dynamic>{
        'folders': <dynamic>[
          <String, dynamic>{
            'uuid': 'f1',
            'name': 'Work',
            'profileIds': <String>['a', 'b', 'c'],
            'favorite': true,
            'collapsed': true,
            'skippedByStartAll': <String>['b'],
          },
        ],
        'unfiled': <String>['e'],
        'unfiledCollapsed': true,
      });
    });

    test('flags that are off are left out of the stored JSON', () {
      const ProfileFolderData data = ProfileFolderData(
        folders: <ProfileFolder>[
          ProfileFolder(uuid: 'f2', name: 'Home', profileIds: <String>['d']),
        ],
      );

      expect(data.toJson(), <String, dynamic>{
        'folders': <dynamic>[
          <String, dynamic>{
            'uuid': 'f2',
            'name': 'Home',
            'profileIds': <String>['d'],
          },
        ],
        'unfiled': <String>[],
      });
    });

    test('reading and writing the stored JSON gives back the same JSON', () {
      final ProfileFolderData data = ProfileFolderData.fromJson(
        jsonDecode(_storedFolders),
      );

      expect(data.toJson(), jsonDecode(_storedFolders));
    });

    test(
      'fields from a newer version survive an edit and are written back',
      () {
        final ProfileFolderData data = ProfileFolderData.fromJson(
          jsonDecode(_foldersFromNewerVersion),
        );

        expect(data.unknown, <String, dynamic>{'layoutVersion': 3});
        expect(data.folders.single.unknown, <String, dynamic>{
          'icon': 'briefcase',
          'colour': <String, dynamic>{'red': 1, 'green': 2},
        });

        final ProfileFolderData edited = data.copyWith(
          folders: <ProfileFolder>[
            data.folders.single.copyWith(favorite: true),
          ],
          unfiledCollapsed: true,
        );

        expect(edited.toJson(), <String, dynamic>{
          'layoutVersion': 3,
          'folders': <dynamic>[
            <String, dynamic>{
              'icon': 'briefcase',
              'colour': <String, dynamic>{'red': 1, 'green': 2},
              'uuid': 'f1',
              'name': 'Work',
              'profileIds': <String>['a'],
              'favorite': true,
            },
          ],
          'unfiled': <String>['b'],
          'unfiledCollapsed': true,
        });
      },
    );
  });

  group('ProfileFolderRepository stored key', () {
    late MockAtClient atClient;
    late ProfileFolderRepository repository;

    setUp(() {
      atClient = MockAtClient();
      repository = ProfileFolderRepository(atClient: atClient);
      when(atClient.getCurrentAtSign()).thenReturn('@test_user');
    });

    test('the key is "folders" in the "noports" namespace', () {
      final AtKey key = ProfileFolderRepository.getProfileFolderAtKey();

      expect(key.key, 'folders');
      expect(key.namespace, 'noports');
    });

    test('the folders are read from the "folders" key', () async {
      when(
        atClient.get(any),
      ).thenAnswer((_) async => AtValue()..value = _storedFolders);

      final ProfileFolderData? data = await repository.getProfileFolders();

      expect(data?.toJson(), jsonDecode(_storedFolders));
      final AtKey read =
          verify(atClient.get(captureAny)).captured.single as AtKey;
      expect(read.key, 'folders');
      expect(read.namespace, 'noports');
      expect(read.sharedBy, '@test_user');
    });

    test(
      'the folders are written to the "folders" key as the stored JSON',
      () async {
        when(atClient.put(any, any)).thenAnswer((_) async => true);

        final bool saved = await repository.putProfileFolders(
          ProfileFolderData.fromJson(jsonDecode(_storedFolders)),
        );

        expect(saved, isTrue);
        final List<dynamic> written = verify(
          atClient.put(captureAny, captureAny),
        ).captured;
        final AtKey key = written[0] as AtKey;
        expect(key.key, 'folders');
        expect(key.namespace, 'noports');
        expect(key.sharedBy, '@test_user');
        expect(jsonDecode(written[1] as String), jsonDecode(_storedFolders));
      },
    );
  });

  group('Settings stored format', () {
    test('every setting is read from the stored JSON', () {
      final Settings settings = Settings.fromJson(jsonDecode(_storedSettings));

      expect(settings.relayAtsign, '@rv_eu');
      expect(settings.overrideRelay, isTrue);
      expect(settings.viewLayout, PreferredViewLayout.sshStyle);
      expect(settings.darkMode, isTrue);
      expect(settings.language, Language.spanish);
      expect(settings.sortMode, ProfileSortMode.nameDescending);
      expect(settings.favoritesFirst, isTrue);
    });

    test('every setting is written with its stored name and value', () {
      final Settings settings = Settings(
        relayAtsign: '@rv_eu'.toAtsign(),
        overrideRelay: true,
        viewLayout: PreferredViewLayout.sshStyle,
        darkMode: true,
        language: Language.spanish,
        sortMode: ProfileSortMode.nameDescending,
        favoritesFirst: true,
      );

      expect(settings.toJson(), jsonDecode(_storedSettings));
    });

    test(
      'the sort modes are stored as manual and name-ascending/descending',
      () {
        expect(_sortModeLiterals.keys, unorderedEquals(ProfileSortMode.values));

        _sortModeLiterals.forEach((ProfileSortMode mode, String literal) {
          expect(
            _settings(sortMode: mode).toJson()['sortMode'],
            literal,
            reason: 'writing $mode',
          );
          expect(
            Settings.fromJson(<String, dynamic>{
              ..._settingsFromOlderVersion(),
              'sortMode': literal,
            }).sortMode,
            mode,
            reason: 'reading "$literal"',
          );
        });
      },
    );

    test('favoritesFirst is stored as a boolean under that name', () {
      expect(
        _settings(favoritesFirst: true).toJson()['favoritesFirst'],
        isTrue,
      );
      expect(
        _settings(favoritesFirst: false).toJson()['favoritesFirst'],
        isFalse,
      );
      expect(
        Settings.fromJson(<String, dynamic>{
          ..._settingsFromOlderVersion(),
          'favoritesFirst': true,
        }).favoritesFirst,
        isTrue,
      );
    });

    test('settings stored before sorting existed read as manual and off', () {
      final Settings settings = Settings.fromJson(_settingsFromOlderVersion());

      expect(settings.sortMode, ProfileSortMode.manual);
      expect(settings.favoritesFirst, isFalse);
    });

    test('a sort mode this version does not know reads as manual', () {
      final Settings settings = Settings.fromJson(<String, dynamic>{
        ..._settingsFromOlderVersion(),
        'sortMode': 'by-date',
        'favoritesFirst': true,
      });

      expect(settings.sortMode, ProfileSortMode.manual);
      expect(settings.favoritesFirst, isTrue);
    });

    test('a stored sort mode of null reads as manual', () {
      final Settings settings = Settings.fromJson(<String, dynamic>{
        ..._settingsFromOlderVersion(),
        'sortMode': null,
      });

      expect(settings.sortMode, ProfileSortMode.manual);
    });
  });

  group('Export and import of favorites', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('npt_stored_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<_Installation> openInstallation(
      WidgetTester tester, {
      Set<String> favorites = const <String>{},
    }) async {
      final _Installation installation = _Installation(favorites: favorites);
      addTearDown(installation.favoriteBloc.close);
      addTearDown(installation.profileListBloc.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => EnableLoggingCubit()),
            BlocProvider(create: (_) => LogsCubit()),
            BlocProvider.value(value: installation.favoriteBloc),
            BlocProvider.value(value: installation.profileListBloc),
          ],
          child: MaterialApp(
            navigatorKey: App.navState,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );
      installation.favoriteBloc.add(const FavoriteLoadEvent());
      installation.profileListBloc.add(
        const ProfileListUpdateEvent(<String>[]),
      );
      await tester.pump();
      return installation;
    }

    Future<void> importDocument(
      WidgetTester tester,
      ExportableProfileFiletype filetype,
      String contents,
    ) async {
      Export.convertExternalDataSourceToProfile(
        fileType: filetype,
        contents: contents,
      );
      await tester.pump();
      // The import reports its result from a post-frame callback.
      tester.binding.scheduleFrame();
      await tester.pump();
    }

    Future<File> exportTo(
      WidgetTester tester,
      ExportableProfileFiletype filetype,
    ) async {
      final File file = File('${dir.path}/export.${filetype.filetype}');
      await tester.runAsync(
        () => Export.saveFile(
          filetype,
          Export.exportableProfiles(<Profile>[_lab, _printer]),
          pickFile: (_) async => file,
        ),
      );
      return file;
    }

    testWidgets('only favorite profiles carry the "favorite" key', (
      tester,
    ) async {
      await openInstallation(tester, favorites: <String>{'p1'});

      final List<Map<String, dynamic>> exported = Export.exportableProfiles(
        <Profile>[_lab, _printer],
      );

      expect(exported, hasLength(2));
      expect(exported[0], containsPair('displayName', 'Lab'));
      expect(exported[0], containsPair('favorite', true));
      expect(exported[1], containsPair('displayName', 'Printer'));
      expect(exported[1], isNot(contains('favorite')));
    });

    for (final ExportableProfileFiletype filetype
        in ExportableProfileFiletype.values) {
      testWidgets('the ${filetype.filetype} file marks a favorite as '
          '"favorite" once', (tester) async {
        await openInstallation(tester, favorites: <String>{'p1'});

        final File file = await exportTo(tester, filetype);

        final String text = file.readAsStringSync();
        expect(
          text,
          contains(switch (filetype) {
            ExportableProfileFiletype.json => '"favorite":true',
            ExportableProfileFiletype.yaml => 'favorite: true',
          }),
        );
        expect('favorite'.allMatches(text), hasLength(1));
      });

      testWidgets('favorites survive a ${filetype.filetype} export and '
          'import', (tester) async {
        await openInstallation(tester, favorites: <String>{'p1'});
        final File file = await exportTo(tester, filetype);

        final _Installation other = await openInstallation(tester);
        await importDocument(tester, filetype, file.readAsStringSync());

        final List<Profile> imported = other.profileRepository.put;
        expect(imported.map((Profile p) => p.displayName), <String>[
          'Lab',
          'Printer',
        ]);
        final Profile lab = imported.first;
        expect(lab.uuid, isNot('p1'));
        expect(other.favoriteUuids, <String>{lab.uuid});
        expect(other.favoriteRepository.stored.keys, <String>[lab.uuid]);
      });

      testWidgets('a ${filetype.filetype} document with "favorite": true '
          'imports that profile as a favorite', (tester) async {
        final _Installation installation = await openInstallation(tester);

        await importDocument(tester, filetype, _exportedDocuments[filetype]!);

        final List<Profile> imported = installation.profileRepository.put;
        expect(imported.map((Profile p) => p.displayName), <String>[
          'Lab',
          'Printer',
        ]);
        expect(installation.favoriteUuids, <String>{imported.first.uuid});
      });
    }

    testWidgets('nothing is imported as a favorite without the key', (
      tester,
    ) async {
      final _Installation installation = await openInstallation(tester);

      await importDocument(
        tester,
        ExportableProfileFiletype.json,
        _exportedDocuments[ExportableProfileFiletype.json]!.replaceAll(
          '"favorite"',
          '"starred"',
        ),
      );

      expect(installation.profileRepository.put, hasLength(2));
      expect(installation.favoriteUuids, isEmpty);
    });
  });
}
