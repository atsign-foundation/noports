import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'NoPorts'**
  String get appName;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get appSubtitle;

  /// No description provided for @tabStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get tabStatus;

  /// No description provided for @tabConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get tabConfiguration;

  /// No description provided for @tabKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get tabKeys;

  /// No description provided for @tabDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get tabDiagnostics;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @serviceTitle.
  ///
  /// In en, this message translates to:
  /// **'NoPorts daemon service'**
  String get serviceTitle;

  /// No description provided for @serviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The background service that answers connection requests for this device.'**
  String get serviceSubtitle;

  /// No description provided for @stateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get stateRunning;

  /// No description provided for @stateStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stateStopped;

  /// No description provided for @stateStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get stateStarting;

  /// No description provided for @stateStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get stateStopping;

  /// No description provided for @stateNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get stateNotInstalled;

  /// No description provided for @stateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get stateUnknown;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @startType.
  ///
  /// In en, this message translates to:
  /// **'Start mode'**
  String get startType;

  /// No description provided for @processId.
  ///
  /// In en, this message translates to:
  /// **'Process ID'**
  String get processId;

  /// No description provided for @lastExitCode.
  ///
  /// In en, this message translates to:
  /// **'Last exit code'**
  String get lastExitCode;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceName;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent log'**
  String get logsTitle;

  /// No description provided for @logsSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String logsSource(String source);

  /// No description provided for @notElevatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrator rights needed'**
  String get notElevatedTitle;

  /// No description provided for @notElevatedBody.
  ///
  /// In en, this message translates to:
  /// **'This app is not running with administrator rights, so it can read settings but cannot save them or control the service. Close it and launch it again as an administrator.'**
  String get notElevatedBody;

  /// No description provided for @privilegePromptNote.
  ///
  /// In en, this message translates to:
  /// **'Saving the configuration and starting or stopping the service need administrator rights. You will be asked to authenticate each time; everything else runs as you.'**
  String get privilegePromptNote;

  /// No description provided for @serviceNotInstalledBody.
  ///
  /// In en, this message translates to:
  /// **'No sshnpd service is registered on this machine. Reinstall NoPorts with the daemon service feature selected.'**
  String get serviceNotInstalledBody;

  /// No description provided for @serviceNotInstalledInstallable.
  ///
  /// In en, this message translates to:
  /// **'No sshnpd service is registered for your account yet. Install it to run the daemon at login from sshnpd.yaml.'**
  String get serviceNotInstalledInstallable;

  /// No description provided for @installService.
  ///
  /// In en, this message translates to:
  /// **'Install service'**
  String get installService;

  /// No description provided for @updateServiceDefinition.
  ///
  /// In en, this message translates to:
  /// **'Update service definition'**
  String get updateServiceDefinition;

  /// No description provided for @serviceInstalled.
  ///
  /// In en, this message translates to:
  /// **'Service installed'**
  String get serviceInstalled;

  /// No description provided for @serviceActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Service action failed: {message}'**
  String serviceActionFailed(String message);

  /// No description provided for @serviceStarted.
  ///
  /// In en, this message translates to:
  /// **'Service started'**
  String get serviceStarted;

  /// No description provided for @serviceStopped.
  ///
  /// In en, this message translates to:
  /// **'Service stopped'**
  String get serviceStopped;

  /// No description provided for @serviceRestarted.
  ///
  /// In en, this message translates to:
  /// **'Service restarted'**
  String get serviceRestarted;

  /// No description provided for @deviceSummary.
  ///
  /// In en, this message translates to:
  /// **'Device {device} as {atsign}'**
  String deviceSummary(String device, String atsign);

  /// No description provided for @configuredManagers.
  ///
  /// In en, this message translates to:
  /// **'Managers: {managers}'**
  String configuredManagers(String managers);

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured yet'**
  String get notConfigured;

  /// No description provided for @runSetup.
  ///
  /// In en, this message translates to:
  /// **'Run setup'**
  String get runSetup;

  /// No description provided for @configTitle.
  ///
  /// In en, this message translates to:
  /// **'Daemon configuration'**
  String get configTitle;

  /// No description provided for @configFile.
  ///
  /// In en, this message translates to:
  /// **'Config file: {path}'**
  String configFile(String path);

  /// No description provided for @configMissingNote.
  ///
  /// In en, this message translates to:
  /// **'This file does not exist yet. Saving will create it from the bundled template.'**
  String get configMissingNote;

  /// No description provided for @formTab.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get formTab;

  /// No description provided for @yamlTab.
  ///
  /// In en, this message translates to:
  /// **'YAML'**
  String get yamlTab;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndRestart.
  ///
  /// In en, this message translates to:
  /// **'Save and restart'**
  String get saveAndRestart;

  /// No description provided for @revert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revert;

  /// No description provided for @showAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Show advanced settings'**
  String get showAdvanced;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @configSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get configSaved;

  /// No description provided for @configSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save configuration: {message}'**
  String configSaveFailed(String message);

  /// No description provided for @configLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read configuration: {message}'**
  String configLoadFailed(String message);

  /// No description provided for @yamlInvalid.
  ///
  /// In en, this message translates to:
  /// **'The YAML is not valid: {message}'**
  String yamlInvalid(String message);

  /// No description provided for @fixProblemsBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Fix the problems below before saving.'**
  String get fixProblemsBeforeSaving;

  /// No description provided for @restartNeededNote.
  ///
  /// In en, this message translates to:
  /// **'The daemon reads its configuration only at start. Restart the service for changes to take effect.'**
  String get restartNeededNote;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @onLabel.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onLabel;

  /// No description provided for @offLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offLabel;

  /// No description provided for @emptyList.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet'**
  String get emptyList;

  /// No description provided for @defaultValueHint.
  ///
  /// In en, this message translates to:
  /// **'Default: {value}'**
  String defaultValueHint(String value);

  /// No description provided for @keysTitle.
  ///
  /// In en, this message translates to:
  /// **'Device atSign keys'**
  String get keysTitle;

  /// No description provided for @keysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The daemon needs the .atKeys file for the device atSign. Import one from another machine, or activate a brand new atSign here.'**
  String get keysSubtitle;

  /// No description provided for @keysCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keys file in use'**
  String get keysCurrent;

  /// No description provided for @keysNone.
  ///
  /// In en, this message translates to:
  /// **'No keys file configured'**
  String get keysNone;

  /// No description provided for @keysFound.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get keysFound;

  /// No description provided for @keysMissing.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get keysMissing;

  /// No description provided for @keysManagedDir.
  ///
  /// In en, this message translates to:
  /// **'Keys enrolled or imported here are kept in your own {dir} and referenced by absolute path in the daemon configuration. Existing key files are never overwritten.'**
  String keysManagedDir(String dir);

  /// No description provided for @importKeys.
  ///
  /// In en, this message translates to:
  /// **'Import an existing .atKeys file'**
  String get importKeys;

  /// No description provided for @importKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Only if you already have a keys file for the device atSign, for example from a fleet deployment. Normally you enroll instead.'**
  String get importKeysHint;

  /// No description provided for @keysImported.
  ///
  /// In en, this message translates to:
  /// **'Imported keys for {atsign}'**
  String keysImported(String atsign);

  /// No description provided for @keysImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import keys: {message}'**
  String keysImportFailed(String message);

  /// No description provided for @keysAtsignMismatch.
  ///
  /// In en, this message translates to:
  /// **'This file is for {fileAtsign} but the configured device atSign is {configAtsign}. Use it anyway and change the device atSign?'**
  String keysAtsignMismatch(String fileAtsign, String configAtsign);

  /// No description provided for @useAnyway.
  ///
  /// In en, this message translates to:
  /// **'Use this file'**
  String get useAnyway;

  /// No description provided for @enterAtsign.
  ///
  /// In en, this message translates to:
  /// **'Device atSign'**
  String get enterAtsign;

  /// No description provided for @enrollTitle.
  ///
  /// In en, this message translates to:
  /// **'Enroll this device'**
  String get enrollTitle;

  /// No description provided for @enroll.
  ///
  /// In en, this message translates to:
  /// **'Enroll'**
  String get enroll;

  /// No description provided for @enrollCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Enroll this device with NoPorts Desktop'**
  String get enrollCardTitle;

  /// No description provided for @enrollCardBody.
  ///
  /// In en, this message translates to:
  /// **'Cuts a new set of keys for the device atSign using APKAM and saves them in your ~/.atsign/keys. The request is approved from the NoPorts Desktop app on your client, which holds the atSign\'s manager keys.'**
  String get enrollCardBody;

  /// No description provided for @enrollHowTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get enrollHowTitle;

  /// No description provided for @enrollHowStep1.
  ///
  /// In en, this message translates to:
  /// **'1. In NoPorts Desktop on your client, sign in with the device atSign and open the Authenticator tab.'**
  String get enrollHowStep1;

  /// No description provided for @enrollHowStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Copy the OTP shown there, or set a PIN if you are enrolling several devices.'**
  String get enrollHowStep2;

  /// No description provided for @enrollHowStep3.
  ///
  /// In en, this message translates to:
  /// **'3. After you press Enroll here, approve the request in the same Authenticator tab.'**
  String get enrollHowStep3;

  /// No description provided for @enrollDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get enrollDeviceName;

  /// No description provided for @enrollPasscode.
  ///
  /// In en, this message translates to:
  /// **'OTP or PIN from NoPorts Desktop'**
  String get enrollPasscode;

  /// No description provided for @enrollPasscodeHint.
  ///
  /// In en, this message translates to:
  /// **'6 characters'**
  String get enrollPasscodeHint;

  /// No description provided for @enrollSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending the enrollment request'**
  String get enrollSubmitting;

  /// No description provided for @enrollAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval. Open NoPorts Desktop on your client, go to Authenticator and approve this device.'**
  String get enrollAwaitingApproval;

  /// No description provided for @enrollCreatingKeys.
  ///
  /// In en, this message translates to:
  /// **'Approved. Writing the keys file.'**
  String get enrollCreatingKeys;

  /// No description provided for @enrollmentId.
  ///
  /// In en, this message translates to:
  /// **'Request ID'**
  String get enrollmentId;

  /// No description provided for @enrollSuccess.
  ///
  /// In en, this message translates to:
  /// **'{atsign} is enrolled and its keys are saved.'**
  String enrollSuccess(String atsign);

  /// No description provided for @backupKeysReminder.
  ///
  /// In en, this message translates to:
  /// **'Keep a backup of the .atKeys file somewhere safe. If it is lost the device has to be enrolled again.'**
  String get backupKeysReminder;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get healthTitle;

  /// No description provided for @healthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick checks that the daemon has everything it needs. Run the full doctor for a detailed report.'**
  String get healthSubtitle;

  /// No description provided for @runChecks.
  ///
  /// In en, this message translates to:
  /// **'Run checks'**
  String get runChecks;

  /// No description provided for @runFullDoctor.
  ///
  /// In en, this message translates to:
  /// **'Run full doctor'**
  String get runFullDoctor;

  /// No description provided for @doctorOutput.
  ///
  /// In en, this message translates to:
  /// **'sshnpd --doctor output'**
  String get doctorOutput;

  /// No description provided for @doctorFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not run the doctor: {message}'**
  String doctorFailed(String message);

  /// No description provided for @checkPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get checkPass;

  /// No description provided for @checkWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get checkWarn;

  /// No description provided for @checkFail.
  ///
  /// In en, this message translates to:
  /// **'Fail'**
  String get checkFail;

  /// No description provided for @checksSummary.
  ///
  /// In en, this message translates to:
  /// **'{passed} passed, {warnings} warnings, {failed} failed'**
  String checksSummary(int passed, int warnings, int failed);

  /// No description provided for @wizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up this device for NoPorts'**
  String get wizardTitle;

  /// No description provided for @wizardIntro.
  ///
  /// In en, this message translates to:
  /// **'Four short steps: name this device, enroll it with NoPorts Desktop to get its keys, choose who may connect, then the daemon is started for you.'**
  String get wizardIntro;

  /// No description provided for @stepKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get stepKeys;

  /// No description provided for @stepAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get stepAccess;

  /// No description provided for @stepDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get stepDevice;

  /// No description provided for @stepFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get stepFinish;

  /// No description provided for @wizardKeysBody.
  ///
  /// In en, this message translates to:
  /// **'Enroll this device to cut its keys. You need the OTP or PIN from the Authenticator tab of NoPorts Desktop on your client.'**
  String get wizardKeysBody;

  /// No description provided for @wizardKeysReady.
  ///
  /// In en, this message translates to:
  /// **'Ready: keys for {atsign}'**
  String wizardKeysReady(String atsign);

  /// No description provided for @wizardAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Which client atSigns may connect to this device? You can add more later on the Configuration tab.'**
  String get wizardAccessBody;

  /// No description provided for @wizardDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Which atSign does this device run as, and what is it called? Clients use both to pick this machine. The device atSign is the one you activated in NoPorts Desktop for this device.'**
  String get wizardDeviceBody;

  /// No description provided for @wizardFinishBody.
  ///
  /// In en, this message translates to:
  /// **'Save the configuration and start the daemon.'**
  String get wizardFinishBody;

  /// No description provided for @wizardSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving configuration'**
  String get wizardSaving;

  /// No description provided for @wizardStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting the service'**
  String get wizardStarting;

  /// No description provided for @wizardChecking.
  ///
  /// In en, this message translates to:
  /// **'Running checks'**
  String get wizardChecking;

  /// No description provided for @wizardComplete.
  ///
  /// In en, this message translates to:
  /// **'This device is ready. Connect to it from a NoPorts client using the device atSign and name above.'**
  String get wizardComplete;

  /// No description provided for @wizardCompleteWithIssues.
  ///
  /// In en, this message translates to:
  /// **'Setup finished but some checks need attention. See the Diagnostics tab.'**
  String get wizardCompleteWithIssues;

  /// No description provided for @openDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open dashboard'**
  String get openDashboard;

  /// No description provided for @skipSetup.
  ///
  /// In en, this message translates to:
  /// **'Skip setup'**
  String get skipSetup;

  /// No description provided for @finishAndStart.
  ///
  /// In en, this message translates to:
  /// **'Save and start'**
  String get finishAndStart;

  /// No description provided for @hostname.
  ///
  /// In en, this message translates to:
  /// **'Use this computer\'s name'**
  String get hostname;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
