import 'dart:io';

import 'package:at_client/at_client_io.dart'
    show AtClientPreference, FileAtKeysIo, PendingEnrollment;
import 'package:at_commons/at_commons.dart' show AtRootDomain, Atsign;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/platform/atsigns.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/device_names.dart';
import 'package:noports_core/commands.dart'
    show ActivateFlows, defaultAppName, defaultEnrollmentNamespaces;

enum EnrollmentStep {
  enterDetails,
  submitting,
  awaitingApproval,
  creatingKeys,
  done,
}

class EnrollmentState extends Equatable {
  const EnrollmentState({
    this.step = EnrollmentStep.enterDetails,
    this.atsign = '',
    this.deviceName = '',
    this.enrollmentId,
    this.error,
    this.keysFile,
  });

  final EnrollmentStep step;
  final String atsign;
  final String deviceName;
  final String? enrollmentId;
  final String? error;
  final File? keysFile;

  bool get busy =>
      step == EnrollmentStep.submitting ||
      step == EnrollmentStep.awaitingApproval ||
      step == EnrollmentStep.creatingKeys;

  EnrollmentState copyWith({
    EnrollmentStep? step,
    String? atsign,
    String? deviceName,
    String? enrollmentId,
    String? error,
    File? keysFile,
    bool clearError = false,
  }) => EnrollmentState(
    step: step ?? this.step,
    atsign: atsign ?? this.atsign,
    deviceName: deviceName ?? this.deviceName,
    enrollmentId: enrollmentId ?? this.enrollmentId,
    error: clearError ? null : error ?? this.error,
    keysFile: keysFile ?? this.keysFile,
  );

  @override
  List<Object?> get props => [
    step,
    atsign,
    deviceName,
    enrollmentId,
    error,
    keysFile?.path,
  ];
}

/// APKAM enrollment of this device: `noports activate` from the GUI.
///
/// Runs noports_core's [ActivateFlows], the same object the CLI runs, so
/// a device asks for the same app name and grants wherever it enrolls. The
/// passcode (OTP or PIN) comes from the NoPorts Desktop app's Authenticator
/// tab on the client, which also approves the request. The resulting
/// .atKeys file is written to the user's ~/.atsign/keys, and is never
/// written over an existing file.
class EnrollmentCubit extends Cubit<EnrollmentState> {
  EnrollmentCubit({
    required this.rootDomain,
    DaemonPaths? paths,
    ActivateFlows flows = const ActivateFlows(),
    this.retryInterval = const Duration(seconds: 10),
    this.maxRetries = 180,
  }) : _paths = paths,
       _flows = flows,
       super(const EnrollmentState());

  /// What `sshnpd` enrolls as; the approve command in the docs filters on
  /// these.
  static final appName = defaultAppName;
  static final namespaces = defaultEnrollmentNamespaces;

  /// As written in sshnpd.yaml, e.g. `root.atsign.org` or
  /// `proxy:host:port`.
  final String rootDomain;
  final Duration retryInterval;

  /// Consecutive failures to reach the atServer tolerated while waiting;
  /// the wait for a person to approve has no bound of its own.
  final int maxRetries;
  final DaemonPaths? _paths;
  final ActivateFlows _flows;

  /// The request in flight, so [cancel] can end its wait.
  PendingEnrollment? _pending;
  bool _cancelled = false;

  DaemonPaths get paths => _paths ?? DaemonPaths.instance;

