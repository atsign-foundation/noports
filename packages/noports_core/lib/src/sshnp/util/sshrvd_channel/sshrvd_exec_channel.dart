import 'package:noports_core/src/sshnp/util/sshrvd_channel/sshrvd_channel.dart';
import 'package:noports_core/sshrv.dart';

class SshrvdExecChannel extends SshrvdChannel {
  SshrvdExecChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(sshrvGenerator: Sshrv.exec);
}
