import 'package:npe2e/noports_version.dart';
import 'package:npe2e/relay_tests/relay_test_flow_shared.dart';
import 'package:npe2e/relay_tests/relay_tests_context.dart';
import 'package:npe2e/relay_tests/relay_tests_test_result.dart';

const NptRelayCase port443ToNormalRelayCase = NptRelayCase(
  name: '443 client to normal relay',
  metadata: '443_to_normal',
  clientUses443: true,
  relayAuthMode: escrRelayAuthMode,
  relayUses443: false,
  expectSuccess: false,
);

List<Future<RelayTestResult> Function()> runPort443ToNormalTests({
  required RelayTestsContext context,
  required NptRelayEnvironment environment,
  required List<NoPortsVersion> clientVersions,
}) {
  return runNptRelayCaseTests(
    context: context,
    environment: environment,
    clientVersions: clientVersions,
    relayCase: port443ToNormalRelayCase,
  );
}
