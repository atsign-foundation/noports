// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get activateUsingLicense => 'activate using a license key';

  @override
  String get activationStatusActivating => 'Activating';

  @override
  String get activationStatusOtpWait => 'Please enter the OTP from your email';

  @override
  String get activationStatusPreparing => 'Preparing for activation';

  @override
  String get addNew => 'Add New';

  @override
  String get advanced => 'Advanced';

  @override
  String get alertDialogTitle => 'Are you sure?';

  @override
  String get allRightsReserved => '@ 2025 Atsign, All Rights Reserved';

  @override
  String get americas => 'Americas';

  @override
  String get approveInstructions =>
      'Please approve request in app with manager keys';

  @override
  String get asiaPacific => 'Asia-Pacific';

  @override
  String get atDirectory => 'AtDirectory';

  @override
  String get atDirectorySubtitle => 'Select the domain you want to use';

  @override
  String get atsignDialogSubtitle => 'Please select your atSign';

  @override
  String get atsignDialogTitle => 'AtSign';

  @override
  String get atsignUncreated => 'Don\'t have an atSign?';

  @override
  String get authenticate => 'Authenticate';

  @override
  String get authorisation => 'Authorisation';

  @override
  String get back => 'Back';

  @override
  String get backUpAtKeys => 'Back Up atKeys';

  @override
  String get backUpAtKeysIntroMsgFirst =>
      'It is important to back up your atKeys so that you can access your data from any device. \n\nIf you lose your atKeys, you will lose access to your data.';

  @override
  String get backUpAtKeysIntroMsgLast =>
      '\n\nYou can save additional backups from the Settings menu anytime.';

  @override
  String get backUpAtKeysMainMsg =>
      'Your atKeys will be used to pair your atSign with this and other devices in the future.\n\natKeys are cryptographic keys that are used to secure your atSign. \n\nThey are unique to you and are used to encrypt and decrypt your data.';

  @override
  String get backupKeyDialogTitle => 'Please select a file to export to:';

  @override
  String get backupYourKey => 'Back Up Your Key';

  @override
  String get cancel => 'Cancel';

  @override
  String get clientAtsignDescription =>
      'An atSign is a resolvable address\nassigned to a device.';

  @override
  String get confirm => 'Confirm';

  @override
  String get connected => 'Connected';

  @override
  String get custom => 'Custom';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get dashboardView => 'Dashboard View';

  @override
  String get debugDumpLogTitle => 'Dev: Dump Logs to terminal';

  @override
  String get defaultRelaySelection => 'Default Relay Selection';

  @override
  String get delete => 'Delete';

  @override
  String get demo => 'Demo';

  @override
  String get demoDescription => 'Click here to load the test profile.';

  @override
  String get demoTextButton => 'Try Now';

  @override
  String get deviceAtsignDescription =>
      'This is the atSign associated with your device.';

  @override
  String get deviceAtsign => 'Device atSign';

  @override
  String get deviceNameDescription => 'This is the name of your remote device.';

  @override
  String get deviceName => 'Device Name';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get discord => 'Discord Support';

  @override
  String get done => 'Done';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get edit => 'Edit';

  @override
  String get email => 'Email Support';

  @override
  String get emptyProfileMessage =>
      'No profiles found\nCreate or Import a profile to start using NoPorts.';

  @override
  String get enableLogging => 'Enable Logging';

  @override
  String get enrollApproved => 'Enrollment request approved';

  @override
  String get enrollDenied => 'Enrollment request denied';

  @override
  String get enroll => 'Enroll';

  @override
  String get enrollRequestDenied => 'Enrollment request denied';

  @override
  String get enrollWithAuthenticatorDescription =>
      'Authenticate through app with manager keys';

  @override
  String get enrollWithAuthenticator => 'Enroll with Authenticator';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String errorAtKeySaveFailed(Object error) {
    return 'Failed to save the atKeys file: $error';
  }

  @override
  String get errorAtKeysFileProcessFailed =>
      'Failed to process the atKeys file';

  @override
  String get errorAtKeysInvalid => 'Invalid atKeys file detected';

  @override
  String get errorAtKeysUploadedMismatch =>
      'The atKeys file you uploaded did not match the atSign requested';

  @override
  String get errorAtServerUnavailable =>
      'Failed to retrieve the atserver status, make sure you have a stable internet connection.';

  @override
  String get errorAtServerUnreachable =>
      'Unable to connect to the atServer, make sure you have a stable internet connection.';

  @override
  String errorAtSignAlreadyPaired(Object atsign) {
    return 'The atSign $atsign is already paired, please contact support.';
  }

  @override
  String get errorAtSignNotExist =>
      'The atSign you have requested doesn\'t exist in this root domain.';

  @override
  String get errorAtSignUnavailable =>
      'The atSign is unavailable. Make sure you have pressed \"Activate\" from your dashboard and have a stable internet connection.';

  @override
  String get errorAuthenticatinFailed => 'Authentication failed.';

  @override
  String get errorAuthenticationTimedOut => 'Authentication timed out.';

  @override
  String get error => 'Error';

  @override
  String get errorOtpRequestFailed =>
      'Failed to request an OTP, try resending, or contact support if the issue persists.';

  @override
  String get errorOtpVerificationFailed =>
      'Failed to verify the OTP with the activation server, please try again. Contact support if the issue persists.';

  @override
  String get errorProfileLoadFailed =>
      'Failed to load this profile, please refresh manually:';

  @override
  String get errorRootDomainNotSupported =>
      'The specified root domain is not supported by automatic activation.';

  @override
  String get errorSwitchAtSignFailed =>
      'Failed to switch atSigns after activation.';

  @override
  String get europe => 'Europe';

  @override
  String get export => 'Export';

  @override
  String get exportLogs => 'Export Logs';

  @override
  String get faq => 'FAQ';

  @override
  String get feedback => 'Feedback';

  @override
  String get fileFormatInvalidDetails =>
      'The profiles section is missing or incorrectly formatted. Please check the document.';

  @override
  String get fileFormatInvalid =>
      'The document format is invalid. Please upload a valid file.';

  @override
  String get fileImported => 'File Imported';

  @override
  String get fileSaved => 'File Saved';

  @override
  String get findOtp =>
      'The request will be displayed in the Authenticator under Requests in any app connected to your atSign with manager keys.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get importFile => 'Import File';

  @override
  String get import => 'Import';

  @override
  String get info => 'Info';

  @override
  String get invalidOtp => 'Invalid OTP';

  @override
  String get json => 'JSON';

  @override
  String get keys => 'Upload atKeys';

  @override
  String get language => 'Language';

  @override
  String get loading => 'Loading';

  @override
  String get localPort => 'Local Port';

  @override
  String get logs => 'Logs';

  @override
  String get minimal => 'Simple';

  @override
  String get myNoPortsMsg => 'Retrieve yours in ';

  @override
  String get next => 'Next';

  @override
  String get noAtsign => 'No atSign';

  @override
  String get noEmailClientAvailable => 'No email client available';

  @override
  String get noName => 'No Name';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get onboardingButtonStatusPicking => 'Waiting for file to be picked';

  @override
  String get onboardingButtonStatusProcessingFile => 'Processing file';

  @override
  String get onboardingError => 'An error has occurred';

  @override
  String get onboardingSubTitle => 'to NoPorts Desktop';

  @override
  String get onboardingTitle => 'Welcome';

  @override
  String get onboard => 'Onboard';

  @override
  String get or => 'Or';

  @override
  String get orSpace => 'or ';

  @override
  String get overrideAllProfile =>
      'Override all profiles with default relay selection';

  @override
  String get pasteProfileDescription => 'Paste the JSON/YAML content here';

  @override
  String get pasteProfile => 'Paste Profile';

  @override
  String get preview => 'Preview';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get profileDeleteMessage =>
      'This profile will be permanently deleted.';

  @override
  String get profileDeleteSecondaryMessage =>
      'Some profiles are running and won\'t be deleted, stop those profiles first to delete them.';

  @override
  String get profileDeleteSelectedMessage =>
      'Selected profiles will be permanently deleted.';

  @override
  String get profileExportDialogTitle => 'Choose Filetype';

  @override
  String get profileExportMessage =>
      'What filetype would you like to export as?';

  @override
  String get profileExportSelectedMessage =>
      'What filetype would you like to export selected profiles as?';

  @override
  String get profileFailedLoaded => 'Profile failed to load';

  @override
  String get profileFailedSaveMessage => 'Profile failed to save';

  @override
  String get profileFailedUnknownMessage => 'No reason provided';

  @override
  String get profileImportDialogTitle => 'Choose Import Method';

  @override
  String get profileImportFailed => 'Failed to import file';

  @override
  String get profileImportSelectedMessage =>
      'How would you like to import a profile?';

  @override
  String get profileNameDescription =>
      'This will be the name of your configurations.';

  @override
  String get profileName => 'Profile Name';

  @override
  String get profile => 'Profile';

  @override
  String get profileRunningActionDeniedMessage =>
      'Cannot perform this action while profile is running.';

  @override
  String get profileRunningCloseMsgStart =>
      'The following profile(s) are connected:';

  @override
  String get profilesFailedLoaded => 'Profiles failed to load';

  @override
  String get profileStatusFailedLoad => 'Failed to load';

  @override
  String get profileStatusFailedSave => 'Failed to Save';

  @override
  String get profileStatusFailedStart => 'Failed to start';

  @override
  String get profileStatusLoaded => 'Disconnected';

  @override
  String get profileStatusLoadedMessage => 'Currently Disconnected';

  @override
  String get profileStatusLoading => 'Loading';

  @override
  String get profileStatusStarted => 'Connected';

  @override
  String get profileStatusStartedMessage => 'Connection successful';

  @override
  String get profileStatusStarting => 'Starting Up';

  @override
  String get profileStatusStopping => 'Shutting Off';

  @override
  String get quit => 'Quit';

  @override
  String get refresh => 'Refresh';

  @override
  String get register => 'register';

  @override
  String get relayDescription =>
      'Choose from our existing relays or create a new one.';

  @override
  String get relay => 'Relay';

  @override
  String get reload => 'Reload';

  @override
  String get remoteHost => 'Remote Host';

  @override
  String get remotePort => 'Remote Port';

  @override
  String get requestExpired =>
      'The original request has expired. Please submit again';

  @override
  String get required => 'Required';

  @override
  String get resendPin => 'Resend Pin';

  @override
  String get resetAtsign => 'Reset atSign';

  @override
  String get rootDomainDefault => 'Default (Prod)';

  @override
  String get rootDomainDemo => 'Demo (VE)';

  @override
  String get saveAtKeys => 'Save atKeys';

  @override
  String get saveLater => 'Save Later';

  @override
  String get selectEnrollMethod => 'Select your enrolment method';

  @override
  String get selectExportFile => 'Please select a file to export to:';

  @override
  String get selectKey => 'Select atKey';

  @override
  String get selectorSubTitleAtsign => 'Enter your NoPorts atSign below.';

  @override
  String get selectorSubTitleRootDomain =>
      'Enter the atDirectory domain (previously called root domain).';

  @override
  String get selectorTitleAtsign => 'NoPorts atSign';

  @override
  String get selectorTitleRootDomain => 'atDirectory Domain';

  @override
  String get serviceMapping => 'Service Mapping';

  @override
  String get settings => 'Settings';

  @override
  String get showWindow => 'Show Window';

  @override
  String get signout => 'Sign Out';

  @override
  String get sshStyle => 'Advanced';

  @override
  String get starting => 'Starting';

  @override
  String get status => 'Status';

  @override
  String get stopping => 'Stopping';

  @override
  String get submitOtp => 'Submit OTP';

  @override
  String get submit => 'Submit';

  @override
  String get success => 'Success';

  @override
  String get switchAtSignDescription =>
      'Are you sure you want to switch atSigns?';

  @override
  String get switchAtSignNote =>
      'Note: Switching atSigns ends all connections.';

  @override
  String get switchAtSign => 'Switch atSign';

  @override
  String get syncInProgress =>
      'Sync in progress. Some profiles may still be loading.';

  @override
  String get typePasteLicense => 'Type/paste your license key';

  @override
  String get unknownError => 'An unknown error occurred';

  @override
  String get uploadKeyDescription => 'Select a local .atkey file';

  @override
  String get uploadKey => 'Upload atKey';

  @override
  String get validationErrorAtsignField => 'Field must be a valid atsign';

  @override
  String get validationErrorDeviceNameField =>
      'Field can only contain lowercase letters, digits, underscores.';

  @override
  String get validationErrorEmptyField => 'This field cannot be left blank';

  @override
  String get validationErrorLocalPortField =>
      'Number must be between 1024 and 65535';

  @override
  String get validationErrorLongField => 'Field must be 1-36 characters long';

  @override
  String get validationErrorRelayField => 'Relay must be a valid atsign';

  @override
  String get validationErrorRemoteHostField =>
      'Field must be partially or fully qualified hostname or an IP address';

  @override
  String get validationErrorRemotePortField =>
      'Number must be between 1 and 65535';

  @override
  String get waitingForApproval => 'Waiting for approval...';

  @override
  String get whatAreAtKeys => 'What are atKeys?';

  @override
  String get whatIsClientAtsign => 'What is a NoPorts atSign?';

  @override
  String get whereToAcceptDescription =>
      'Please approve the request in an app with a manager key.';

  @override
  String get whereToAccept => 'Where to accept?';

  @override
  String get yamlRecommended => 'YAML (Recommended)';

  @override
  String get yaml => 'YAML';
}
