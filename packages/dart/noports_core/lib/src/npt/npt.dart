import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:uuid/uuid.dart';

import '../common/features.dart';
import '../common/mixins/async_completion.dart';
import '../common/mixins/async_initialization.dart';
import '../common/mixins/at_client_bindings.dart';
import '../common/streaming_logging_handler.dart';
import '../sshnp/impl/notification_request_message.dart';
import '../sshnp/util/srvd_channel/srvd_exec_channel.dart';
import '../sshnp/util/sshnpd_channel/sshnpd_channel.dart';
import '../sshnp/util/sshnpd_channel/sshnpd_default_channel.dart';

abstract interface class Npt {
  AtClient get atClient;

  NptParams get params;

  String get sessionId;

  String get namespace;

  /// Yields a string every time something interesting happens with regards to
  /// progress towards establishing the connection.
  Stream<String>? get progressStream;

  /// Yields every log message that is written to [stderr]
  Stream<String>? get logStream;

  /// - Sends request to rvd
  /// - Sends request to npd
  /// - Waits for success or error response, or time out after 10 secs
  /// - Run local srv which will bind to some port and connect to the rvd
  /// - Return the port which the local srv is bound to
  Future<int> run();

  factory Npt.create({
    required NptParams params,
    required AtClient atClient,
    Stream<String>? logStream,
  }) {
    return _NptImpl(
      params: params,
      atClient: atClient,
      logStream: logStream,
    );
  }

  static ArgParser createArgParser() {
    ArgParser parser = ArgParser(
      usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : null,
      showAliasesInUsage: true,
    );
    return parser;
  }
}

abstract class NptBase implements Npt {
  @override
  final AtClient atClient;

  @override
  final NptParams params;

  @override
  final String sessionId;

  @override
  final String namespace;

  static final StreamingLoggingHandler _slh =
      StreamingLoggingHandler(AtSignLogger.defaultLoggingHandler);

  final StreamController<String> _progressStreamController =
      StreamController<String>.broadcast();

  /// Subclasses should use this method to generate progress messages
  sendProgress(String message) {
    _progressStreamController.add(message);
  }

  /// Yields a string every time something interesting happens with regards to
  /// progress towards establishing the connection.
  @override
  Stream<String>? get progressStream => _progressStreamController.stream;

  /// Yields every log message that is written to [stderr]
  @override
  final Stream<String>? logStream;

  final logger = AtSignLogger(' Npt ');

  NptBase({
    required this.params,
    required this.atClient,
    this.logStream,
  })  : sessionId = Uuid().v4(),
        namespace = '${params.device}.${DefaultArgs.namespace}' {
    AtSignLogger.defaultLoggingHandler = _slh;
    logger.level = params.verbose ? 'info' : 'shout';

    /// Set the namespace to the device's namespace
    AtClientPreference preference =
        atClient.getPreferences() ?? AtClientPreference();
    preference.namespace = namespace;
    atClient.setPreferences(preference);
  }
}

class _NptImpl extends NptBase
    with AsyncInitialization, AsyncDisposal, AtClientBindings {
  SshnpdDefaultChannel get sshnpdChannel => _sshnpdChannel;
  late final SshnpdDefaultChannel _sshnpdChannel;

  SrvdExecChannel get srvdChannel => _srvdChannel;
  late final SrvdExecChannel _srvdChannel;

  _NptImpl({
    required super.params,
    required super.atClient,
    super.logStream,
  }) {
    _sshnpdChannel = SshnpdDefaultChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
      namespace: namespace,
    );
    _srvdChannel = SrvdExecChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
    );
  }

  @override
  Future<void> dispose() async {
    completeDisposal();
  }

  @override
  @mustCallSuper
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;

    logger.info('Initializing $runtimeType');

    /// Start the sshnpd payload handler
    await sshnpdChannel.callInitialization();

    List<DaemonFeature> requiredFeatures = [
      DaemonFeature.srAuth,
      DaemonFeature.srE2ee,
      DaemonFeature.supportsPortChoice,
    ];
    sendProgress('Sending daemon feature check request');

    Future<List<(DaemonFeature feature, bool supported, String reason)>>
        featureCheck = sshnpdChannel.featureCheck(requiredFeatures);

    /// Retrieve the srvd host and port pair
    sendProgress('Fetching host and port from srvd');
    await srvdChannel.callInitialization();
    sendProgress('Received host and port from srvd');

    sendProgress('Waiting for daemon feature check response');
    List<(DaemonFeature, bool, String)> features = await featureCheck;
    sendProgress('Received daemon feature check response');
    await Future.delayed(Duration(milliseconds: 1));
    for (final (DaemonFeature _, bool supported, String reason) in features) {
      if (!supported) throw SshnpError(reason);
    }
    sendProgress('Required daemon features are supported');
  }

  @override
  Future<int> run() async {
    /// Ensure that sshnp is initialized
    await callInitialization();

    var msg = 'Sending session request to the device daemon';
    logger.info(msg);
    sendProgress(msg);

    /// Send an ssh request to sshnpd
    await notify(
      AtKey()
        ..key = 'ssh_request'
        ..namespace = namespace
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000),
      signAndWrapAndJsonEncode(
          atClient,
          SshnpSessionRequest(
            direct: true,
            sessionId: sessionId,
            host: srvdChannel.rvdHost,
            port: srvdChannel.daemonPort,
            authenticateToRvd: params.authenticateDeviceToRvd,
            clientNonce: srvdChannel.clientNonce,
            rvdNonce: srvdChannel.rvdNonce,
            encryptRvdTraffic: params.encryptRvdTraffic,
            clientEphemeralPK: params.sessionKP.atPublicKey.publicKey,
            clientEphemeralPKType: params.sessionKPType.name,
            remotePort: params.remotePort,
          ).toJson()),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );

    /// Wait for a response from sshnpd
    sendProgress('Waiting for response from the device daemon');
    var acked = await sshnpdChannel.waitForDaemonResponse();
    if (acked != SshnpdAck.acknowledged) {
      throw SshnpError('No response from the device daemon');
    } else {
      sendProgress('Received response from the device daemon');
    }

    if (sshnpdChannel.ephemeralPrivateKey == null) {
      throw SshnpError(
        'Expected an ephemeral private key from sshnpd, but it was not set',
      );
    }

    /// Find a port to use
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    int localRvPort = server.port;
    await server.close();

    /// Start srv
    sendProgress('Creating connection to socket rendezvous');
    await srvdChannel.runSrv(
      localRvPort: localRvPort,
      sessionAESKeyString: sshnpdChannel.sessionAESKeyString,
      sessionIVString: sshnpdChannel.sessionIVString,
    );

    return localRvPort;
  }
}
