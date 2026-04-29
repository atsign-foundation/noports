import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/test_result.dart';

class RelayTestResult extends TestResult {
  final NoPortsVersion clientVersion;
  final NoPortsVersion daemonVersion;
  final NoPortsVersion? relayVersion;
  final String relayKind;
  final String relayAuthMode;
  final bool only443;

  RelayTestResult({
    required super.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required this.relayVersion,
    required this.relayKind,
    required this.relayAuthMode,
    required this.only443,
    required super.status,
    required super.exitCode,
  });
}
