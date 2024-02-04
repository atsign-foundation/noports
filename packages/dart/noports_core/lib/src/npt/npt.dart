import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';

import '../common/default_args.dart';
import '../common/streaming_logging_handler.dart';

abstract interface class Npt {
  AtClient get atClient;

  int get remotePort;

  String get npdAtSign;

  String get rvdAtSign;

  String get device;

  bool get verbose;

  /// Yields a string every time something interesting happens with regards to
  /// progress towards establishing the connection.
  Stream<String>? get progressStream;

  /// - Sends request to rvd
  /// - Sends request to npd
  /// - Waits for success or error response, or time out after 10 secs
  /// - Run local srv which will bind to some port and connect to the rvd
  /// - Return the port which the local srv is bound to
  Future<int> run();

  factory Npt.create({
    required AtClient atClient,
    required int remotePort,
    required String npdAtSign,
    required String rvdAtSign,
    required String device,
    bool verbose = DefaultArgs.verbose,
    Stream<String>? logStream,
  }) {
    return _NptImpl(
      atClient: atClient,
      remotePort: remotePort,
      npdAtSign: npdAtSign,
      rvdAtSign: rvdAtSign,
      device: device,
      verbose: verbose,
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
  final int remotePort;
  @override
  final String npdAtSign;
  @override
  final String rvdAtSign;
  @override
  final String device;
  @override
  final bool verbose;

  static final StreamingLoggingHandler _slh =
      StreamingLoggingHandler(AtSignLogger.defaultLoggingHandler);

  final StreamController<String> _progressStreamController =
      StreamController<String>.broadcast();

  /// Yields a string every time something interesting happens with regards to
  /// progress towards establishing the connection.
  @override
  Stream<String>? get progressStream => _progressStreamController.stream;

  /// Yields every log message that is written to [stderr]
  final Stream<String>? logStream;

  NptBase({
    required this.atClient,
    required this.remotePort,
    required this.npdAtSign,
    required this.rvdAtSign,
    required this.device,
    this.verbose = DefaultArgs.verbose,
    this.logStream,
  }) {
    AtSignLogger.defaultLoggingHandler = _slh;
  }
}

class _NptImpl extends NptBase {
  _NptImpl({
    required super.atClient,
    required super.remotePort,
    required super.npdAtSign,
    required super.rvdAtSign,
    required super.device,
    super.verbose,
    super.logStream,
  });

  @override
  Future<int> run() async {
    // TODO: implement run
    throw UnimplementedError();
  }
}
