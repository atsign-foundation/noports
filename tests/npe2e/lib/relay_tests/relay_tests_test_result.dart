import 'package:npe2e/noports_version.dart';
import 'package:npe2e/test_result.dart';

class RelayTestResult extends TestResult {
  final NoPortsVersion clientVersion;
  final NoPortsVersion daemonVersion;
  final NoPortsVersion? relayVersion;
  final String relayKind;
  final String relayAuthMode;
  final bool clientOnly443;
  final bool relayOnly443;
  final String caseName;
  final bool expectedSuccess;

  RelayTestResult({
    required super.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required this.relayVersion,
    required this.relayKind,
    required this.relayAuthMode,
    required this.clientOnly443,
    required this.relayOnly443,
    required this.caseName,
    required this.expectedSuccess,
    required super.status,
    required super.exitCode,
  });
}
