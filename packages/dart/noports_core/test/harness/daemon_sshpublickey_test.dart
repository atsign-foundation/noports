import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
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

/// Keeps every record the loggers created while it is the default handler
/// are handed.
class _Records implements LoggingHandler {
  final List<LogRecord> records = [];

  @override
  void call(LogRecord record) => records.add(record);
}

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

  /// Starts the daemon, returning what its logger logged while it was
  /// being constructed.
  Future<List<LogRecord>> startDaemon({
    bool addSshPublicKeys = true,
    String sshPublicKeyPermissions = '',
  }) async {
    final LoggingHandler handler = AtSignLogger.defaultLoggingHandler;
    final _Records startup = _Records();
    AtSignLogger.defaultLoggingHandler = startup;
    try {
      daemon = await harness.startDaemon(
        permitOpen: ['localhost:22'],
        addSshPublicKeys: addSshPublicKeys,
        sshPublicKeyPermissions: sshPublicKeyPermissions,
      );
    } finally {
      AtSignLogger.defaultLoggingHandler = handler;
    }
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
    return startup.records
        .where((r) => r.loggerName == daemon.logger.logger.name)
        .toList();
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

  /// Checks that the daemon replies to a ping with a heartbeat.
  Future<void> expectRunning() async {
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
    'a key whose comment holds a character outside ASCII, or is over 256 characters, is added without it',
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
    'a key whose comment holds a non-ASCII character is added without it',
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

  test(
    'sshnpd leaves a from= option out of the --sshpublickey-permissions value, with a warning',
    () async {
      final List<LogRecord> startup = await startDaemon(
        sshPublicKeyPermissions: 'from="10.0.0.0/8",no-pty',
      );

      await send(['ssh-ed25519 $k1']);

      expect(authKeys.readAsLinesSync(), [
        loopbackLine('ssh-ed25519', k1, permissions: 'no-pty'),
      ]);
      expect(
        startup.where((r) => r.level == Level.WARNING).map((r) => r.message),
        [
          'Leaving the from= option out of the ssh public key permissions:'
              ' sshnpd sets the from= option itself.',
        ],
      );
    },
  );

  test('sshnpd leaves a from= option out however it is cased', () async {
    await startDaemon(sshPublicKeyPermissions: 'FROM="10.0.0.0/8"');

    await send(['ssh-ed25519 $k1']);

    expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-ed25519', k1)]);
  });

  test(
    'sshnpd without --sshpublickey starts with a from= option in --sshpublickey-permissions',
    () async {
      final List<LogRecord> startup = await startDaemon(
        addSshPublicKeys: false,
        sshPublicKeyPermissions: 'from="10.0.0.0/8"',
      );

      await expectRunning();

      expect(
        startup.where((r) => r.level == Level.WARNING).map((r) => r.message),
        [contains('Leaving the from= option out')],
      );
    },
  );

  test(
    'a direct caller\'s permissions are treated as the command line\'s',
    () async {
      final List<LogRecord> startup = await startDaemon(
        sshPublicKeyPermissions: ' no-pty,,From="10.0.0.0/8" ',
      );

      expect(daemon.sshPublicKeyPermissions, 'no-pty');
      expect(startup.where((r) => r.level == Level.WARNING), hasLength(1));
      expect(
        () => SshnpdImpl(
          atClient: daemon.atClient,
          username: 'harness',
          homeDirectory: harness.home.path,
          device: NoPortsHarness.device,
          managerAtsigns: [NoPortsHarness.clientAtSign],
          sshClient: SupportedSshClient.openssh,
          sshPublicKeyPermissions: 'no-pty\nssh-ed25519 $k2',
          ephemeralPermissions: '',
          sshAlgorithm: SupportedSshAlgorithm.ed25519,
          deviceGroup: 'default',
          version: '1.0.0',
          permitOpen: ['localhost:22'],
          strict: false,
          clientKeyCheckInterval: const Duration(seconds: 10),
          requireEnrollmentSignature: false,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Detected newline characters'),
          ),
        ),
      );
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

  test(
    'a value whose key data is not of its stated key type changes nothing',
    () async {
      givenAuthorizedKeys('ssh-ed25519 $k0 user@laptop\n');
      final List<int> before = authKeys.readAsBytesSync();
      await startDaemon();

      final [outcome] = await send(['ssh-ed25519 $r1']);

      expect(authKeys.readAsBytesSync(), before);
      expect(
        outcome.message,
        startsWith(
          'Refusing the sshpublickey from ${NoPortsHarness.clientAtSign},'
          ' as its key data is not of its stated key type',
        ),
      );
    },
  );

  test(
    'a value with a key type outside the supported list changes nothing',
    () async {
      givenAuthorizedKeys('ssh-ed25519 $k0 user@laptop\n');
      final List<int> before = authKeys.readAsBytesSync();
      await startDaemon();

      final [outcome] = await send(['ssh-dss $k1']);

      expect(authKeys.readAsBytesSync(), before);
      expect(
        outcome.message,
        contains('its key type is not one sshnpd accepts'),
      );
    },
  );

  test('a value over 8 KiB changes nothing', () async {
    givenAuthorizedKeys('ssh-ed25519 $k0 user@laptop\n');
    final List<int> before = authKeys.readAsBytesSync();
    final String value = 'ssh-ed25519 $k1 '.padRight(8193, 'a');
    expect(value.length, 8193);
    await startDaemon();

    final [outcome] = await send([value]);

    expect(authKeys.readAsBytesSync(), before);
    expect(outcome.message, contains('as it is over 8192 bytes'));
  });

  test('a value of exactly 8 KiB is added', () async {
    await startDaemon();

    await send(['ssh-ed25519 $k1 '.padRight(8192, 'a')]);

    expect(authKeys.readAsLinesSync(), [loopbackLine('ssh-ed25519', k1)]);
  });

  test(
    'a refused value on a device with no ~/.ssh leaves no ~/.ssh behind',
    () async {
      final Directory ssh = Directory('${harness.home.path}/.ssh');
      await startDaemon();
      expect(ssh.existsSync(), isFalse);

      final [outcome] = await send(['ssh-ed25519 $r1']);

      expect(outcome.message, startsWith('Refusing the sshpublickey from'));
      expect(ssh.existsSync(), isFalse);
    },
  );

  test(
    'a key already on a line without the loopback restriction is left as it is, with a warning',
    () async {
      givenAuthorizedKeys('ssh-ed25519 $k1 user@laptop\n');
      final List<int> before = authKeys.readAsBytesSync();
      await startDaemon();

      final [outcome] = await send(['ssh-ed25519 $k1']);

      expect(authKeys.readAsBytesSync(), before);
      expect(outcome.level, Level.WARNING);
      expect(
        outcome.message,
        'The ssh public key from ${NoPortsHarness.clientAtSign} is already in'
        ' authorized_keys on a line without the loopback from= option,'
        ' which sshnpd leaves as it is',
      );
    },
  );

  test('a key already on a loopback-only line is logged at info', () async {
    givenAuthorizedKeys('${loopbackLine('ssh-ed25519', k1)}\n');
    await startDaemon();

    final [outcome] = await send(['ssh-ed25519 $k1']);

    expect(outcome.level, Level.INFO);
    expect(outcome.message, contains('is already in authorized_keys'));
  });

  test(
    'a refused value shows quotes, backslashes and non-ASCII bytes escaped',
    () async {
      await startDaemon();

      final [outcome] = await send([
        'ssh-ed25519 $k1\n", as it is from @bob: "x\\ caf\u00e9',
      ]);

      expect(
        outcome.message,
        'Refusing the sshpublickey from ${NoPortsHarness.clientAtSign},'
        ' as it holds a control character:'
        ' "ssh-ed25519 $k1\\n\\", as it is from @bob: \\"x\\\\ caf\\xc3\\xa9"',
      );
    },
  );

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

    await expectRunning();

    expect(authKeys.existsSync(), isFalse);
  });
}
