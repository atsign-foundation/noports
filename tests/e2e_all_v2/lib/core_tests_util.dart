import 'dart:io';

import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
import 'package:e2e_all_v2/core_tests/core_tests_print_utils.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/log_fragment.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';

/// Result of a single test phase (client execution + daemon log capture)
class TestPhaseResult {
  final ProcessOutputCapture clientCapture;
  final LogFragment daemonLogFragment;
  final int exitCode;

  TestPhaseResult({
    required this.clientCapture,
    required this.daemonLogFragment,
    required this.exitCode,
  });

  /// Check if this phase passed based on expected exit code
  bool passed({required int expectedExitCode}) => exitCode == expectedExitCode;
}

/// Utilities for running core tests with standardized patterns
class CoreTestRunner {
  /// Runs a single test phase with automatic log fragment and process management.
  ///
  /// This method handles:
  /// - Finding the appropriate Docker instance for the daemon
  /// - Creating and managing daemon log fragments
  /// - Starting the client binary with output capture
  /// - Coordinating cleanup of resources
  ///
  /// Returns a [TestPhaseResult] containing the client output, daemon logs, and exit code.
  static Future<TestPhaseResult> runTestPhase({
    required final CoreTestsContext context,
    required final CoreTestLogger logger,
    required final NoPortsVersion clientVersion,
    required final NoPortsVersion daemonVersion,
    required final String clientBinaryType,
    required final List<String> clientArgs,
    required final String deviceName,
    final String? metadata,
    final Map<String, String>? environment,
    final String? workingDirectory,
  }) async {
    final DockerInstance dockerInstance = _getDockerInstance(
      context: context,
      deviceName: deviceName,
    );

    final File daemonStdoutFile = logger.getDaemonStdoutLogFile(
      metadata: metadata ?? '',
      suffix: 'fragment',
    );
    final File daemonStderrFile = logger.getDaemonStderrLogFile(
      metadata: metadata ?? '',
      suffix: 'fragment',
    );

    final LogFragment daemonLogFragment = dockerInstance.createLogFragment(
      stdoutFile: daemonStdoutFile,
      stderrFile: daemonStderrFile,
    );

    await daemonLogFragment.start();

    final File clientBinary = _getClientBinary(
      context: context,
      clientVersion: clientVersion,
      binaryType: clientBinaryType,
    );

    final File clientStdoutFile = logger.getClientStdoutLogFile(
      metadata: metadata ?? '',
    );
    final File clientStderrFile = logger.getClientStderrLogFile(
      metadata: metadata ?? '',
    );

    final ProcessOutputCapture clientCapture = await startCommandWithCapture(
      clientBinary.path,
      clientArgs,
      stdoutLogFile: clientStdoutFile,
      stderrLogFile: clientStderrFile,
      environment: environment,
      workingDirectory: workingDirectory,
    );

    final int exitCode = await clientCapture.exitCode;

    await daemonLogFragment.stop();

    return TestPhaseResult(
      clientCapture: clientCapture,
      daemonLogFragment: daemonLogFragment,
      exitCode: exitCode,
    );
  }

  /// Runs a complete single-phase test with automatic result handling.
  ///
  /// This is a higher-level wrapper around [runTestPhase] that:
  /// - Prints test start message
  /// - Runs the test phase
  /// - Validates exit code against expected value
  /// - Prints test result and logs (on failure or if alwaysOutputLogs is true)
  /// - Returns a [CoreTestResult]
  ///
  /// Ideal for simple tests that consist of a single client invocation.
  static Future<CoreTestResult> runSinglePhaseTest({
    required final CoreTestsContext context,
    required final CoreTestLogger logger,
    required final NoPortsVersion clientVersion,
    required final NoPortsVersion daemonVersion,
    required final String testName,
    required final String clientBinaryType,
    required final List<String> clientArgs,
    required final String deviceName,
    required final int expectedExitCode,
    final String? metadata,
    final Map<String, String>? environment,
    final String? workingDirectory,
  }) async {
    final String extra = generateExtraString(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    );

    printTestStart(testName: testName, extra: extra);

    final TestPhaseResult phaseResult = await runTestPhase(
      context: context,
      logger: logger,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      clientBinaryType: clientBinaryType,
      clientArgs: clientArgs,
      deviceName: deviceName,
      metadata: metadata,
      environment: environment,
      workingDirectory: workingDirectory,
    );

    final bool passed = phaseResult.passed(expectedExitCode: expectedExitCode);
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: passed ? TestStatus.passed : TestStatus.failed,
      exitCode: phaseResult.exitCode,
    );

