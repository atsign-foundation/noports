import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

final sshnpParamsProvider = StateProvider<SSHNPParams>(
  (ref) => SSHNPParams(clientAtSign: '', sshnpdAtSign: '', host: '', legacyDaemon: true),
);

final configFileWriteStateProvider = StateProvider<ConfigFileWriteState>(
  (ref) => ConfigFileWriteState.create,
);
