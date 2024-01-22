import 'package:noports_core/src/sshnp/util/srvd_channel/srvd_channel.dart';
import 'package:noports_core/srv.dart';
import 'package:socket_connector/socket_connector.dart';

class SrvdDartChannel extends SrvdChannel<SocketConnector> {
  SrvdDartChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(srvGenerator: Srv.dart);
}