    printTestResult(testResult: result, extra: extra);

    if (!passed || context.alwaysOutputLogs) {
      printAllLogs(
        clientCapture: phaseResult.clientCapture,
        daemonLogFragment: phaseResult.daemonLogFragment,
      );
    }

    return result;
  }

  /// Runs a multi-phase test where each phase must pass for the test to succeed.
  ///
  /// This allows you to define multiple test phases (e.g., test with and without a flag)
  /// where each phase is a function that runs and returns a [TestPhaseResult].
  ///
  /// If any phase fails, the test immediately fails and returns without running remaining phases.
  /// Logs from the failed phase are printed (or all phases if alwaysOutputLogs is true).
  ///
  /// Example:
  /// ```dart
  /// final result = await CoreTestRunner.runMultiPhaseTest(
  ///   context: context,
  ///   logger: logger,
  ///   clientVersion: clientVersion,
  ///   daemonVersion: daemonVersion,
  ///   testName: 'my_test',
  ///   phases: [
  ///     TestPhase(
  ///       name: 'without_flag',
  ///       expectedExitCode: 1,
  ///       runner: () => CoreTestRunner.runTestPhase(...),
  ///     ),
  ///     TestPhase(
  ///       name: 'with_flag',
  ///       expectedExitCode: 0,
  ///       runner: () => CoreTestRunner.runTestPhase(...),
  ///     ),
  ///   ],
  /// );
  /// ```
  static Future<CoreTestResult> runMultiPhaseTest({
    required final CoreTestsContext context,
    required final NoPortsVersion clientVersion,
    required final NoPortsVersion daemonVersion,
    required final String testName,
    required final List<TestPhase> phases,
  }) async {
    final String extra = generateExtraString(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    );

    printTestStart(testName: testName, extra: extra);

    final List<TestPhaseResult> phaseResults = [];

    for (final TestPhase phase in phases) {
      final TestPhaseResult phaseResult = await phase.runner();
      phaseResults.add(phaseResult);

      if (!phaseResult.passed(expectedExitCode: phase.expectedExitCode)) {
        final CoreTestResult result = CoreTestResult(
          testName: testName,
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
          status: TestStatus.failed,
          exitCode: phaseResult.exitCode,
        );

        printTestResult(testResult: result, extra: extra);

        if (context.alwaysOutputLogs) {
          for (int i = 0; i < phaseResults.length; i++) {
            print('\n--- Phase ${i + 1}: ${phases[i].name} ---');
            printAllLogs(
              clientCapture: phaseResults[i].clientCapture,
              daemonLogFragment: phaseResults[i].daemonLogFragment,
            );
          }
        } else {
          print('\n--- Failed Phase: ${phase.name} ---');
          printAllLogs(
            clientCapture: phaseResult.clientCapture,
            daemonLogFragment: phaseResult.daemonLogFragment,
          );
        }

        return result;
      }
    }

    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.passed,
      exitCode: 0,
    );

    printTestResult(testResult: result, extra: extra);

    if (context.alwaysOutputLogs) {
      for (int i = 0; i < phaseResults.length; i++) {
        print('\n--- Phase ${i + 1}: ${phases[i].name} ---');
        printAllLogs(
          clientCapture: phaseResults[i].clientCapture,
          daemonLogFragment: phaseResults[i].daemonLogFragment,
        );
      }
    }

    return result;
  }

  /// Helper to find the Docker instance by device name
  static DockerInstance _getDockerInstance({
    required final CoreTestsContext context,
    required final String deviceName,
  }) {
    for (final (String name, DockerInstance instance) in context.dockerInstances) {
      if (name == deviceName) {
        return instance;
      }
    }
    throw Exception('Docker instance not found for device: $deviceName');
  }

  /// Helper to find the client binary
  static File _getClientBinary({
    required final CoreTestsContext context,
    required final NoPortsVersion clientVersion,
    required final String binaryType,
  }) {
    return getClientBinary(
      clientBinaries: context.clientBinaries,
      clientVersion: clientVersion,
      clientBinaryType: binaryType,
    );
  }
}

/// Represents a single phase in a multi-phase test
class TestPhase {
  final String name;
  final int expectedExitCode;
  final Future<TestPhaseResult> Function() runner;

  TestPhase({
    required this.name,
    required this.expectedExitCode,
    required this.runner,
  });
}

