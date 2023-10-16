part of 'sshnp.dart';

abstract class SSHNPResult {}

abstract class SSHNPCommandResult implements SSHNPResult {
  String get command;
  List<String> get args;
}

const _optionsWithPrivateKey = ['-o StrictHostKeyChecking=accept-new', '-o IdentitiesOnly=yes'];

class SSHNPFailed implements SSHNPResult {
  final String message;
  final Object? exception;
  final StackTrace? stackTrace;

  SSHNPFailed(this.message, [this.exception, this.stackTrace]);

  @override
  String toString() {
    return message;
  }
}

class SSHCommand implements SSHNPCommandResult {
  @override
  final String command = 'ssh';

  final int localPort;
  final String? remoteUsername;
  final String host;
  final String? privateKeyFileName;

  final List<String> sshOptions;

  Future? sshrvResult;
  Process? sshProcess;
  SSHClient? sshClient;

  SSHCommand.base({
    required this.localPort,
    required this.remoteUsername,
    required this.host,
    List<String>? localSshOptions,
    this.privateKeyFileName,
    this.sshrvResult,
    this.sshProcess,
    this.sshClient,
  }) : sshOptions = [
          if (shouldIncludePrivateKey(privateKeyFileName)) ..._optionsWithPrivateKey,
          ...(localSshOptions ?? [])
        ];

  static bool shouldIncludePrivateKey(String? privateKeyFileName) =>
      privateKeyFileName != null && privateKeyFileName.isNotEmpty;

  @override
  List<String> get args => [
        '-p $localPort',
        ...sshOptions,
        if (remoteUsername != null) '$remoteUsername@$host',
        if (remoteUsername == null) host,
        if (shouldIncludePrivateKey(privateKeyFileName)) ...['-i', '$privateKeyFileName'],
      ];

  @override
  String toString() {
    final sb = StringBuffer();
    sb.write(command);
    sb.write(' ');
    sb.write(args.join(' '));
    return sb.toString();
  }
}
