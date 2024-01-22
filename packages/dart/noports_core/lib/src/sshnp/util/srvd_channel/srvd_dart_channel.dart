import 'package:noports_core/src/sshnp/util/srvd_channel/srvd_channel.dart';
import 'package:noports_core/srv.dart';
import 'package:socket_connector/socket_connector.dart';

class SshrvdDartChannel extends SshrvdChannel<SocketConnector> {
  SshrvdDartChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(sshrvGenerator: Srv.dart);
}
