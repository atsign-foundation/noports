import 'package:noports_installer/src/install/install_step.dart';

sealed class InstallStatus {
  const InstallStatus();
}

enum InstallProgressVerbosity { debug, info, warn, error }

class InstallProgress extends InstallStatus {
  final String status;
  final InstallProgressVerbosity verbosity;
  const InstallProgress(this.status,
      {this.verbosity = InstallProgressVerbosity.info});
}

class InstallTypeSuccess extends InstallStatus {
  final InstallStep type;
  const InstallTypeSuccess(this.type);
}

class InstallTypeFailure extends InstallStatus {
  final InstallStep type;
  const InstallTypeFailure(this.type);
}

abstract class InstallResult extends InstallStatus {
  const InstallResult();
}

class InstallCompleted extends InstallResult {
  final Set<InstallStep> successes;
  final Set<InstallStep> failures;
  const InstallCompleted({required this.successes, required this.failures});
}

class InstallFailure extends InstallResult {
  final Object? error;
  final StackTrace stackTrace;
  const InstallFailure(this.error, this.stackTrace);
}
