import 'dart:io';

import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/platform/daemon_paths.dart';

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
  List<Object?> get props => [step, atsign, deviceName, enrollmentId, error, keysFile?.path];
}

/// APKAM enrollment of this device, the same thing as
/// `at_activate enroll -a @x -s <passcode> -p noports -d <device> -n "sshnp:rw,sshrvd:rw"`.
///
/// The passcode (OTP or PIN) comes from the NoPorts Desktop app's
/// Authenticator tab on the client, which also approves the request. The
/// resulting .atKeys file is written straight into the daemon's managed
/// keys directory.
class EnrollmentCubit extends Cubit<EnrollmentState> {
  EnrollmentCubit({
    required this.rootDomain,
    DaemonPaths? paths,
    AtOnboardingService Function(String atsign, AtOnboardingPreference pref)? serviceFactory,
  }) : _paths = paths,
       _serviceFactory = serviceFactory ?? AtOnboardingServiceImpl.new,
       super(const EnrollmentState());

  /// Must match what `sshnpd` enrolls as; the approve command in the docs
  /// filters on these.
  static const appName = 'noports';
  static const namespaces = {'sshnp': 'rw', 'sshrvd': 'rw'};

  final String rootDomain;
  final DaemonPaths? _paths;
  final AtOnboardingService Function(String, AtOnboardingPreference) _serviceFactory;
  bool _cancelled = false;

  DaemonPaths get paths => _paths ?? DaemonPaths.instance;

  Future<void> enroll({
    required String rawAtsign,
    required String deviceName,
    required String passcode,
  }) async {
    final atsign = AtUtils.fixAtSign(rawAtsign.trim());
    final device = deviceName.trim();
    final code = passcode.trim();
    if (device.isEmpty || code.isEmpty) {
      emit(state.copyWith(error: 'Device name and passcode are required.'));
      return;
    }
    _cancelled = false;
    emit(state.copyWith(
      step: EnrollmentStep.submitting,
      atsign: atsign,
      deviceName: device,
      clearError: true,
    ));

    final dest = paths.keysFileFor(atsign);
    AtOnboardingService? svc;
    try {
      if (await dest.exists()) {
        // A stale file here would make createAtKeysFile refuse to write.
        await dest.rename('${dest.path}.old');
      }
      await dest.parent.create(recursive: true);
      final pref = AtOnboardingPreference()
        ..rootDomain = rootDomain
        ..atKeysFilePath = dest.path
        ..appName = appName
        ..deviceName = device;
      svc = _serviceFactory(atsign, pref);

      final er = await svc.sendEnrollRequest(appName, device, code, namespaces);
      if (_cancelled) return;
      emit(state.copyWith(
        step: EnrollmentStep.awaitingApproval,
        enrollmentId: er.enrollmentId,
      ));

      // Poll for up to ~30 minutes; the user has to go and approve it.
      await svc.awaitApproval(er, logProgress: false, maxRetries: 180);
      if (_cancelled) return;

      emit(state.copyWith(step: EnrollmentStep.creatingKeys));
      await svc.createAtKeysFile(er, atKeysFile: dest, allowOverwrite: true);
      await KeysRepository.restrictPermissions(dest);
      emit(state.copyWith(step: EnrollmentStep.done, keysFile: dest));
    } catch (e) {
      if (_cancelled) return;
      emit(state.copyWith(step: EnrollmentStep.enterDetails, error: _describe(e)));
    } finally {
      try {
        await svc?.close();
      } catch (_) {}
    }
  }

  /// Stop waiting. The request stays pending on the atServer until it is
  /// approved, denied or expires.
  void cancel() {
    _cancelled = true;
  }

  static String _describe(Object e) {
    var s = e.toString().replaceFirst(RegExp(r'^\w*Exception: '), '');
    if (s.contains('denied')) return 'The enrollment request was denied in NoPorts Desktop.';
    if (s.contains('otp') || s.contains('OTP') || s.contains('invalid passcode')) {
      return 'The passcode was not accepted. Copy a fresh OTP, or the PIN, from NoPorts Desktop\'s Authenticator tab.';
    }
    if (s.contains('timed out') || s.contains('Timed out') || s.contains('max retries')) {
      return 'Gave up waiting for approval. Approve the request in NoPorts Desktop and try again.';
    }
    return s;
  }
}
