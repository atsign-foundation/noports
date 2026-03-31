import 'package:e2e_all_v2/client_binaries.dart';

Future<void> runCoreTestCases({required final String testRunId}) async {

  // Goals:
  // 1. Set up Client binaries put them in a $testId/$version/* folder
  //  (v5.9.4, v5.11.2, v5.13.0, current)
  //  for versions, download from github.com/atsign-foundation/noports/releases
  //  for current, compile dart binaries using `dart compile exe`
  // 2. Set up the Docker daemons
  //  run Dart (current), v5.9.4, v5.11.2, v5.13.0, and C (current) in Docker containers
  // 3. Run tests via executing Client binaries, and save logs 

  // assume Dart
  const List<String> clientVersions = [
    'v5.9.4',
    'v5.11.2',
    'v5.13.0',
    'current',
  ];

  ClientBinaryManager clientBinaryManager = 
    ClientBinaryManager(testRunId: testRunId);

  List<(ClientBinaryType, ClientLanguage, String)> requiredBinaries = [];
  requiredBinaries.addAll(clientVersions.map((clientVersion) => (ClientBinaryType.sshnp, ClientLanguage.dart, clientVersion)).toSet());
  requiredBinaries.addAll(clientVersions.map((clientVersion) => (ClientBinaryType.npt, ClientLanguage.dart, clientVersion)).toSet());

  List<ClientBinary> clientBinaries = await clientBinaryManager.ensureBinaries(required: requiredBinaries);
  print('Available client binaries: length=${clientBinaries.length}');
  for(final ClientBinary clientBinary in clientBinaries) {
    print('  ${clientBinary.binaryType.name} | ${clientBinary.language.name} | ${clientBinary.version}');
  }

  // Test coverage

  // Test #1: 001_minus_s_flag
  // 1. Generates a new ssh key
  // 2. 
  //     a. Run sshnp against a daemon without the `-s` flag with that new key
  //     b. Verify it fails
  // 3.
  //     a. Run against a daemon with the `-s` flag
  //     b. Verify it succeeds
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: C (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0

  // Test #2: minus_r_flag
  // 1. Run sshnp with `--host` (expect to pass)
  // 2. Run sshnp with `-h` invalid and `-r` valid (expect to pass)
  // 3. Run sshnp with `-h` valid and `-r` invalid (expect to fail)
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart v5.9.4 | Daemon: Dart (current)
  // - Client: Dart v5.11.2 | Daemon: Dart (current)
  // - Client: Dart v5.13.0 | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0

  // Test #3: minus_u_flag
  // - Client: Dart (current) | Daemon: Dart (current)

  // Test #4: npt_to_port_22
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart v5.9.4 | Daemon: Dart (current)
  // - Client: Dart v5.11.2 | Daemon: Dart (current)
  // - Client: Dart v5.13.0 | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: C (current)
  // - Client: Dart v5.9.4 | Daemon: C (current)
  // - Client: Dart v5.11.2 | Daemon: C (current)
  // - Client: Dart v5.13.0 | Daemon: C (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0

  // Test #5: npt_to_port_22_no_encrypt_traffic
  // - Client: Dart (current) | Daemon: Dart (current)

  // Test #6: v4_dart_inline
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart v5.9.4 | Daemon: Dart (current)
  // - Client: Dart v5.11.2 | Daemon: Dart (current)
  // - Client: Dart v5.13.0 | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0

  // Test #7: v4_openssh_print
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart v5.9.4 | Daemon: Dart (current)
  // - Client: Dart v5.11.2 | Daemon: Dart (current)
  // - Client: Dart v5.13.0 | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0

  // Test #8: v5_dart_inline
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart v5.9.4 | Daemon: Dart (current)
  // - Client: Dart v5.11.2 | Daemon: Dart (current)
  // - Client: Dart v5.13.0 | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: C (current)
  // - Client: Dart v5.9.4 | Daemon: C (current)
  // - Client: Dart v5.11.2 | Daemon: C (current)
  // - Client: Dart v5.13.0 | Daemon: C (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0

  // Test #9: v5_openssh_inline
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart v5.9.4 | Daemon: Dart (current)
  // - Client: Dart v5.11.2 | Daemon: Dart (current)
  // - Client: Dart v5.13.0 | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: C (current)
  // - Client: Dart v5.9.4 | Daemon: C (current)
  // - Client: Dart v5.11.2 | Daemon: C (current)
  // - Client: Dart v5.13.0 | Daemon: C (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0

  // Test #10: v5_openssh_print
  // - Client: Dart (current) | Daemon: Dart (current)
  // - Client: Dart v5.9.4 | Daemon: Dart (current)
  // - Client: Dart v5.11.2 | Daemon: Dart (current)
  // - Client: Dart v5.13.0 | Daemon: Dart (current)
  // - Client: Dart (current) | Daemon: C (current)
  // - Client: Dart v5.9.4 | Daemon: C (current)
  // - Client: Dart v5.11.2 | Daemon: C (current)
  // - Client: Dart v5.13.0 | Daemon: C (current)
  // - Client: Dart (current) | Daemon: Dart v5.9.4
  // - Client: Dart (current) | Daemon: Dart v5.11.2
  // - Client: Dart (current) | Daemon: Dart v5.13.0
}
