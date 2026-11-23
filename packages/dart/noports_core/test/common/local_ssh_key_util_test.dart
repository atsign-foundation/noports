import 'dart:io';

import 'package:noports_core/src/common/at_ssh_key_util/local_ssh_key_util.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'ssh_public_key_fixtures.dart';

const _userKey = 'ssh-ed25519 AAAAexistingUserKey user@laptop';

void main() {
  group('LocalSshKeyUtil authorized_keys', () {
    late Directory home;
    late File authKeys;
    late LocalSshKeyUtil keyUtil;
    late String idA;
    late String idB;

    String ephemeralLine(String key, String sessionId) =>
        'command="echo \\"ssh session complete\\";sleep 20"'
        ',PermitOpen="localhost:22"'
        ' $key sshnp_ephemeral_$sessionId';

    Future<void> authorize(String key, String sessionId) =>
        keyUtil.authorizePublicKey(
          sshPublicKey: key,
          localSshdPort: 22,
          sessionId: sessionId,
        );

    setUp(() {
      home = Directory.systemTemp.createTempSync('local_ssh_key_util_test');
      Directory('${home.path}/.ssh').createSync();
      authKeys = File('${home.path}/.ssh/authorized_keys')
        ..writeAsStringSync('$_userKey\n');
      keyUtil = LocalSshKeyUtil(homeDirectory: home.path);
      idA = Uuid().v4();
      idB = Uuid().v4();
    });

    tearDown(() {
      home.deleteSync(recursive: true);
    });

    test(
      'authorizePublicKey appends one restricted line for the session',
      () async {
        await authorize('ssh-ed25519 AAAAkeyA', idA);

        expect(authKeys.readAsLinesSync(), [
          _userKey,
          ephemeralLine('ssh-ed25519 AAAAkeyA', idA),
        ]);
      },
    );

    test(
      'authorizePublicKey creates a missing authorized_keys readable only by its owner',
      () async {
        authKeys.deleteSync();

        await authorize('ssh-ed25519 AAAAkeyA', idA);

        expect(authKeys.readAsLinesSync(), [
          ephemeralLine('ssh-ed25519 AAAAkeyA', idA),
        ]);
        if (!Platform.isWindows) {
          final int permissions = authKeys.statSync().mode & 0x1ff;
          expect(permissions, int.parse('600', radix: 8));
        }
      },
    );

    test(
      'authorizePublicKey writes no blank line into an empty authorized_keys',
      () async {
        authKeys.writeAsStringSync('');

        await authorize('ssh-ed25519 AAAAkeyA', idA);

        expect(authKeys.readAsLinesSync(), [
          ephemeralLine('ssh-ed25519 AAAAkeyA', idA),
        ]);
      },
    );

    test(
      'authorizePublicKey leaves an existing authorized_keys\' permissions alone',
      () async {
        Process.runSync('chmod', ['644', authKeys.path]);

        await authorize('ssh-ed25519 AAAAkeyA', idA);

        expect(authKeys.statSync().mode & 0x1ff, int.parse('644', radix: 8));
      },
      testOn: '!windows',
    );

    test('deauthorizePublicKey removes only that session\'s line', () async {
      await authorize('ssh-ed25519 AAAAkeyA', idA);
      await authorize('ssh-ed25519 AAAAkeyB', idB);

      await keyUtil.deauthorizePublicKey(idA);

      expect(authKeys.readAsLinesSync(), [
        _userKey,
        ephemeralLine('ssh-ed25519 AAAAkeyB', idB),
      ]);
    });

    test(
      'deauthorizePublicKey keeps lines which merely contain the id',
      () async {
        final containing = [
          'ssh-ed25519 AAAAidAsComment $idA',
          'ssh-ed25519 AAAAidMidLine$idA user@laptop',
          'ssh-ed25519 AAAAlongerId sshnp_ephemeral_$idA-old',
          'ssh-ed25519 AAAAnoSeparator notsshnp_ephemeral_$idA',
        ];
        authKeys.writeAsStringSync('$_userKey\n${containing.join('\n')}\n');
        await authorize('ssh-ed25519 AAAAkeyA', idA);

        await keyUtil.deauthorizePublicKey(idA);

        expect(authKeys.readAsLinesSync(), [_userKey, ...containing]);
      },
    );

    test(
      'deauthorizePublicKey with a substring of every line removes nothing',
      () async {
        await authorize('ssh-ed25519 AAAAkeyA', idA);
        final before = authKeys.readAsLinesSync();

        for (final sessionId in ['', 'ssh', 'sshnp_ephemeral_']) {
          await keyUtil.deauthorizePublicKey(sessionId);
          expect(
            authKeys.readAsLinesSync(),
            before,
            reason: 'deauthorizePublicKey("$sessionId") removed a line',
          );
        }
      },
    );

    test('concurrent removals each take effect', () async {
      await authorize('ssh-ed25519 AAAAkeyA', idA);
      await authorize('ssh-ed25519 AAAAkeyB', idB);

      await Future.wait([
        keyUtil.deauthorizePublicKey(idA),
        LocalSshKeyUtil(homeDirectory: home.path).deauthorizePublicKey(idB),
      ]);

      expect(authKeys.readAsLinesSync(), [_userKey]);
    });

    test('a removal concurrent with an authorization keeps the new key',
        () async {
      await authorize('ssh-ed25519 AAAAkeyA', idA);

      await Future.wait([
        keyUtil.deauthorizePublicKey(idA),
        LocalSshKeyUtil(homeDirectory: home.path).authorizePublicKey(
          sshPublicKey: 'ssh-ed25519 AAAAkeyB',
          localSshdPort: 22,
          sessionId: idB,
        ),
      ]);

      expect(authKeys.readAsLinesSync(), [
        _userKey,
        ephemeralLine('ssh-ed25519 AAAAkeyB', idB),
      ]);
    });

    test(
      'addPublicKey creates a missing authorized_keys readable only by its owner',
      () async {
        authKeys.deleteSync();

        await keyUtil.addPublicKey(sshPublicKey: 'ssh-ed25519 $k1');

        expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-ed25519', k1)]);
        if (!Platform.isWindows) {
          final int permissions = authKeys.statSync().mode & 0x1ff;
          expect(permissions, int.parse('600', radix: 8));
        }
      },
    );

    test('addPublicKey puts the permissions after the loopback restriction',
        () async {
      await keyUtil.addPublicKey(
        sshPublicKey: 'ssh-ed25519 $k1',
        permissions: 'no-pty',
      );

      expect(authKeys.readAsLinesSync(), [
        _userKey,
        loopbackLine('ssh-ed25519', k1, permissions: 'no-pty'),
      ]);
    });

    test('addPublicKey adds a key only once', () async {
      await keyUtil.addPublicKey(sshPublicKey: 'ssh-ed25519 $k1');
      await keyUtil.addPublicKey(sshPublicKey: 'ssh-ed25519 $k1');

      expect(authKeys.readAsLinesSync(), [
        _userKey,
        loopbackLine('ssh-ed25519', k1),
      ]);
    });

    test('an addition concurrent with a removal keeps the added key', () async {
      await authorize('ssh-ed25519 AAAAkeyA', idA);

      await Future.wait([
        keyUtil.deauthorizePublicKey(idA),
        LocalSshKeyUtil(
          homeDirectory: home.path,
        ).addPublicKey(sshPublicKey: 'ssh-ed25519 $k1'),
      ]);

      expect(authKeys.readAsLinesSync(), [
        _userKey,
        loopbackLine('ssh-ed25519', k1),
      ]);
    });

    test(
      'addPublicKey refuses permissions holding a newline or a from option',
      () async {
        final List<int> before = authKeys.readAsBytesSync();

        for (final String permissions in [
          'no-pty\nssh-ed25519 $k2',
          'no-pty\r',
          'from="10.0.0.0/8"',
          'no-pty,FROM="10.0.0.0/8"',
        ]) {
          await expectLater(
            keyUtil.addPublicKey(
              sshPublicKey: 'ssh-ed25519 $k1',
              permissions: permissions,
            ),
            throwsArgumentError,
            reason: permissions,
          );
        }
        expect(authKeys.readAsBytesSync(), before);
      },
    );
  });

  group('addPublicKey', () {
    late Directory home;
    late File authKeys;
    late LocalSshKeyUtil keyUtil;

    setUp(() {
      home = Directory.systemTemp.createTempSync('add_public_key_test');
      authKeys = File('${home.path}/.ssh/authorized_keys');
      keyUtil = LocalSshKeyUtil(homeDirectory: home.path);
    });

    tearDown(() {
      home.deleteSync(recursive: true);
    });

    Future<void> add(String value) =>
        keyUtil.addPublicKey(sshPublicKey: value);

    /// Checks that [add] refuses [value], leaving authorized_keys as it was.
    Future<void> expectRefused(String value) async {
      final List<int> before = authKeys.readAsBytesSync();
      await expectLater(add(value), throwsFormatException);
      expect(authKeys.readAsBytesSync(), before);
    }

    test(
      'a key added after a last line with no newline starts a line of its own',
      () async {
        authKeys.writeAsStringSync('ssh-ed25519 $k0 user@laptop');

        await add('ssh-ed25519 $k1');

        expect(authKeys.readAsLinesSync(), [
          'ssh-ed25519 $k0 user@laptop',
          loopbackLine('ssh-ed25519', k1),
        ]);
      },
    );

    test(
      'two keys sent one after the other are each on a line of their own',
      () async {
        await add('ssh-ed25519 $k1');
        await add('ssh-ed25519 $k2');

        expect(authKeys.readAsLinesSync(), [
          loopbackLine('ssh-ed25519', k1),
          loopbackLine('ssh-ed25519', k2),
        ]);
      },
    );

    test('a key already in authorized_keys is not added again', () async {
      authKeys.writeAsStringSync('${loopbackLine('ssh-ed25519', k1)}\n');
      final List<int> before = authKeys.readAsBytesSync();

      await add('ssh-ed25519 $k1');

      expect(authKeys.readAsBytesSync(), before);
    });

    test(
      'a key already in authorized_keys on a line of its own options is left as it is',
      () async {
        authKeys.writeAsStringSync('ssh-ed25519 $k1 user@laptop\n');
        final List<int> before = authKeys.readAsBytesSync();

        await add('ssh-ed25519 $k1');

        expect(authKeys.readAsBytesSync(), before);
      },
    );

    test('a key sent with a trailing newline keeps its comment', () async {
      await add('ssh-ed25519 $k1 user@client\n');

      expect(authKeys.readAsLinesSync(), [
        loopbackLine('ssh-ed25519', k1, comment: 'user@client'),
      ]);
    });

    test('an RSA key named by its signature algorithm is written as ssh-rsa',
        () async {
      await add('rsa-sha2-256 $r1');

      expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-rsa', r1)]);
    });

    test(
      'a value whose key data is not of its stated key type changes nothing',
      () async {
        authKeys.writeAsStringSync('ssh-ed25519 $k0 user@laptop\n');

        await expectRefused('ssh-ed25519 $r1');
      },
    );

    test(
      'a value with a key type outside the supported list changes nothing',
      () async {
        authKeys.writeAsStringSync('ssh-ed25519 $k0 user@laptop\n');

        await expectRefused('ssh-dss $k1');
      },
    );

    test('a value over 8 KiB changes nothing', () async {
      authKeys.writeAsStringSync('ssh-ed25519 $k0 user@laptop\n');
      final String value = 'ssh-ed25519 $k1 '.padRight(8193, 'a');
      expect(value.length, 8193);

      await expectRefused(value);
    });

    test('a value of exactly 8 KiB is added', () async {
      final String value = 'ssh-ed25519 $k1 '.padRight(8192, 'a');

      await add(value);

      expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-ed25519', k1)]);
    });

    test('a key with a comment of 256 printable characters keeps it', () async {
      final String comment = 'a' * 255 + '~';

      await add('ssh-ed25519 $k1 $comment');

      expect(authKeys.readAsLinesSync(), [
        loopbackLine('ssh-ed25519', k1, comment: comment),
      ]);
    });
  });
}
