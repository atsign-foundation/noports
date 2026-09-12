// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NoPorts';

  @override
  String get appSubtitle => 'Configuration';

  @override
  String get tabStatus => 'Status';

  @override
  String get tabConfiguration => 'Configuration';

  @override
  String get tabKeys => 'Keys';

  @override
  String get tabDiagnostics => 'Diagnostics';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get info => 'Info';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get done => 'Done';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get browse => 'Browse';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading';

  @override
  String get serviceTitle => 'NoPorts daemon service';

  @override
  String get serviceSubtitle =>
      'The background service that answers connection requests for this device.';

  @override
  String get stateRunning => 'Running';

  @override
  String get stateStopped => 'Stopped';

  @override
  String get stateStarting => 'Starting';

  @override
  String get stateStopping => 'Stopping';

  @override
  String get stateNotInstalled => 'Not installed';

  @override
  String get stateUnknown => 'Unknown';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get restart => 'Restart';

  @override
  String get startType => 'Start mode';

  @override
  String get processId => 'Process ID';

  @override
  String get lastExitCode => 'Last exit code';

  @override
  String get serviceName => 'Service';

  @override
  String get logsTitle => 'Recent log';

  @override
  String logsSource(String source) {
    return 'Source: $source';
  }

  @override
  String get notElevatedTitle => 'Administrator rights needed';

  @override
  String get notElevatedBody =>
      'This app is not running with administrator rights, so it can read settings but cannot save them or control the service. Close it and launch it again as an administrator.';

  @override
  String get privilegePromptNote =>
      'Saving the configuration and starting or stopping the service need administrator rights. You will be asked for your password each time; everything else runs as you.';

  @override
  String get serviceNotInstalledBody =>
      'No sshnpd service is registered on this machine. Reinstall NoPorts with the daemon service feature selected.';

  @override
  String serviceActionFailed(String message) {
    return 'Service action failed: $message';
  }

  @override
  String get serviceStarted => 'Service started';

  @override
  String get serviceStopped => 'Service stopped';

  @override
  String get serviceRestarted => 'Service restarted';

  @override
  String deviceSummary(String device, String atsign) {
    return 'Device $device as $atsign';
  }

  @override
  String configuredManagers(String managers) {
    return 'Managers: $managers';
  }

  @override
  String get notConfigured => 'Not configured yet';

  @override
  String get runSetup => 'Run setup';

  @override
  String get configTitle => 'Daemon configuration';

  @override
  String configFile(String path) {
    return 'Config file: $path';
  }

  @override
  String get configMissingNote =>
      'This file does not exist yet. Saving will create it from the bundled template.';

  @override
  String get formTab => 'Form';

  @override
  String get yamlTab => 'YAML';

  @override
  String get save => 'Save';

  @override
  String get saveAndRestart => 'Save and restart';

  @override
  String get revert => 'Revert';

  @override
  String get showAdvanced => 'Show advanced settings';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get configSaved => 'Configuration saved';

  @override
  String configSaveFailed(String message) {
    return 'Could not save configuration: $message';
  }

  @override
  String configLoadFailed(String message) {
    return 'Could not read configuration: $message';
  }

  @override
  String yamlInvalid(String message) {
    return 'The YAML is not valid: $message';
  }

  @override
  String get fixProblemsBeforeSaving => 'Fix the problems below before saving.';

  @override
  String get restartNeededNote =>
      'The daemon reads its configuration only at start. Restart the service for changes to take effect.';

  @override
  String get defaultLabel => 'Default';

  @override
  String get onLabel => 'On';

  @override
  String get offLabel => 'Off';

  @override
  String get emptyList => 'Nothing added yet';

  @override
  String defaultValueHint(String value) {
    return 'Default: $value';
  }

  @override
  String get keysTitle => 'Device atSign keys';

  @override
  String get keysSubtitle =>
      'The daemon needs the .atKeys file for the device atSign. Import one from another machine, or activate a brand new atSign here.';

  @override
  String get keysCurrent => 'Keys file in use';

  @override
  String get keysNone => 'No keys file configured';

  @override
  String get keysFound => 'Found';

  @override
  String get keysMissing => 'File not found';

  @override
  String keysManagedDir(String dir) {
    return 'Keys enrolled or imported here are kept in your own $dir and referenced by absolute path in the daemon configuration. Existing key files are never overwritten.';
  }

  @override
  String get importKeys => 'Import an existing .atKeys file';

  @override
  String get importKeysHint =>
      'Only if you already have a keys file for the device atSign, for example from a fleet deployment. Normally you enroll instead.';

  @override
  String keysImported(String atsign) {
    return 'Imported keys for $atsign';
  }

  @override
  String keysImportFailed(String message) {
    return 'Could not import keys: $message';
  }

  @override
  String keysAtsignMismatch(String fileAtsign, String configAtsign) {
    return 'This file is for $fileAtsign but the configured device atSign is $configAtsign. Use it anyway and change the device atSign?';
  }

  @override
  String get useAnyway => 'Use this file';

  @override
  String get enterAtsign => 'Device atSign';

  @override
  String get enrollTitle => 'Enroll this device';

  @override
  String get enroll => 'Enroll';

  @override
  String get enrollCardTitle => 'Enroll this device with NoPorts Desktop';

  @override
  String get enrollCardBody =>
      'Cuts a new set of keys for the device atSign using APKAM and saves them in your ~/.atsign/keys. The request is approved from the NoPorts Desktop app on your client, which holds the atSign\'s manager keys.';

  @override
  String get enrollHowTitle => 'Before you start';

  @override
  String get enrollHowStep1 =>
      '1. In NoPorts Desktop on your client, sign in with the device atSign and open the Authenticator tab.';

  @override
  String get enrollHowStep2 =>
      '2. Copy the OTP shown there, or set a PIN if you are enrolling several devices.';

  @override
  String get enrollHowStep3 =>
      '3. After you press Enroll here, approve the request in the same Authenticator tab.';

  @override
  String get enrollDeviceName => 'Device name';

  @override
  String get enrollPasscode => 'OTP or PIN from NoPorts Desktop';

  @override
  String get enrollPasscodeHint => '6 characters';

  @override
  String get enrollSubmitting => 'Sending the enrollment request';

  @override
  String get enrollAwaitingApproval =>
      'Waiting for approval. Open NoPorts Desktop on your client, go to Authenticator and approve this device.';

  @override
  String get enrollCreatingKeys => 'Approved. Writing the keys file.';

  @override
  String get enrollmentId => 'Request ID';

  @override
  String enrollSuccess(String atsign) {
    return '$atsign is enrolled and its keys are saved.';
  }

  @override
  String get backupKeysReminder =>
      'Keep a backup of the .atKeys file somewhere safe. If it is lost the device has to be enrolled again.';

  @override
  String get healthTitle => 'Diagnostics';

  @override
  String get healthSubtitle =>
      'Quick checks that the daemon has everything it needs. Run the full doctor for a detailed report.';

  @override
  String get runChecks => 'Run checks';

  @override
  String get runFullDoctor => 'Run full doctor';

  @override
  String get doctorOutput => 'sshnpd --doctor output';

  @override
  String doctorFailed(String message) {
    return 'Could not run the doctor: $message';
  }

  @override
  String get checkPass => 'Pass';

  @override
  String get checkWarn => 'Warning';

  @override
  String get checkFail => 'Fail';

  @override
  String checksSummary(int passed, int warnings, int failed) {
    return '$passed passed, $warnings warnings, $failed failed';
  }

  @override
  String get wizardTitle => 'Set up this device for NoPorts';

  @override
  String get wizardIntro =>
      'Four short steps: name this device, enroll it with NoPorts Desktop to get its keys, choose who may connect, then the daemon is started for you.';

  @override
  String get stepKeys => 'Keys';

  @override
  String get stepAccess => 'Access';

  @override
  String get stepDevice => 'Device';

  @override
  String get stepFinish => 'Finish';

  @override
  String get wizardKeysBody =>
      'Enroll this device to cut its keys. You need the OTP or PIN from the Authenticator tab of NoPorts Desktop on your client.';

  @override
  String wizardKeysReady(String atsign) {
    return 'Ready: keys for $atsign';
  }

  @override
  String get wizardAccessBody =>
      'Which client atSigns may connect to this device? You can add more later on the Configuration tab.';

  @override
  String get wizardDeviceBody =>
      'Which atSign does this device run as, and what is it called? Clients use both to pick this machine. The device atSign is the one you activated in NoPorts Desktop for this device.';

  @override
  String get wizardFinishBody => 'Save the configuration and start the daemon.';

  @override
  String get wizardSaving => 'Saving configuration';

  @override
  String get wizardStarting => 'Starting the service';

  @override
  String get wizardChecking => 'Running checks';

  @override
  String get wizardComplete =>
      'This device is ready. Connect to it from a NoPorts client using the device atSign and name above.';

  @override
  String get wizardCompleteWithIssues =>
      'Setup finished but some checks need attention. See the Diagnostics tab.';

  @override
  String get openDashboard => 'Open dashboard';

  @override
  String get skipSetup => 'Skip setup';

  @override
  String get finishAndStart => 'Save and start';

  @override
  String get hostname => 'Use this computer\'s name';
}
