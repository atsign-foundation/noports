import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/tests/sshnp_test_helpers.dart';
import 'package:e2e_all_v2/noports_version.dart';

const String testName = 'v5_openssh_inline';
const String _metadata = 'v5OpensshInline';

List<Future<CoreTestResult> Function()> runV5OpensshInlineTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFactories = [];
  final CoreTestLogger testLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );

  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations =
      generateV5VersionCombinations(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
      );

  for (final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion)
      in versionCombinations) {
    testFactories.add(
      () => runInlineSshnpTest(
        testName: testName,
        metadata: _metadata,
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
        protocol: SshnpProtocol.v5,
        sshClient: SshnpClient.openssh,
      ),
    );
  }

  return testFactories;
}
