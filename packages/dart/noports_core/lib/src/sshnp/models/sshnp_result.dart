import 'package:meta/meta.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:socket_connector/socket_connector.dart';

import '../../common/noports_exception.dart';

abstract class SshnpResult {}

class SshnpSuccess implements SshnpResult {}

class SshnpFailure implements SshnpResult {}

// This is a mixin class instead of a mixin on SshnpResult so that it can be tested independently
mixin class SshnpConnectionBean<Bean> {
  Bean? _connectionBean;

  @protected
  @visibleForTesting
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
      final value = await (_connectionBean as Future);

      if (value is Process) {
        value.kill();
      }

      if (value is SocketConnector) {
        value.close();
      }
    }
  }
}

@visibleForTesting
const optionsWithPrivateKey = [
  '-o StrictHostKeyChecking=accept-new',
  '-o IdentitiesOnly=yes'
];

class SshnpError extends SshnpException implements SshnpFailure {
  SshnpError(super.message, {super.error, super.stackTrace});
}

class SshnpCommand<Bean> extends SshnpSuccess with SshnpConnectionBean<Bean> {
  final String command;
  final int localPort;
  final String? remoteUsername;
  final String host;
  final String? privateKeyFileName;

  final List<String> sshOptions;

  SshnpCommand({
    required this.localPort,
    required this.host,
    this.remoteUsername,
    this.command = 'ssh',
    List<String>? localSshOptions,
    this.privateKeyFileName,
    Bean? connectionBean,
  }) : sshOptions = [
          if (shouldIncludePrivateKey(privateKeyFileName))
            ...optionsWithPrivateKey,
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

class SshnpNoOpSuccess<Bean> extends SshnpSuccess
    with SshnpConnectionBean<Bean> {
  String? message;
  SshnpNoOpSuccess({this.message, Bean? connectionBean}) {
    this.connectionBean = connectionBean;
  }

  @override
  String toString() {
    return message ?? 'Connection Established';
  }
}
