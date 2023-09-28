import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

abstract class SSHNPResult {}

const _optionsWithPrivateKey = [
  '-o StrictHostKeyChecking=accept-new',
  '-o IdentitiesOnly=yes'
];

class SSHNPError implements SSHNPResult, Exception {
  final Object message;
  final Object? error;
  final StackTrace? stackTrace;

  SSHNPError(this.message, {this.error, this.stackTrace});

  @override
  String toString() {
    return message.toString();
  }

  String toVerboseString() {
    final sb = StringBuffer();
    sb.write(message);
    if (error != null) {
      sb.write('\n');
      sb.write('Error: $error');
    }
    if (stackTrace != null) {
      sb.write('\n');
      sb.write('Stack Trace: $stackTrace');
    }
    return sb.toString();
  }
}

class SSHNPSuccess implements SSHNPResult {
  final String command = 'ssh';

  final int localPort;
  final String? remoteUsername;
  final String host;
  final String? privateKeyFileName;

  final List<String> sshOptions;

  Future? sshrvResult;
  Process? sshProcess;
  SSHClient? sshClient;

  SSHNPSuccess.base({
    required this.localPort,
    required this.remoteUsername,
    required this.host,
    List<String>? localSshOptions,
    this.privateKeyFileName,
    this.sshrvResult,
    this.sshProcess,
    this.sshClient,
  }) : sshOptions = [
          if (shouldIncludePrivateKey(privateKeyFileName))
            ..._optionsWithPrivateKey,
          ...(localSshOptions ?? [])
        ];

  static bool shouldIncludePrivateKey(String? privateKeyFileName) =>
      privateKeyFileName != null && privateKeyFileName.isNotEmpty;

  List<String> get args => [
        '-p $localPort',
        ...sshOptions,
        if (remoteUsername != null) '$remoteUsername@$host',
        if (remoteUsername == null) host,
        if (shouldIncludePrivateKey(privateKeyFileName)) ...[
          '-i',
          '$privateKeyFileName'
        ],
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
