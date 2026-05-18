import 'package:npe2e/noports_version.dart';
import 'package:npe2e/relay_tests/relay_test_flow_shared.dart';
import 'package:npe2e/relay_tests/relay_tests_context.dart';
import 'package:npe2e/relay_tests/relay_tests_test_result.dart';

const NptRelayCase normalTo443RelayCase = NptRelayCase(
  name: 'normal client to 443 relay',
  metadata: 'normal_to_443',
  clientUses443: false,
  relayAuthMode: payloadRelayAuthMode,
  relayUses443: true,
  expectSuccess: true,
);

List<Future<RelayTestResult> Function()> runNormalTo443Tests({
  required RelayTestsContext context,
  required NptRelayEnvironment environment,
  required List<NoPortsVersion> clientVersions,
}) {
  return runNptRelayCaseTests(
    context: context,
    environment: environment,
    clientVersions: clientVersions,
    relayCase: normalTo443RelayCase,
  );
}
