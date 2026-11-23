import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:logging/logging.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import '../common/ssh_public_key_fixtures.dart';
import 'noports_harness.dart';

/// The start of each message the daemon logs once it has finished with an
/// sshpublickey notification.
final RegExp _outcome = RegExp(
  r'^(Added the ssh public key from|The ssh public key from .* is already'
  r'|Refusing the sshpublickey from|Ignoring sshpublickey from'
  r'|Error writing to)',
);

void main() {
  late NoPortsHarness harness;
  late SshnpdImpl daemon;
  late AtClient alice;
  late File authKeys;
  late List<LogRecord> logs;
  late StreamController<LogRecord> outcomes;

  setUp(() {
    harness = NoPortsHarness.create();
    authKeys = File('${harness.home.path}/.ssh/authorized_keys');
    logs = [];
    outcomes = StreamController.broadcast();
    addTearDown(outcomes.close);
  });

  void givenAuthorizedKeys(String content) {
    authKeys.parent.createSync(recursive: true);
    authKeys.writeAsStringSync(content);
  }

  Future<void> startDaemon({
    bool addSshPublicKeys = true,
    String sshPublicKeyPermissions = '',
  }) async {
    daemon = await harness.startDaemon(
      permitOpen: ['localhost:22'],
      addSshPublicKeys: addSshPublicKeys,
      sshPublicKeyPermissions: sshPublicKeyPermissions,
    );
    daemon.logger.logger.level = Level.ALL;
    final subscription = daemon.logger.logger.onRecord.listen((r) {
      logs.add(r);
      if (_outcome.hasMatch(r.message)) outcomes.add(r);
    });
    addTearDown(subscription.cancel);
    alice = await harness.openClient(
      NoPortsHarness.clientAtSign,
      namespace: DefaultArgs.namespace,
    );
  }

  Future<void> notifyDaemon(String key, String value) =>
      alice.notificationService.notify(
        NotificationParams.forUpdate(
          AtKey()
            ..key = key
            ..namespace = '${NoPortsHarness.device}.${DefaultArgs.namespace}'
            ..sharedBy = alice.getCurrentAtSign()
            ..sharedWith = NoPortsHarness.daemonAtSign
            ..metadata = (Metadata()..ttl = 10000),
          value: value,
        ),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

  /// Sends each of [values] as @alice's sshpublickey, all at once, and
  /// returns the daemon's last log line about each, waiting up to 10 seconds.
  Future<List<LogRecord>> send(List<String> values) async {
    final Future<List<LogRecord>> finished = outcomes.stream
        .take(values.length)
        .toList()
        .timeout(const Duration(seconds: 10));
    await Future.wait(values.map((v) => notifyDaemon('sshpublickey', v)));
    return finished;
  }

  test(
    'a client\'s key is added as one line that allows only loopback logins',
    () async {
      givenAuthorizedKeys('ssh-ed25519 $k0 user@laptop\n');
      await startDaemon();

      await send(['ssh-ed25519 $k1']);

      expect(authKeys.readAsLinesSync(), [
        'ssh-ed25519 $k0 user@laptop',
        loopbackLine('ssh-ed25519', k1),
      ]);
      expect(authKeys.readAsStringSync(), endsWith('\n'));
    },
  );

  test('two keys sent together are each on a line of their own', () async {
    await startDaemon();

    await send(['ssh-ed25519 $k1', 'ssh-ed25519 $k2']);

    expect(
      authKeys.readAsLinesSync(),
      unorderedEquals([
        loopbackLine('ssh-ed25519', k1),
        loopbackLine('ssh-ed25519', k2),
      ]),
    );
  });

  test(
    'a key whose comment is not printable ASCII, or is over 256 characters, is added without it',
    () async {
      final String comment = 'a' * 257;
      await startDaemon();

      final [outcome] = await send(['ssh-ed25519 $k1 $comment']);

      expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-ed25519', k1)]);
      expect(outcome.level, Level.INFO);
      expect(outcome.message, contains(NoPortsHarness.clientAtSign));
      expect(outcome.message, contains('without its comment'));
      expect(logs.where((r) => r.message.contains('a' * 20)), isEmpty);
    },
  );

  test(
    'a key whose comment holds a character outside printable ASCII is added without it',
    () async {
      await startDaemon();

      final [outcome] = await send(['ssh-ed25519 $k1 user@café']);

      expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-ed25519', k1)]);
      expect(outcome.message, contains('without its comment'));
      expect(logs.where((r) => r.message.contains('user@caf')), isEmpty);
    },
  );

  test(
    'the --sshpublickey-permissions value follows the loopback restriction',
    () async {
      await startDaemon(sshPublicKeyPermissions: 'no-pty');

      await send(['ssh-ed25519 $k1']);

      expect(authKeys.readAsLinesSync(), [
        loopbackLine('ssh-ed25519', k1, permissions: 'no-pty'),
      ]);
    },
  );

  test('a value holding two key lines changes nothing', () async {
    givenAuthorizedKeys('ssh-ed25519 $k0 user@laptop\n');
    final List<int> before = authKeys.readAsBytesSync();
    await startDaemon();

    final [outcome] = await send(['ssh-ed25519 $k1\nssh-ed25519 $k2']);

    expect(authKeys.readAsBytesSync(), before);
    expect(outcome.level, Level.WARNING);
    expect(outcome.message, contains(NoPortsHarness.clientAtSign));
  });

  test('a refused value is logged on one line', () async {
    await startDaemon();

    final [outcome] = await send(['ssh-ed25519 $k1\nsecond line']);

    expect(outcome.level, Level.WARNING);
    expect(outcome.message, isNot(contains('\n')));
    expect(outcome.message, contains('"ssh-ed25519 $k1\\nsecond line"'));
  });

  test(
    'a refused value over 200 characters is logged cut to 200 characters',
    () async {
      final String value = 'ssh-ed25519 $k1\n${'b' * 300}';
      await startDaemon();

      final [outcome] = await send([value]);

      final String shown = RegExp(
        r'"(.*)"$',
      ).firstMatch(outcome.message)!.group(1)!;
      expect(shown, hasLength(200));
      expect(shown, startsWith('ssh-ed25519 $k1\\nbbb'));
    },
  );

  test('sshnpd without --sshpublickey ignores a client\'s key', () async {
    givenAuthorizedKeys('ssh-ed25519 $k0 user@laptop\n');
    final List<int> before = authKeys.readAsBytesSync();
    await startDaemon(addSshPublicKeys: false);

    final [outcome] = await send(['ssh-ed25519 $k1']);

    expect(outcome.message, startsWith('Ignoring sshpublickey from'));
    expect(authKeys.readAsBytesSync(), before);
  });

  test(
    'a key sent to a device with no ~/.ssh is added to a new authorized_keys only its owner can read',
    () async {
      final Directory ssh = Directory('${harness.home.path}/.ssh');
      expect(ssh.existsSync(), isFalse);
      await startDaemon();

      await send(['ssh-ed25519 $k1']);

      expect(ssh.statSync().mode & 0x1ff, int.parse('700', radix: 8));
      expect(authKeys.statSync().mode & 0x1ff, int.parse('600', radix: 8));
      expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-ed25519', k1)]);
    },
    testOn: '!windows',
  );

  test('sshnpd starts on a device with no authorized_keys', () async {
    await startDaemon();
    final Future<AtNotification> heartbeat = alice.notificationService
        .subscribe(
          regex:
              'heartbeat\\.${NoPortsHarness.device}\\.${DefaultArgs.namespace}',
          shouldDecrypt: true,
        )
        .where((n) => n.from == NoPortsHarness.daemonAtSign)
        .first
        .timeout(const Duration(seconds: 10));

    await notifyDaemon('ping', 'ping');

    expect((await heartbeat).value, contains(NoPortsHarness.device));
    expect(authKeys.existsSync(), isFalse);
  });
}
