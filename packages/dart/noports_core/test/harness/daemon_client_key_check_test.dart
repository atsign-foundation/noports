import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/npt.dart';
import 'package:noports_core/src/common/enrollment_signature.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:noports_core/srv.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'noports_harness.dart';

/// Signs with the enrollment [atClient] authenticated as.
class _Signer with ApkamSigning {
  _Signer(this.atClient);

  @override
  final AtClient atClient;

  @override
  final AtSignLogger logger = AtSignLogger('test signer');
}

void main() {
  const checkEvery = Duration(milliseconds: 200);

  /// A relay that doesn't check signing keys, a daemon checking its clients'
  /// enrollments every [check], and an npt tunnel from the client to a
  /// loopback echo server using [relayAuthMode].
  Future<({NoPortsHarness harness, SshnpdImpl daemon, int localPort})> tunnel({
    Duration check = checkEvery,
    RelayAuthMode relayAuthMode = RelayAuthMode.escr,
    bool requireEnrollmentSignature = false,
  }) async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay(signingKeyCheckInterval: Duration.zero);
    final daemon = await harness.startDaemon(
      permitOpen: ['127.0.0.1:${echo.port}'],
      clientKeyCheckInterval: check,
      requireEnrollmentSignature: requireEnrollmentSignature,
    );
    final npt = Npt.create(
      params: NptParams(
        clientAtSign: NoPortsHarness.clientAtSign,
        sshnpdAtSign: NoPortsHarness.daemonAtSign,
        srvdAtSign: NoPortsHarness.relayAtSign,
        remoteHost: '127.0.0.1',
        remotePort: echo.port,
        device: NoPortsHarness.device,
        localPort: 0,
        localHost: '127.0.0.1',
        inline: true,
        timeout: const Duration(seconds: 30),
        relayAuthMode: relayAuthMode,
      ),
      atClient: await harness.openClient(
        NoPortsHarness.clientAtSign,
        namespace: DefaultArgs.namespace,
      ),
    );
    addTearDown(npt.close);
    return (harness: harness, daemon: daemon, localPort: await npt.run());
  }

  /// Opens a connection through the tunnel at [localPort] and waits until it
  /// has carried bytes both ways; its `ended` completes when it ends.
  Future<({Future<void> ended})> liveConnection(int localPort) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, localPort);
    addTearDown(socket.destroy);
    final echoed = Completer<void>();
    final ended = Completer<void>();
    void end([_]) {
      if (!ended.isCompleted) ended.complete();
    }

    socket.listen(
      (_) {
        if (!echoed.isCompleted) echoed.complete();
      },
      onDone: end,
      onError: end,
    );
    socket.write('live');
    await echoed.future.timeout(const Duration(seconds: 10));
    return (ended: ended.future);
  }

  /// Whether a new connection through the tunnel at [localPort] carries
  /// [message] there and back within 5 seconds.
  Future<bool> roundTrips(int localPort, String message) async {
    try {
      final socket =
          await Socket.connect(InternetAddress.loopbackIPv4, localPort);
      addTearDown(socket.destroy);
      final received = StringBuffer();
      final gotAll = Completer<bool>();
      socket.listen(
        (bytes) {
          received.write(utf8.decode(bytes));
          if (received.length >= message.length && !gotAll.isCompleted) {
            gotAll.complete(received.toString() == message);
          }
        },
        onDone: () {
          if (!gotAll.isCompleted) gotAll.complete(false);
        },
        onError: (_) {
          if (!gotAll.isCompleted) gotAll.complete(false);
        },
      );
      socket.write(message);
      return await gotAll.future
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } on SocketException {
      return false;
    }
  }

  /// How many times the daemon has looked up the `_apsk` record the client's
  /// first enrollment publishes. After the request is verified, only the
  /// check looks it up again.
  int clientKeyLookups(NoPortsHarness harness) {
    final client = harness.server[NoPortsHarness.clientAtSign];
    final command = 'plookup:bypassCache:true:all:'
        '_apsk.${client.firstEnrollment.id}.a.__e${NoPortsHarness.clientAtSign}';
    return [
      for (final c in harness.server.connections)
        if (c.atSign.atSign == NoPortsHarness.daemonAtSign) ...c.commands,
    ].where((c) => c == command).length;
  }

  /// Waits until [condition] holds, failing after 10 seconds.
  Future<void> eventually(String what, bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  for (final mode in [RelayAuthMode.escr, RelayAuthMode.payload]) {
    test("the daemon ends a ${mode.name} tunnel once the client's enrollment"
        ' is revoked', () async {
      final (:harness, :daemon, :localPort) = await tunnel(relayAuthMode: mode);
      final connection = await liveConnection(localPort);
      expect(daemon.trackedClientSessions, 1,
          reason: "the daemon verified the client's enrollment signature");

      harness.server[NoPortsHarness.clientAtSign].firstEnrollment.revoke();

      await connection.ended.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('the open connection survived the revocation'),
      );
      expect(await roundTrips(localPort, 'after'), isFalse,
          reason: 'a new connection must not get through');
      await eventually('the daemon to stop tracking the session',
          () => daemon.trackedClientSessions == 0);
    });
  }

  test("with the daemon's check off, a revoked client's tunnel stays up",
      () async {
    final (:harness, :daemon, :localPort) = await tunnel(check: Duration.zero);
    final connection = await liveConnection(localPort);
    var ended = false;
    unawaited(connection.ended.then((_) => ended = true));

    harness.server[NoPortsHarness.clientAtSign].firstEnrollment.revoke();
    await Future.delayed(checkEvery * 10);

    expect(ended, isFalse, reason: 'something else ended the tunnel');
    expect(await roundTrips(localPort, 'still up'), isTrue);
  });

  test("the daemon keeps a tunnel whose client's key is still published,"
      ' re-checking it', () async {
    final (:harness, :daemon, :localPort) = await tunnel();
    final connection = await liveConnection(localPort);
    var ended = false;
    unawaited(connection.ended.then((_) => ended = true));
    final before = clientKeyLookups(harness);

    await eventually('two re-checks of the client\'s key',
        () => ended || clientKeyLookups(harness) - before >= 2);

    expect(ended, isFalse, reason: 'the daemon ended a tunnel it should keep');
    expect(await roundTrips(localPort, 'kept'), isTrue);
    expect(daemon.trackedClientSessions, 1);
  });

  test("the daemon keeps a tunnel while it can't reach the client's atServer",
      () async {
    final (:harness, :daemon, :localPort) = await tunnel();
    final connection = await liveConnection(localPort);
    var ended = false;
    unawaited(connection.ended.then((_) => ended = true));
    final before = clientKeyLookups(harness);

    harness.server[NoPortsHarness.clientAtSign].unreachable = true;
    await eventually('two failed re-checks of the client\'s key',
        () => ended || clientKeyLookups(harness) - before >= 2);

    expect(ended, isFalse,
        reason: 'the daemon ended a tunnel because a lookup failed');
    expect(await roundTrips(localPort, 'kept'), isTrue);
  });

  late NoPortsHarness harness;
  late AtClient alice;
  late StreamController<String> replies;

  /// A daemon, with [require], [inline] and [check] set as asked, and
  /// alice's client listening for its replies.
  Future<void> start({
    bool require = false,
    bool inline = true,
    Duration check = checkEvery,
  }) async {
    harness = NoPortsHarness.create();
    await harness.startDaemon(
      permitOpen: ['127.0.0.1:22'],
      requireEnrollmentSignature: require,
      inline: inline,
      clientKeyCheckInterval: check,
    );
    alice = await harness.openClient(
      NoPortsHarness.clientAtSign,
      namespace: DefaultArgs.namespace,
    );
    replies = StreamController.broadcast();
    final subscription = alice.notificationService
        .subscribe(
          regex: '${NoPortsHarness.device}\\.${DefaultArgs.namespace}',
          shouldDecrypt: true,
        )
        .where((n) => n.from == NoPortsHarness.daemonAtSign)
        .listen((n) => replies.add('${n.key} ${n.value}'));
    addTearDown(subscription.cancel);
  }

  /// An npt request for a fresh session to 127.0.0.1:22.
  Map<String, dynamic> payload(String sessionId) => NptSessionRequest(
        sessionId: sessionId,
        rvdHost: '127.0.0.1',
        rvdPort: 1,
        requestedHost: '127.0.0.1',
        requestedPort: 22,
        authenticateToRvd: false,
        relayAuthMode: RelayAuthMode.payload,
        relayAuthAesKey: null,
        clientNonce: 'client-nonce',
        rvdNonce: 'rvd-nonce',
        encryptRvdTraffic: false,
        clientEphemeralPK: RsaKeyPair.generate().atPublicKey.publicKey,
        clientEphemeralPKType: EncryptionKeyType.rsa2048.name,
        timeout: const Duration(seconds: 5),
        twinKeys: false,
        relayAtsign: null,
      ).toJson();

  /// The daemon's reply about [sessionId] once alice has sent it [envelope]
  /// as a request of type [type].
  Future<String> replyTo(
    String sessionId,
    String envelope, {
    String type = 'npt_request',
  }) async {
    final reply = replies.stream
        .firstWhere((r) => r.contains('$sessionId.'))
        .timeout(const Duration(seconds: 10));
    await alice.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey()
          ..key = type
          ..namespace = '${NoPortsHarness.device}.${DefaultArgs.namespace}'
          ..sharedBy = alice.getCurrentAtSign()
          ..sharedWith = NoPortsHarness.daemonAtSign
          ..metadata = (Metadata()..ttl = 10000),
        value: envelope,
      ),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );
    return reply;
  }

  const startFailed = 'Failed to start up the daemon side';

  group('requests', () {
    test('a request changed after its enrollment signature is refused, even'
        ' by a daemon that is not strict', () async {
      await start();
      final tampered = Uuid().v4();
      final genuine = Uuid().v4();
      final envelope = jsonDecode(
        await signAndWrapRequest(alice, _Signer(alice), payload(tampered)),
      );
      envelope['payload']['clientNonce'] = 'another-nonce';

      expect(
        await replyTo(tampered, jsonEncode(envelope)),
        contains('Enrollment signature not verified'),
      );
      expect(
        await replyTo(
          genuine,
          await signAndWrapRequest(alice, _Signer(alice), payload(genuine)),
        ),
        contains(startFailed),
      );
    });

    test("a request signed with another atSign's enrollment key is refused",
        () async {
      await start();
      const eve = '@eve';
      harness.server.addAtSign(eve);
      final eveClient = await harness.openClient(eve,
          namespace: DefaultArgs.namespace);
      final sessionId = Uuid().v4();
      final body = payload(sessionId);
      final envelope = await signAndWrap(alice, body);
      envelope[enrollmentSignatureField] =
          (await enrollmentSignatureOf(_Signer(eveClient), body))!;

      expect(
        await replyTo(sessionId, jsonEncode(envelope)),
        allOf(contains('Enrollment signature not verified'),
            contains('not the requester')),
      );
    });

    test('a daemon that requires an enrollment signature refuses a request'
        ' without one, and takes one with one', () async {
      await start(require: true);
      final unsigned = Uuid().v4();
      final signed = Uuid().v4();

      expect(
        await replyTo(
          unsigned,
          await signAndWrapAndJsonEncode(alice, payload(unsigned)),
        ),
        contains('requires session requests signed'),
      );
      expect(
        await replyTo(
          signed,
          await signAndWrapRequest(alice, _Signer(alice), payload(signed)),
        ),
        contains(startFailed),
      );
    });

    test('a daemon that requires an enrollment signature refuses a legacy'
        ' request, which has none', () async {
      await start(require: true);
      final sessionId = Uuid().v4();

      expect(
        await replyTo(
          sessionId,
          '1 1 harness 127.0.0.1 $sessionId',
          type: 'sshd',
        ),
        contains('requires session requests signed'),
      );
    });

    /// alice's signed request for [sessionId], with [fields] replacing those
    /// of its enrollment signature.
    Future<String> alteredRequest(
      String sessionId,
      Map<String, Object?> Function(Map<String, String>) fields,
    ) async {
      final body = payload(sessionId);
      final envelope = await signAndWrap(alice, body);
      final signature = (await enrollmentSignatureOf(_Signer(alice), body))!;
      envelope[enrollmentSignatureField] = {
        ...signature,
        ...fields(signature),
      };
      return jsonEncode(envelope);
    }

    /// alice's signed request for [sessionId], naming an `_apsk` record her
    /// atServer doesn't hold, so its signature can't be checked.
    Future<String> missingKeyRequest(String sessionId) =>
        alteredRequest(sessionId, (signature) => {
              'sk': signature['sk']!.replaceFirst(
                RegExp(r'_apsk\.[^.]+\.'),
                '_apsk.no-such-enrollment.',
              ),
            });

    test("a request whose enrollment signature can't be checked goes ahead"
        ' unwatched', () async {
      await start();
      final sessionId = Uuid().v4();

      expect(
        await replyTo(sessionId, await missingKeyRequest(sessionId)),
        contains(startFailed),
      );
      expect(harness.daemon!.trackedClientSessions, 0);
    });

    test('a daemon that requires an enrollment signature refuses a request'
        " whose signature it can't check", () async {
      await start(require: true);
      final sessionId = Uuid().v4();

      expect(
        await replyTo(sessionId, await missingKeyRequest(sessionId)),
        contains('Could not check the enrollment signature'),
      );
    });

    test("a signing key spelled with a variant of the requester's atSign is"
        ' refused', () async {
      await start();
      final sessionId = Uuid().v4();

      expect(
        await replyTo(
          sessionId,
          await alteredRequest(sessionId, (signature) => {
                'sk': signature['sk']!.replaceFirst(
                  NoPortsHarness.clientAtSign,
                  '@al.ice',
                ),
              }),
        ),
        allOf(
          contains('Enrollment signature not verified'),
          contains('not the requester'),
        ),
      );
    });

    test('an enrollment signature naming its key with something other than a'
        ' string is refused', () async {
      await start();
      final sessionId = Uuid().v4();

      expect(
        await replyTo(
          sessionId,
          await alteredRequest(sessionId, (_) => {'kid': 7}),
        ),
        contains('"kid" that is not a string'),
      );
    });
  });

  group('srv processes', () {
    late Directory bin;

    /// Whether process [pid] is still running.
    bool running(int pid) => Process.killPid(pid, ProcessSignal.sigcont);

    setUp(() {
      bin = Directory.systemTemp.createTempSync('srv_stand_in');
      addTearDown(() => bin.deleteSync(recursive: true));
      final srv = File('${bin.path}/srv')
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'echo \$\$ > "${bin.path}/pid"\n'
          "echo '${Srv.startedString}'\n"
          'exec sleep 300\n',
        );
      Process.runSync('chmod', ['+x', srv.path]);
      Srv.localBinaryPathOverride = srv.path;
      addTearDown(() => Srv.localBinaryPathOverride = null);
    });

    /// Has alice ask for a signed session, [sessionId] or a fresh one,
    /// returning the pid of the srv process the daemon starts for it.
    Future<int> session([String? sessionId]) async {
      sessionId ??= Uuid().v4();
      final reply = await replyTo(
        sessionId,
        await signAndWrapRequest(alice, _Signer(alice), payload(sessionId)),
      );
      expect(reply, isNot(contains(startFailed)));
      final pid = int.parse(File('${bin.path}/pid').readAsStringSync().trim());
      addTearDown(() {
        final command = Process.runSync('ps', ['-p', '$pid', '-o', 'command='])
            .stdout as String;
        if (command.contains('sleep 300')) Process.killPid(pid);
      });
      return pid;
    }

    test("the daemon ends a session's srv process once the client's"
        ' enrollment is revoked', () async {
      await start(inline: false);
      final pid = await session();
      expect(harness.daemon!.trackedClientSessions, 1);
      expect(running(pid), isTrue);

      harness.server[NoPortsHarness.clientAtSign].firstEnrollment.revoke();

      await eventually('the srv process to end', () => !running(pid));
      await eventually('the daemon to stop tracking the session',
          () => harness.daemon!.trackedClientSessions == 0);
    });

    test('the daemon refuses a request for a session id it is watching',
        () async {
      await start(inline: false);
      final sessionId = Uuid().v4();
      final pid = await session(sessionId);
      await harness.daemon!.atClient.delete(
        AtKey.fromString('$sessionId.session_mutexes.${DefaultArgs.namespace}'
            '${NoPortsHarness.daemonAtSign}'),
        deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true,
      );

      expect(
        await replyTo(
          sessionId,
          await signAndWrapRequest(alice, _Signer(alice), payload(sessionId)),
        ),
        contains('already live'),
      );
      expect(harness.daemon!.trackedClientSessions, 1);
      expect(running(pid), isTrue);
    });

    test('the daemon stops tracking a session whose srv process ends by'
        ' itself', () async {
      await start(inline: false, check: Duration.zero);
      final pid = await session();
      expect(harness.daemon!.trackedClientSessions, 1);

      Process.killPid(pid);

      await eventually('the daemon to stop tracking the session',
          () => harness.daemon!.trackedClientSessions == 0);
    });
  }, skip: Platform.isWindows ? 'srv is stood in by a shell script' : false);
}