/// Helper utilities for building common argument lists
class ArgBuilder {
  /// Builds base arguments for npt command
  ///
  /// Returns: ['-a', deviceAtsign, '-d', deviceName, '-h', relayAtsign, '-r', rootDomain, '-k', apkamKeyPath]
  static List<String> buildBaseNptArgs({
    required final CoreTestsContext context,
    required final String deviceName,
  }) {
    final File apkamKey = context.apkamKeys[context.daemonAtsign]!;

    return [
      '-a',
      context.daemonAtsign,
      '-d',
      deviceName,
      '-h',
      context.relayAtsign,
      '-r',
      context.rootDomain,
      '-k',
      apkamKey.path,
    ];
  }

  /// Builds base arguments for sshnp command
  ///
  /// Returns common sshnp args: ['-f', clientAtsign, '-t', daemonAtsign, '-d', deviceName, ...]
  static List<String> buildBaseSshnpArgs({
    required final CoreTestsContext context,
    required final String deviceName,
  }) {
    final File apkamKey = context.apkamKeys[context.clientAtsign]!;

    return [
      '-f',
      context.clientAtsign,
      '-t',
      context.daemonAtsign,
      '-d',
      deviceName,
      '-h',
      context.relayAtsign,
      '--root-domain',
      context.rootDomain,
      '-k',
      apkamKey.path,
      '-i',
      context.identityFilePath,
      '-u',
      context.remoteUsername,
    ];
  }

  /// Builds arguments for sshnp with common flags and additional custom args
  static List<String> buildSshnpArgs({
    required final CoreTestsContext context,
    required final String deviceName,
    final List<String> additionalArgs = const [],
  }) {
    return [
      ...buildBaseSshnpArgs(context: context, deviceName: deviceName),
      ...additionalArgs,
    ];
  }

  /// Builds arguments for npt with common flags and additional custom args
  static List<String> buildNptArgs({
    required final CoreTestsContext context,
    required final String deviceName,
    final List<String> additionalArgs = const [],
  }) {
    return [
      ...buildBaseNptArgs(context: context, deviceName: deviceName),
      ...additionalArgs,
    ];
  }
}

/// Helper utilities for generating version combinations for tests
class VersionCombinations {
  /// Generates all relevant version combinations for testing.
  ///
  /// By default (onlyCurrentPairs = true), only generates combinations where
  /// at least one of client or daemon is 'current' version. This prevents
  /// testing old-client vs old-daemon which is typically not needed.
  ///
  /// Example:
  /// ```dart
  /// clientVersions: [current, v5.9.4, v5.11.2]
  /// daemonVersions: [current, v5.9.4]
  /// ```
  /// Generates:
  /// ```
  /// (current, current)
  /// (current, v5.9.4)
  /// (v5.9.4, current)
  /// (v5.11.2, current)
  /// ```
  static List<(NoPortsVersion, NoPortsVersion)> generate({
    required final List<NoPortsVersion> clientVersions,
    required final List<NoPortsVersion> daemonVersions,
    final bool onlyCurrentPairs = true,
  }) {
    final List<(NoPortsVersion, NoPortsVersion)> combinations = [];

    for (final NoPortsVersion clientVersion in clientVersions) {
      for (final NoPortsVersion daemonVersion in daemonVersions) {
        final bool isClientCurrent = clientVersion.version == 'current';
        final bool isDaemonCurrent = daemonVersion.version == 'current';

        // Skip old-client vs old-daemon if onlyCurrentPairs is true
        if (onlyCurrentPairs && !isClientCurrent && !isDaemonCurrent) {
          continue;
        }

        combinations.add((clientVersion, daemonVersion));
      }
    }

    return combinations;
  }

  /// Generates combinations filtered by minimum version requirements
  ///
  /// Only includes combinations where both client and daemon meet the minimum version.
  static List<(NoPortsVersion, NoPortsVersion)> generateWithMinVersion({
    required final List<NoPortsVersion> clientVersions,
    required final List<NoPortsVersion> daemonVersions,
    required final NoPortsVersion minClientVersion,
    required final NoPortsVersion minDaemonVersion,
    final bool onlyCurrentPairs = true,
  }) {
    return generate(
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
      onlyCurrentPairs: onlyCurrentPairs,
    ).where((combo) {
      final (clientVersion, daemonVersion) = combo;
      return versionIsAtLeast(clientVersion, minClientVersion) &&
          versionIsAtLeast(daemonVersion, minDaemonVersion);
    }).toList();
  }
}
