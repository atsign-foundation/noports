part of 'sshrv.dart';

String _getSshrvCommand() {
  late String sshnpDir;
  List<String> pathList =
      Platform.resolvedExecutable.split(Platform.pathSeparator);
  if (pathList.last == 'sshnp' || pathList.last == 'sshnp.exe') {
    pathList.removeLast();
    sshnpDir = pathList.join(Platform.pathSeparator);

    return '$sshnpDir${Platform.pathSeparator}sshrv';
  } else {
    throw Exception(
        'sshnp is expected to be run as a compiled executable, not via the dart command, use SSHRV.pureDart() to create SSHRV instead');
  }
}

@visibleForTesting
class SSHRVImpl implements SSHRV<ProcessResult> {
  @override
  final String host;

  @override
  final int streamingPort;

  const SSHRVImpl(this.host, this.streamingPort);

  @override
  Future<ProcessResult> run() {
    return Process.run(_getSshrvCommand(), [host, streamingPort.toString()]);
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
