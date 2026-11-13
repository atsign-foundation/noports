import 'dart:io';

import 'package:noports_core/src/common/at_ssh_key_util/local_ssh_key_util.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

const _userKey = 'ssh-ed25519 AAAAexistingUserKey user@laptop';
const _clientKey = 'ssh-ed25519 AAAAclientKey user@client';

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

        await keyUtil.addPublicKey(sshPublicKey: '$_clientKey\n');

        expect(authKeys.readAsLinesSync(), [_clientKey]);
        if (!Platform.isWindows) {
          final int permissions = authKeys.statSync().mode & 0x1ff;
          expect(permissions, int.parse('600', radix: 8));
        }
      },
    );

    test('addPublicKey puts the permissions before the key', () async {
      await keyUtil.addPublicKey(
        sshPublicKey: '$_clientKey\n',
        permissions: 'no-pty',
      );

      expect(authKeys.readAsLinesSync(), [_userKey, 'no-pty $_clientKey']);
    });

    test('addPublicKey adds a key only once', () async {
      await keyUtil.addPublicKey(sshPublicKey: '$_clientKey\n');
      await keyUtil.addPublicKey(sshPublicKey: '$_clientKey\n');

      expect(authKeys.readAsLinesSync(), [_userKey, _clientKey]);
    });

    test('an addition concurrent with a removal keeps the added key', () async {
      await authorize('ssh-ed25519 AAAAkeyA', idA);

      await Future.wait([
        keyUtil.deauthorizePublicKey(idA),
        LocalSshKeyUtil(
          homeDirectory: home.path,
        ).addPublicKey(sshPublicKey: '$_clientKey\n'),
      ]);

      expect(authKeys.readAsLinesSync(), [_userKey, _clientKey]);
    });
  });
}
