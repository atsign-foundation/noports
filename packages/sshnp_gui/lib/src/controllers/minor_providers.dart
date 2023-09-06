import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

final sshnpParamsProvider = StateProvider<SSHNPParams>(
  (ref) => SSHNPParams(clientAtSign: '', sshnpdAtSign: '', host: '', legacyDaemon: true),
);

/// index for the config file that is being updated
final sshnpParamsUpdateIndexProvider = StateProvider<int>(
  (ref) => 0,
);

final configFileWriteStateProvider = StateProvider<ConfigFileWriteState>(
  (ref) => ConfigFileWriteState.create,
);
final terminalSSHCommandProvider = StateProvider<String>(
  (ref) => '',
);
