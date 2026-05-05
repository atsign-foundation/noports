import 'package:npe2e/noports_version.dart';
import 'package:npe2e/relay_tests/relay_test_flow_shared.dart';
import 'package:npe2e/relay_tests/relay_tests_context.dart';
import 'package:npe2e/relay_tests/relay_tests_test_result.dart';

const NptRelayCase port443To443RelayCase = NptRelayCase(
  name: '443 client to 443 relay',
  metadata: '443_to_443',
  clientUses443: true,
  relayAuthMode: escrRelayAuthMode,
  relayUses443: true,
  expectSuccess: true,
);

List<Future<RelayTestResult> Function()> runPort443To443Tests({
  required RelayTestsContext context,
  required NptRelayEnvironment environment,
  required List<NoPortsVersion> clientVersions,
}) {
  return runNptRelayCaseTests(
    context: context,
    environment: environment,
    clientVersions: clientVersions,
    relayCase: port443To443RelayCase,
  );
}
