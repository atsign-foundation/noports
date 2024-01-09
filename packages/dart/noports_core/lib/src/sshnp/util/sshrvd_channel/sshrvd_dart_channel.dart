import 'package:noports_core/src/sshnp/util/sshrvd_channel/sshrvd_channel.dart';
import 'package:noports_core/sshrv.dart';
import 'package:socket_connector/socket_connector.dart';

class SshrvdDartChannel extends SshrvdChannel<SocketConnector> {
  SshrvdDartChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(sshrvGenerator: Sshrv.dart);
}
