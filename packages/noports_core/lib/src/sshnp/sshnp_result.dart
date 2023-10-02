import 'dart:io';

import 'package:meta/meta.dart';
import 'package:socket_connector/socket_connector.dart';

abstract class SSHNPResult {}

class SSHNPSuccess implements SSHNPResult {}

class SSHNPFailure implements SSHNPResult {}

mixin SSHNPConnectionBean<Bean> on SSHNPResult {
  Bean? _connectionBean;

  @protected
  set connectionBean(Bean? connectionBean) {
    _connectionBean = connectionBean;
  }

  Bean? get connectionBean => _connectionBean;

  Future<void> killConnectionBean() async {
    if (_connectionBean is Process) {
      (_connectionBean as Process).kill();
    }

    if (_connectionBean is SocketConnector) {
      (_connectionBean as SocketConnector).close();
    }

    if (_connectionBean is Future) {
      await (_connectionBean as Future).then((value) {
        if (value is Process) {
          value.kill();
        }
        if (value is SocketConnector) {
          value.close();
        }
      });
    }
  }
}

const _optionsWithPrivateKey = [
  '-o StrictHostKeyChecking=accept-new',
  '-o IdentitiesOnly=yes'
];

class SSHNPError implements SSHNPFailure, Exception {
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

class SSHNPCommand<Bean> extends SSHNPSuccess with SSHNPConnectionBean<Bean> {
  final String command;
  final int localPort;
  final String? remoteUsername;
  final String host;
  final String? privateKeyFileName;

  final List<String> sshOptions;

  SSHNPCommand(
      {required this.localPort,
      required this.remoteUsername,
      required this.host,
      this.command = 'ssh',
      List<String>? localSshOptions,
      this.privateKeyFileName,
      Bean? connectionBean})
      : sshOptions = [
          if (shouldIncludePrivateKey(privateKeyFileName))
            ..._optionsWithPrivateKey,
          ...(localSshOptions ?? [])
        ] {
    this.connectionBean = connectionBean;
  }

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

class SSHNPNoOpSuccess<Bean> extends SSHNPSuccess
    with SSHNPConnectionBean<Bean> {
  SSHNPNoOpSuccess({Bean? connectionBean}) {
    this.connectionBean = connectionBean;
  }
}
