import 'package:npe2e/noports_version.dart';
import 'package:npe2e/relay_tests/relay_test_flow_shared.dart';
import 'package:npe2e/relay_tests/relay_tests_context.dart';
import 'package:npe2e/relay_tests/relay_tests_test_result.dart';

const NptRelayCase normalToNormalRelayCase = NptRelayCase(
  name: 'normal client to normal relay',
  metadata: 'normal_to_normal',
  clientUses443: false,
  relayAuthMode: payloadRelayAuthMode,
  relayUses443: false,
  expectSuccess: true,
);

List<Future<RelayTestResult> Function()> runNormalToNormalTests({
  required RelayTestsContext context,
  required NptRelayEnvironment environment,
  required List<NoPortsVersion> clientVersions,
}) {
  return runNptRelayCaseTests(
    context: context,
    environment: environment,
    clientVersions: clientVersions,
    relayCase: normalToNormalRelayCase,
  );
}
