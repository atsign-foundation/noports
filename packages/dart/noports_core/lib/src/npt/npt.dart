import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/srvd_exec_channel.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:uuid/uuid.dart';

import '../common/features.dart';
import '../common/mixins/async_completion.dart';
import '../common/mixins/async_initialization.dart';
import '../common/mixins/at_client_bindings.dart';
import '../common/streaming_logging_handler.dart';
import '../sshnp/impl/notification_request_message.dart';
import '../sshnp/util/srvd_channel/srvd_channel.dart';
import '../sshnp/util/srvd_channel/srvd_dart_channel.dart';
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

  /// - Sends request to rvd
  /// - Sends request to npd
  /// - Waits for success or error response, or time out after 10 secs
  /// - Run local srv which will bind to some port and connect to the rvd
  /// - Return the SocketConnector created by Npt
  Future<SocketConnector> runInline({int? localRvPort});

  Future<void> close();

  Future get done;

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

  late final SrvdChannel _srvdChannel;

  final Completer _completer = Completer();

  @override
  Future get done => _completer.future;

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
    if (params.inline) {
      _srvdChannel = SrvdDartBindPortChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
      );
    } else {
      _srvdChannel = SrvdExecChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
      );
    }
  }

  @override
  Future<void> dispose() async {
    completeDisposal();
  }

  @override
  Future<void> close() async {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
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
    if (!(params.timeout == DefaultArgs.srvTimeout)) {
      requiredFeatures.add(DaemonFeature.adjustableTimeout);
    }
    logger.info('Sending daemon feature check request');
    sendProgress('Sending daemon feature check request');

    Future<List<(DaemonFeature feature, bool supported, String reason)>>
        featureCheckFuture = sshnpdChannel.featureCheck(requiredFeatures,
            timeout: params.daemonPingTimeout);

    /// Retrieve the srvd host and port pair
    sendProgress('Fetching host and port from srvd');
    await _srvdChannel.callInitialization();
    sendProgress('Received host and port from srvd');

    sendProgress('Waiting for daemon feature check response');
    List<(DaemonFeature, bool, String)> features = await featureCheckFuture;
    sendProgress('Received daemon feature check response');

    await Future.delayed(Duration(milliseconds: 1));
    for (final (DaemonFeature _, bool supported, String reason) in features) {
      if (!supported) {
        if (reason.contains('timed out')) {
          throw TimeoutException('Ping to NoPorts daemon timed out');
        } else {
          throw SshnpError(reason);
        }
      }
    }
    sendProgress('Required daemon features are supported');

    completeInitialization();
  }

  /// Shared setup log for [run] and [runInline]
  /// returns [localRvPort]
  Future<int> _preRun() async {
    /// Ensure that npt is initialized
    await callInitialization();

    var msg = 'Sending session request to the device daemon';
    logger.info(msg);
    sendProgress(msg);

    /// Send an ssh request to sshnpd
    await notify(
      AtKey()
        ..key = 'npt_request'
        ..namespace = namespace
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000),
      signAndWrapAndJsonEncode(
          atClient,
          NptSessionRequest(
            sessionId: sessionId,
            rvdHost: _srvdChannel.rvdHost,
            rvdPort: _srvdChannel.daemonPort,
            authenticateToRvd: params.authenticateDeviceToRvd,
            clientNonce: _srvdChannel.clientNonce,
            rvdNonce: _srvdChannel.rvdNonce!,
            encryptRvdTraffic: params.encryptRvdTraffic,
            clientEphemeralPK: params.sessionKP.atPublicKey.publicKey,
            clientEphemeralPKType: params.sessionKPType.name,
            requestedPort: params.remotePort,
            requestedHost: params.remoteHost,
            timeout: params.timeout,
          ).toJson()),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    );

    /// Wait for a response from sshnpd
    sendProgress('Waiting for response from the device daemon');
    SshnpdAck ack = await sshnpdChannel.waitForDaemonResponse();
    switch (ack) {
      case SshnpdAck.acknowledged:
        sendProgress('Received response from the device daemon');
      case SshnpdAck.acknowledgedWithErrors:
        throw SshnpError('Received error response from the device daemon');
      case SshnpdAck.notAcknowledged:
        throw SshnpError('No response from the device daemon');
    }

    int localRvPort;
    if (params.localPort == 0) {
      sendProgress('Finding an available local port');

      /// Find a port to use
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      localRvPort = server.port;
      await server.close();
    } else {
      sendProgress('Will use local port ${params.localPort}');

      localRvPort = params.localPort;
    }

    return localRvPort;
  }

  @override
  Future<int> run() async {
    int localRvPort = await _preRun();

    /// Start srv
    if (params.inline) {
      // not detached
      await runInline(localRvPort: localRvPort);
    } else {
      sendProgress('Creating connection to socket rendezvous');

      await _srvdChannel.runSrv(
        localRvPort: localRvPort,
        sessionAESKeyString: sshnpdChannel.sessionAESKeyString,
        sessionIVString: sshnpdChannel.sessionIVString,
        multi: true,
        detached: true,
        timeout: params.timeout,
      );
      _completer.complete();
    }

    return localRvPort;
  }

  @override
  Future<SocketConnector> runInline({int? localRvPort}) async {
    localRvPort ??= await _preRun();
    sendProgress('Creating connection to socket rendezvous');
    if (!params.inline) {
      logger.warning(
          "WAT - runInline() was called but params.inline = false, running under the assumption that params.inline was meant to be true.");
    }

    SocketConnector sc = await _srvdChannel.runSrv(
      localRvPort: localRvPort,
      sessionAESKeyString: sshnpdChannel.sessionAESKeyString,
      sessionIVString: sshnpdChannel.sessionIVString,
      multi: true,
      detached: false,
      timeout: params.timeout,
    );

    unawaited(sc.done.then((_) {
      logger.info('SocketConnector done');
      _completer.complete();
    }));

    return sc;
  }
}
