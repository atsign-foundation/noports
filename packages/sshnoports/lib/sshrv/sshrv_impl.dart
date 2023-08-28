part of 'sshrv.dart';

@visibleForTesting
class SSHRVImpl implements SSHRV<Process> {
  @override
  final String host;

  @override
  final int streamingPort;

  @override
  final int localSshdPort;

  const SSHRVImpl(
    this.host,
    this.streamingPort, {
    this.localSshdPort = SSHNP.defaultLocalSshdPort,
  });

  @override
  Future<Process> run() async {
    String? command = await SSHRV.getLocalBinaryPath();
    String postfix = Platform.isWindows ? '.exe' : '';
    if (command == null) {
      throw Exception(
        'Unable to locate sshrv$postfix binary.\n'
        'N.B. sshnp is expected to be compiled and run from source, not via the dart command.',
      );
    }
    return Process.start(
      command,
      [host, streamingPort.toString(), localSshdPort.toString()],
      mode: ProcessStartMode.detached,
    );
  }
}

@visibleForTesting
class SSHRVImplPureDart implements SSHRV<SocketConnector> {
  @override
  final String host;

  @override
  final int streamingPort;

  @override
  final int localSshdPort;

  const SSHRVImplPureDart(
    this.host,
    this.streamingPort, {
    this.localSshdPort = 22,
  });

  @override
  Future<SocketConnector> run() async {
    try {
      var hosts = await InternetAddress.lookup(host);

      return await SocketConnector.socketToSocket(
        socketAddressA: InternetAddress.loopbackIPv4,
        socketPortA: localSshdPort,
        socketAddressB: hosts[0],
        socketPortB: streamingPort,
        verbose: false,
      );
    } catch (e) {
      print('sshrv error: ${e.toString()}');
      rethrow;
    }
  }
}