  Future<void> enroll({
    required String rawAtsign,
    required String deviceName,
    required String passcode,
  }) async {
    final atsign = Atsigns.normalize(rawAtsign);
    // As the daemon does with its own setting: snakify, then the pattern.
    final device = DeviceNames.snakify(deviceName);
    final code = passcode.trim();
    if (atsign == null) {
      emit(
        state.copyWith(
          error:
              '"${rawAtsign.trim()}" is not a valid atsign: '
              '${Atsigns.problem(rawAtsign)}',
        ),
      );
      return;
    }
    if (!DeviceNames.isValid(device)) {
      emit(
        state.copyWith(
          error: 'Device name "$device" is not allowed. ${DeviceNames.rule}',
        ),
      );
      return;
    }
    if (code.isEmpty) {
      emit(state.copyWith(error: 'The passcode is required.'));
      return;
    }
    _cancelled = false;
    emit(
      state.copyWith(
        step: EnrollmentStep.submitting,
        atsign: atsign,
        deviceName: device,
        clearError: true,
      ),
    );

    final dest = paths.keysFileFor(atsign);
    try {
      await dest.parent.create(recursive: true);
      final root = AtRootDomain.parse(rootDomain);
      final preference = AtClientPreference()
        ..rootDomain = root.rootDomain
        ..rootPort = root.rootPort;
      final keys = FileAtKeysIo(filePath: (_) => dest.path);
      final at = Atsign(atsign);

      // A keyfile holding a request submitted earlier for this app and
      // device is resumed rather than repeated. Any other existing keyfile
      // is left alone: never overwrite a device's keys.
      var pending = await _flows.resumeEnrollment(
        at,
        app: appName,
        device: device,
        keys: keys,
        preference: preference,
      );
      if (pending == null && await dest.exists()) {
        throw StateError(
          'Keys for $atsign already exist at ${dest.path}. Not overwriting '
          'them. Use that file, or move it away first if this device really '
          'needs new keys.',
        );
      }
      pending ??= await _flows.enroll(
        at,
        otp: code,
        app: appName,
        device: device,
        namespaces: namespaces,
        keys: keys,
        preference: preference,
      );
      _pending = pending;
      if (_cancelled) {
        await pending.cancel();
        return;
      }
      emit(
        state.copyWith(
          step: EnrollmentStep.awaitingApproval,
          enrollmentId: pending.enrollmentId,
        ),
      );

      // Approval completes the keys in the file; no client is opened since
      // the daemon, not this app, is what will use them.
      await pending.awaitApproval(
        retryInterval: retryInterval,
        maxRetries: maxRetries,
      );
      if (_cancelled) return;

      emit(state.copyWith(step: EnrollmentStep.creatingKeys));
      await KeysRepository.restrictPermissions(dest);
      emit(state.copyWith(step: EnrollmentStep.done, keysFile: dest));
    } catch (e) {
      if (_cancelled) return;
      emit(
        state.copyWith(step: EnrollmentStep.enterDetails, error: _describe(e)),
      );
    } finally {
      _pending = null;
    }
  }

  /// Stop waiting and abandon the request: the wait ends, the pending keys
  /// are dropped from the file, and a later approval in NoPorts Desktop
  /// completes nothing here. The request itself stays on the atServer
  /// until the manager denies it or it expires.
  Future<void> cancel() async {
    _cancelled = true;
    final pending = _pending;
    if (pending != null) {
      try {
        await pending.cancel();
      } catch (_) {
        // Already ended; nothing to withdraw.
      }
    }
  }

  static String describeError(Object e) => _describe(e);

  static String _describe(Object e) {
    var s = e.toString().replaceFirst(
      RegExp(r'^(\w*Exception|Bad state): '),
      '',
    );
    if (s.contains('CERTIFICATE_VERIFY_FAILED') ||
        s.contains('HandshakeException')) {
      return 'The secure connection to the atServer could not be verified '
          '(CERTIFICATE_VERIFY_FAILED). This machine is missing the root '
          'certificates that TLS needs: install the ca-certificates package '
          '(Linux) or check the system trust store, then try again.';
    }
    if (s.contains('AT0032') || s.contains('Another enrollment with id')) {
      final name = RegExp(r'device name: (\S+)').firstMatch(s)?.group(1);
      return 'A device called ${name ?? 'this'} is already enrolled for this '
          'atsign (for example from an earlier install). Use a different '
          'device name, or revoke the old enrollment from NoPorts Desktop\'s '
          'Authenticator tab and try again.';
    }
    if (s.contains('denied')) {
      return 'The enrollment request was denied in NoPorts Desktop.';
    }
    if (s.contains('otp') ||
        s.contains('OTP') ||
        s.contains('invalid passcode')) {
      return 'The passcode was not accepted. Copy a fresh OTP, or the PIN, from NoPorts Desktop\'s Authenticator tab.';
    }
    if (s.contains('timed out') ||
        s.contains('Timed out') ||
        s.contains('max retries')) {
      return 'Gave up waiting for approval. Approve the request in NoPorts Desktop and try again.';
    }
    return s;
  }
}
