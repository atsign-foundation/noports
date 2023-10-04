import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';

mixin SSHNPLocalFileMixin on SSHNPImpl {
  late final String sshHomeDirectory;

  @override
  Future<void> init() async {
    if (!params.allowLocalFileSystem) {
      throw SSHNPError(
          'The current client type requires allowLocalFileSystem to be true: $runtimeType');
    }
    await super.init();
    if (initializedCompleter.isCompleted) return;
  }
}
