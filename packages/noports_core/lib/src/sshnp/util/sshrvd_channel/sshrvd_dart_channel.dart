import 'package:noports_core/src/sshnp/util/sshrvd_channel/sshrvd_channel.dart';
import 'package:noports_core/sshrv.dart';

class SshrvdDartChannel extends SshrvdChannel {
  SshrvdDartChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
  }) : super(sshrvGenerator: SSHRV.dart);
}
