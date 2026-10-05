import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_client/sqlite.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'fake_atserver.dart';

/// A client, a daemon and a relay, each its own atSign on one
/// [FakeAtServer], with real NoPorts components on top, torn down after the
/// test that built them.
class NoPortsHarness {
  NoPortsHarness._(this.server, this.home);

  final FakeAtServer server;

  /// A home directory for the daemon, so nothing touches the real `~/.ssh`.
  final Directory home;

  static const clientAtSign = '@alice';
  static const daemonAtSign = '@bob';
  static const relayAtSign = '@relay';
  static const device = 'harness';

  /// A harness whose atSigns exist but whose daemon and relay aren't running.
  static NoPortsHarness create() {
    final server = FakeAtServer()
      ..addAtSign(clientAtSign)
      ..addAtSign(daemonAtSign)
      ..addAtSign(relayAtSign);
    final home = Directory.systemTemp.createTempSync('noports_harness');
    final harness = NoPortsHarness._(server, home);
    final loggingHandler = AtSignLogger.defaultLoggingHandler;
    addTearDown(() async {
      await harness._tearDown();
      AtSignLogger.defaultLoggingHandler = loggingHandler;
      home.deleteSync(recursive: true);
    });
    return harness;
  }

  final List<AtClient> _clients = [];
  SshnpdImpl? daemon;
  SrvdImpl? relay;

  /// A client for [atSign], authenticated as its first enrollment, under
  /// [posture].
  Future<AtClient> openClient(
    String atSign, {
    required String namespace,
    PqPosture posture = PqPosture.legacy,
    Set<SigningAlgoType>? dataSigningKeyAlgorithms,
  }) async {
    final fake = server[atSign];
    final client = await Atsign(atSign).open(
      keys: InMemoryAtKeysIo.holding(atSign, fake.firstEnrollment.keys),
      preference: AtClientPreference(
        posture: posture,
        dataSigningKeyAlgorithms: dataSigningKeyAlgorithms,
      )
        ..namespace = namespace
        ..rootDomain = 'fake.atserver.test'
        ..fetchOfflineNotifications = false,
      storage: InMemoryAtClientStorage(atSign: atSign),
      lookUps: server.lookUps,
      serviceFactory: server.serviceFactory,
    );
    _clients.add(client);
    return client;
  }

  /// Starts srvd on the relay atSign.
  Future<SrvdImpl> startRelay({
    PqPosture posture = PqPosture.legacy,
    Set<SigningAlgoType>? dataSigningKeyAlgorithms,
  }) async {
    final relay = this.relay = SrvdImpl(
      atClient: await openClient(
        relayAtSign,
        namespace: Srvd.namespace,
        posture: posture,
        dataSigningKeyAlgorithms: dataSigningKeyAlgorithms,
      ),
      atSign: relayAtSign.toAtsign(),
      homeDirectory: home.path,
      atKeysFilePath: home.path,
      managerAtsign: 'open',
      ipAddress: '127.0.0.1',
      logTraffic: false,
      verbose: false,
      bind443: false,
      localBindPort443: 443,
      relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
    );
    await relay.init();
    await relay.run();
    return relay;
  }

  /// Starts sshnpd on the daemon atSign, managed by the client atSign and
  /// permitted to open [permitOpen]. With [advertisesEscr] false it tells
  /// clients it predates ESCR relay authentication, as an old daemon does.
  Future<SshnpdImpl> startDaemon({
    required List<String> permitOpen,
    bool advertisesEscr = true,
    PqPosture posture = PqPosture.legacy,
    bool postQuantum = false,
    Set<SigningAlgoType>? dataSigningKeyAlgorithms,
  }) async {
    final daemon = this.daemon = SshnpdImpl(
      atClient: await openClient(
        daemonAtSign,
        namespace: DefaultArgs.namespace,
        posture: posture,
        dataSigningKeyAlgorithms: dataSigningKeyAlgorithms,
      ),
      username: 'harness',
      homeDirectory: home.path,
      device: device,
      managerAtsigns: [clientAtSign],
      policyManagerAtsign: null,
      sshClient: SupportedSshClient.openssh,
      makeDeviceInfoVisible: false,
      addSshPublicKeys: false,
      localSshdPort: 22,
      sshPublicKeyPermissions: '',
      ephemeralPermissions: '',
      sshAlgorithm: SupportedSshAlgorithm.ed25519,
      deviceGroup: 'default',
      version: '1.0.0',
      permitOpen: permitOpen,
      strict: false,
      inline: true,
      postQuantum: postQuantum,
    );
    (daemon.pingResponse['supportedFeatures'] as Map)[
        DaemonFeature.supportsRamEscr.name] = advertisesEscr;
    await daemon.init();
    await daemon.run();
    return daemon;
  }

  Future<void> _tearDown() async {
    await daemon?.stop();
    await relay?.stop();
    for (final client in _clients.reversed) {
      await client.stop();
    }
  }
}

/// A loopback server that writes back whatever it reads, closed after the
/// test that started it.
Future<ServerSocket> startEchoServer() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((socket) => socket.listen(socket.add, onDone: socket.destroy));
  addTearDown(server.close);
  return server;
}
