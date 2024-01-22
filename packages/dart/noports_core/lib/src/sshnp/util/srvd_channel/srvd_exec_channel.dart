import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/srvd_channel.dart';
import 'package:noports_core/srv.dart';

class SrvdExecChannel extends SrvdChannel<Process> {
  SrvdExecChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(srvGenerator: Srv.exec);
}
