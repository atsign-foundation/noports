import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';

void main() {
  group('Signing in from an atKeys file backs its keys up to the keychain', () {
    test('A sign-in from an atKeys file replaces a pending-only keychain entry:'
        " when the keychain holds only request e1's pending keys and the"
        " atServer has accepted the file's keys, then the keychain holds the"
        " file's keys and nothing of e1", () async {
      final keychain = _Keychain(_pendingKeys());

      final dropped = await NoPortsOnboardingUtil.backUpToKeychain(
        _alice,
        InMemoryAtKeysIo.holding('@alice', _fileKeys()),
        accepted: true,
        keychain: keychain,
      );

      final entry = keychain.entries['@alice'];
      expect(
        entry?.enrollmentIds,
        isNot(contains('e1')),
        reason: "nothing of e1 is left in the keychain",
      );
      expect(
        entry?.enrollmentToAuthenticateAs(),
        'e9',
        reason: "the keychain holds the file's keys",
      );
      expect(
        entry?.pendingEnrollmentIds,
        isEmpty,
        reason: 'the next sign-in opens from the keychain',
      );
      expect(dropped, ['e1'], reason: 'e1 is named as dropped');
      expect(
        keychain.callsOutsideWriteSection,
        0,
        reason: 'the entry is read and replaced in one write section',
      );
    });

    testWidgets('A sign-in from an atKeys file replaces a pending-only keychain'
        " entry: when the keychain holds only request e1's pending keys and"
        " the atServer has accepted the file's keys, then the app log names e1"
        ' as dropped and to be denied in the Authenticator', (tester) async {
      await _pumpApp(tester);

      await NoPortsOnboardingUtil.backUpToKeychain(
        _alice,
        InMemoryAtKeysIo.holding('@alice', _fileKeys()),
        accepted: true,
        keychain: _Keychain(_pendingKeys()),
      );

      expect(
        _logLines.where(
          (line) =>
              line.contains('e1') &&
              line.contains('dropped') &&
              line.contains('deny'),
        ),
        hasLength(1),
        reason: 'the app log names e1 as dropped and to be denied',
      );
    });

    test('A sign-in from an atKeys file keeps a keychain entry holding a'
        ' credential: when the keychain holds a credential for the atSign,'
        ' then the entry is left as it was', () async {
      final held = _credentialKeys();
      final keychain = _Keychain(held);

      final dropped = await NoPortsOnboardingUtil.backUpToKeychain(
        _alice,
        InMemoryAtKeysIo.holding('@alice', _fileKeys()),
        accepted: true,
        keychain: keychain,
      );

      expect(
        keychain.entries['@alice'],
        same(held),
        reason: 'the entry is left as it was',
      );
      expect(keychain.writes, 0, reason: 'nothing is written to the keychain');
      expect(dropped, isEmpty, reason: 'nothing is dropped');
    });

    test('A sign-in the atServer has not accepted keeps a pending request:'
        " when the keychain holds only request e1's pending keys and the"
        " atServer has not accepted the file's keys, then e1's keys stay and"
        ' nothing is written', () async {
      final held = _pendingKeys();
      final keychain = _Keychain(held);

      final dropped = await NoPortsOnboardingUtil.backUpToKeychain(
        _alice,
        InMemoryAtKeysIo.holding('@alice', _fileKeys()),
        accepted: false,
        keychain: keychain,
      );

      expect(
        keychain.entries['@alice'],
        same(held),
        reason: "e1's pending keys stay in the keychain",
      );
      expect(keychain.writes, 0, reason: 'nothing is written to the keychain');
      expect(dropped, isEmpty, reason: 'nothing is dropped');
    });

    test('A sign-in from an atKeys file with no keychain entry backs the keys'
        ' up: when the keychain holds nothing, then it holds the file\'s'
        ' keys', () async {
      final keychain = _Keychain();

      await NoPortsOnboardingUtil.backUpToKeychain(
        _alice,
        InMemoryAtKeysIo.holding('@alice', _fileKeys()),
        accepted: true,
        keychain: keychain,
      );

      expect(
        keychain.entries['@alice']?.enrollmentToAuthenticateAs(),
        'e9',
        reason: "the keychain holds the file's keys",
      );
    });
  });
}

final _alice = '@alice'.toAtsign();

/// A keychain holding [alice] for @alice, or nothing at all. [writes] counts
/// the entries added and removed, and [callsOutsideWriteSection] the reads,
/// additions and removals made outside [writing].
class _Keychain extends Fake implements KeychainStorage {
  _Keychain([AtKeys? alice]) {
    if (alice != null) entries['@alice'] = alice;
  }

  final entries = <String, AtKeys>{};
  var writes = 0;
  var callsOutsideWriteSection = 0;
  var _writeSections = 0;

  void _call() {
    if (_writeSections == 0) callsOutsideWriteSection++;
  }

  /// Throws as `KeychainStorage.getAtsign` does when the keychain holds no
  /// atSign at all.
  @override
  Future<AtKeys?> getAtsign(String atSign) async {
    _call();
    if (entries.isEmpty) throw AtKeyException('No atsign found in keychain');
    return entries[atSign];
  }

  @override
  Future<T> writing<T>(Future<T> Function() action) async {
    _writeSections++;
    try {
      return await action();
    } finally {
      _writeSections--;
    }
  }

  @override
  Future<void> appendAtKeysToKeychain({required AtKeys keys}) async {
    _call();
    writes++;
    entries[keys.atsign.toString()] = keys;
  }

  @override
  Future<void> removeAtsignFromKeychain(String atSign) async {
    _call();
    writes++;
    entries.remove(atSign);
  }
}

/// What a request awaiting a decision leaves in the keychain: its keypair,
/// filed as pending under enrollment e1.
AtKeys _pendingKeys() => AtKeys.fromJson({
  'version': 1,
  'atsign': '@alice',
  'keys': <Object?>[],
  'enrollments': [
    {
      'enrollmentId': 'e1',
      'appName': 'noports',
      'deviceName': 'testdevice',
      'keys': [
        {
          'keyId': 'auth:rsa2048:1',
          'material': [
            {
              'role': 'privateAuthentication',
              'algorithm': 'rsa2048',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'status': 'pending',
              'bytes': 'cHJpdmF0ZQ==',
            },
          ],
        },
      ],
    },
  ],
});

/// A credential for @alice already in the keychain, of enrollment e0.
AtKeys _credentialKeys() => AtKeys.legacy(
  apkamPublicKey: 'cHVibGlj',
  apkamPrivateKey: 'cHJpdmF0ZQ==',
  enrollmentId: 'e0',
);

/// The keys in the atKeys file the user signs in with, of enrollment e9.
AtKeys _fileKeys() => AtKeys.legacy(
  apkamPublicKey: 'ZmlsZXB1Yg==',
  apkamPrivateKey: 'ZmlsZXByaXY=',
  enrollmentId: 'e9',
);

/// What has been written to the app log.
Iterable<String> get _logLines => App.navState.currentContext!
    .read<LogsCubit>()
    .logs
    .map((entry) => entry.loggable.toString());

/// Provides the app log [App.log] writes to.
Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnableLoggingCubit()),
        BlocProvider(create: (_) => LogsCubit()),
      ],
      child: MaterialApp(navigatorKey: App.navState, home: const Scaffold()),
    ),
  );
}
