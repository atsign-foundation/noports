part of 'sshrv.dart';

@visibleForTesting
class SSHRVImpl implements SSHRV<ProcessResult> {
  @override
  final String host;

  @override
  final int streamingPort;

  const SSHRVImpl(this.host, this.streamingPort);

  @override
  Future<ProcessResult> run() async {
    String? command = await SSHRV.getLocalBinaryPath();
    if (command == null) {
      throw Exception('sshrv binary not found');
    }
    return Process.run(command, [host, streamingPort.toString()]);
  }
}

@visibleForTesting
class SSHRVImplPureDart implements SSHRV<SocketConnector> {
  @override
  final String host;

  @override
  final int streamingPort;

  const SSHRVImplPureDart(this.host, this.streamingPort);

  @override
  Future<SocketConnector> run() async {
    try {
      var hosts = await InternetAddress.lookup(host);

      return await SocketConnector.socketToSocket(
        socketAddressA: InternetAddress.loopbackIPv4,
        socketPortA: 22,
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
