import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

final sshnpPartialParamsProvider = StateProvider<SSHNPPartialParams>(
  (ref) => SSHNPPartialParams(),
);

final configFileWriteStateProvider = StateProvider<ConfigFileWriteState>(
  (ref) => ConfigFileWriteState.create,
);
final terminalSSHCommandProvider = StateProvider<String>(
  (ref) => '',
);
