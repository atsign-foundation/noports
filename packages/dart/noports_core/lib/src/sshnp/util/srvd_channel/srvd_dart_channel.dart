import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/srvd_channel.dart';
import 'package:noports_core/srv.dart';

class SrvdDartBindPortChannel extends SrvdChannel<Future> {
  SrvdDartBindPortChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(srvGenerator: Srv.dart);
}

class SrvdDartSSHSocketChannel extends SrvdChannel<SSHSocket> {
  SrvdDartSSHSocketChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(srvGenerator: Srv.inline);
}
