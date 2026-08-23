// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get activate => 'Activate';

  @override
  String get activating => 'Activating';

  @override
  String get activationAtsignFileStorageLocation =>
      'Select a folder to save your .atKeys files';

  @override
  String get activationAtsignListDescription =>
      'The following Atsigns will be activated:';

  @override
  String get activationButtonDescription =>
      'Complete Activation and set up a new Atsign';

  @override
  String get activationComplete => 'Complete Activation';

  @override
  String get activationFileBased => 'File-based Activation';

  @override
  String get activationFileBasedDescription =>
      'Please upload your activation file (.yaml).\nThis file is downloaded from your Management Portal.';

  @override
  String get activationFileErrorMessage =>
      'Please use a valid activation file.';

  @override
  String get activationFileLoadingMessage => 'Processing File...';

  @override
  String get activationFileSuccessMessage =>
      'Activation file uploaded successfully!';

  @override
  String get activationFileUploadDragDropDescription =>
      'Upload or drag & drop your one-time activation file (.yaml)';

  @override
  String get activationInProgress =>
      'Activating, please wait until every Atsign has finished.';

  @override
  String get activationKeyStatusActivated => 'Activated';

  @override
  String get activationKeyStatusActivating => 'Activating';

  @override
  String get activationKeyStatusAlreadyActivated => 'Already Activated';

  @override
  String get activationKeyStatusFailed => 'Failed';

  @override
  String get activationKeyStatusWaiting => 'Waiting';

  @override
  String get activationManual => 'Manual Activation';

  @override
  String get activationRetryFailed => 'Retry Failed';

  @override
  String get activationStatus => 'Activation Status';

  @override
  String get activationStatusActivating => 'Activating';

  @override
  String activationStatusCount(Object current, Object total) {
    return '$current of $total Atsigns activated:';
  }

  @override
  String get activationStatusOtpWait => 'Please enter the OTP from your email';

  @override
  String get activationStatusPreparing => 'Preparing for activation';

  @override
  String get add => 'Add';

  @override
  String get addAtsign => 'Add Atsign';

  @override
  String get addNew => 'Add New';

  @override
  String get advanced => 'Advanced';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get alertDialogTitle => 'Are you sure?';

  @override
  String get allRightsReserved => '© 2026 Atsign, All Rights Reserved';

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
  String get atsignDialogSubtitle => 'Please select your Atsign';

  @override
  String get atsignDialogTitle => 'Atsign';

  @override
  String get atsignFrom => 'From Atsign';

  @override
  String get atsignsUser => 'User Atsign';

  @override
  String get atsignsUserTooltip =>
      'An Atsign like \"@alice\" that will be connecting to other devices';

  @override
  String get atsignTo => 'To Atsign';

  @override
  String get atsignUncreated => 'Don\'t have an Atsign?';

  @override
  String get authenticate => 'Authenticate';

  @override
  String get authenticator => 'Authenticator';

  @override
  String get authorisation => 'Authorisation';

  @override
  String get autoStartApplication => 'Auto-Start Client Application';

  @override
  String get back => 'Back';

  @override
  String get backUp => 'Back Up';

  @override
  String get backUpAtKeys => 'Back Up atKeys';

  @override
  String backUpAtKeysIntroMsgFirst(String saveOrBackup) {
    String _temp0 = intl.Intl.selectLogic(saveOrBackup, {
      'save': 'save',
      'other': 'backup',
    });
    return 'It is important to $_temp0 your atKeys so that you can access your data from any device. \n\nIf you lose your atKeys, you will lose access to your data.';
  }

  @override
  String get backUpAtKeysIntroMsgLast =>
      '\n\nYou can save additional backups from the Settings menu anytime.';

  @override
  String get backUpAtKeysMainMsg =>
      'Your atKeys will be used to pair your Atsign with this and other devices in the future.\n\natKeys are cryptographic keys that are used to secure your Atsign. \n\nThey are unique to you and are used to encrypt and decrypt your data.';

  @override
  String get backupKeyDialogTitle => 'Please select a file to export to:';

  @override
  String get backupYourKey => 'Back Up Your Key';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get connected => 'Connected';

  @override
  String get connectionClosed => 'Connection closed, will retry...';

  @override
  String get connectionRetrying => 'Retrying connection (keep-alive)...';

  @override
  String get connections => 'Connections';

  @override
  String get connectionTimedOut => 'Connection timed out, will retry...';

  @override
  String get connectUriProtocolDescription =>
      'This setting automatically launches the appropriate application after a connection is established, based on the selected protocol. If no protocol is selected, no application will be launched. Select the protocol to use for the connection.';

  @override
  String get connectUriProtocolNone => 'None';

  @override
  String get connectUriUsername => 'Username';

  @override
  String get connectUriUsernameDescription =>
      'Optional username for protocols like SSH (e.g., user in ssh://user@host)';

  @override
  String get couldNotLoadPreviousState => 'Could not load previous state error';

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
  String get description => 'Description';

  @override
  String get deviceAdd => 'Add Device';

  @override
  String get deviceAtsign => 'Device Atsign';

  @override
  String get deviceAtsignDescription =>
      'This is the Atsign associated with your device.';

  @override
  String get deviceAtsignDescriptionTwo =>
      'An Atsign like \"@bob_device\", that will be connected to. This is also known as the daemon or npd machine that is running the daemon process that will be receiving connection requests where connections will be established to this device.';

  @override
  String get deviceAtsigns => 'Device Atsign';

  @override
  String get deviceEdit => 'Edit Device';

  @override
  String get deviceGroup => 'Device Group';

  @override
  String get deviceGroupAdd => 'Add Device Group';

  @override
  String get deviceGroupEdit => 'Edit Device Group';

  @override
  String get deviceGroupNo => 'No Device Group';

  @override
  String get deviceGroups => 'Device Groups';

  @override
  String get deviceGroupsNotAdded => 'No device groups added yet';

  @override
  String get deviceGroupTooltip =>
      'Daemon processes that specify the --dg option with a string will allow connections from user to the specified host:ports';

  @override
  String get deviceName => 'Device Name';

  @override
  String get deviceNameDescription => 'This is the name of your remote device.';

  @override
  String get devices => 'Devices';

  @override
  String get devicesNotAdded => 'No devices added yet';

  @override
  String get devicesTooltip =>
      'A device name string like \"default\" that is under a device Atsign. A device Atsign can have multiple device names, device names help distinguish individual device daemon processes. Adding a device name here will allow tunnels to be established from the user Atsign to this device Atsign/device name pair.';

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
      'No profiles found.\nCreate or Import a profile to start using NoPorts.';

  @override
  String get enableLogging => 'Enable Logging';

  @override
  String get enroll => 'Enroll';

  @override
  String get enrollApproved => 'Enrollment request approved';

  @override
  String get enrollDenied => 'Enrollment request denied';

  @override
  String get enrollRequestDenied => 'Enrollment request denied';

  @override
  String get enrollWithAuthenticator => 'Enroll with Authenticator';

  @override
  String get enrollWithAuthenticatorDescription =>
      'Authenticate through app with manager keys';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String get error => 'Error';

  @override
  String get errorActivationKeysConflict =>
      'This Atsign was previously onboarded with a different set of keys. Remove it from the app and try again.';

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
      'The atKeys file you uploaded did not match the Atsign requested';

  @override
  String get errorAtServerUnavailable =>
      'Failed to retrieve the atserver status, make sure you have a stable internet connection.';

  @override
  String get errorAtServerUnreachable =>
      'Unable to connect to the atServer, make sure you have a stable internet connection.';

  @override
  String errorAtsignAlreadyPaired(Object atsign) {
    return 'The Atsign $atsign is already paired, please contact support.';
  }

  @override
  String get errorAtsignNotExist =>
      'The Atsign you have requested doesn\'t exist in this root domain.';

  @override
  String get errorAtsignUnavailable =>
      'The Atsign is unavailable. Make sure you have pressed \"Activate\" from your dashboard and have a stable internet connection.';

  @override
  String get errorCramAuthFailed =>
      'The activation key was rejected by the atServer. This activation file may have already been used.';

  @override
  String errorOnboardingWithDetails(Object details) {
    return 'Onboarding failed: $details';
  }

  @override
  String get errorAuthenticatinFailed => 'Authentication failed.';

  @override
  String get errorAuthenticationTimedOut => 'Authentication timed out.';

  @override
  String errorDuringStartupWithDetails(Object errorMessage) {
    return 'Error during startup: $errorMessage';
  }

  @override
  String get errorOtpRequestFailed =>
      'Failed to request an OTP, try resending, or contact support if the issue persists.';

  @override
  String get errorOtpVerificationFailed =>
      'Failed to verify the OTP with the activation server, please try again. Contact support if the issue persists.';

  @override
  String get errorProfileLoadFailed => 'Failed to load this profile';

  @override
  String get errorRootDomainNotSupported =>
      'The specified root domain is not supported by automatic activation.';

  @override
  String get errorSwitchAtsignFailed =>
      'Failed to switch Atsign after activation.';

  @override
  String errorWithDetails(Object errorMessage) {
    return 'Error: $errorMessage,';
  }

  @override
  String get europe => 'Europe';

  @override
  String get export => 'Export';

  @override
  String get exportLogs => 'Export Logs';

  @override
  String get faq => 'FAQ';

  @override
  String get fastest => 'Fastest';

  @override
  String get feedback => 'Feedback';

  @override
  String get fileFormatInvalid =>
      'The document format is invalid. Please upload a valid file.';

  @override
  String get fileFormatInvalidDetails =>
      'The profiles section is missing or incorrectly formatted. Please check the document.';

  @override
  String get fileImported => 'File Imported';

  @override
  String get fileSaved => 'File Saved';

  @override
  String get findOtp =>
      'The request will be displayed in the Authenticator under Requests in any app connected to your Atsign with manager keys.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get groupAdd => 'Add Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get import => 'Import';

  @override
  String get importFile => 'Import File';

  @override
  String get info => 'Info';

  @override
  String get invalidOtp => 'Invalid OTP';

  @override
  String get json => 'JSON';

  @override
  String get jsonCopyToClipboard => 'Copy JSON to Clipboard';

  @override
  String get jsonPayloadCopiedToClipboard => 'JSON payload copied to clipboard';

  @override
  String get keys => 'Upload atKeys';

  @override
  String get language => 'Language';

  @override
  String get loading => 'Loading';

  @override
  String get localHost => 'Local Host';

  @override
  String get localHostDescription =>
      'The hostname or IP address to bind to on your local machine';

  @override
  String get localPort => 'Local Port';

  @override
  String get localPortDescription =>
      'The port you\'ll use on your local machine';

  @override
  String get logs => 'Logs';

  @override
  String get logsClear => 'Clear Logs';

  @override
  String get logsNotAvailable =>
      'No logs available yet.\nActivity will appear here when policy requests are made.';

  @override
  String get logsNotAvailableStartMonitoring =>
      'No logs available.\nStart monitoring from the Policy Manager to see activity.';

  @override
  String get logsView => 'View Logs';

  @override
  String get logType => 'Log Type';

  @override
  String get manageAtsigns => 'Manage Atsign';

  @override
  String get minimal => 'Simple';

  @override
  String get monitoringActive => 'Monitoring Active';

  @override
  String get monitoringInactive => 'Monitoring Inactive';

  @override
  String get monitoringStart => 'Start Monitoring';

  @override
  String get monitoringStop => 'Stop Monitoring';

  @override
  String get myNoPortsMsg => 'Retrieve yours in My NoPorts →';

  @override
  String get name => 'Name';

  @override
  String get next => 'Next';

  @override
  String get noAtsign => 'No Atsign';

  @override
  String get noAtsignsAdded => 'No Atsign added yet';

  @override
  String get noDescription => 'No description';

  @override
  String get noEmailClientAvailable => 'No email client available';

  @override
  String get noName => 'No Name';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get nptStartupTimedout => 'Npt startup timed out';

  @override
  String get ok => 'OK';

  @override
  String get onboard => 'Onboard';

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
  String get or => 'OR';

  @override
  String get overrideAllProfile =>
      'Override all profiles with default relay selection';

  @override
  String get pasteProfile => 'Paste Profile';

  @override
  String get pasteProfileDescription => 'Paste the JSON/YAML content here';

  @override
  String permitOpens(Object permitOpens) {
    return 'Permit Opens: $permitOpens';
  }

  @override
  String get permitOpensHostPort => 'Permit Opens (host:port)';

  @override
  String get permitOpensNotConfigured => 'No permit opens configured';

  @override
  String get policy => 'Policy';

  @override
  String get policyLogs => 'Policy Logs';

  @override
  String get policyManager => 'Policy Manager';

  @override
  String get policyRequestPayload => 'Policy Request Payload';

  @override
  String get preview => 'Preview';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get profile => 'Profile';

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
  String get profileKeepAlive => '🕺 Keep Alive';

  @override
  String get profileKeepAliveDescription =>
      'Stay alive. If a session ends, create a new session and re-bind to the local port. Sessions can end due to being unused after a timeout or network issues.';

  @override
  String get profileName => 'Profile Name';

  @override
  String get profileNameDescription =>
      'This will be the name of your configurations.';

  @override
  String get profilePort443 => 'Use Port 443';

  @override
  String get profilePort443Description =>
      'Forces the relay to use port 443 instead of an ephemeral port. Automatically enables ESCR relay authentication mode for security.';

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
  String get register => 'Register';

  @override
  String get relay => 'Relay';

  @override
  String get relayDescription =>
      'Choose from our existing relays or create a new one.';

  @override
  String get reload => 'Reload';

  @override
  String get remoteHost => 'Remote Host';

  @override
  String get remoteHostDescription =>
      'The hostname or IP address of the service you are connecting to on the remote machine';

  @override
  String get remotePort => 'Remote Port';

  @override
  String get remotePortDescription =>
      'The port that will be used on the remote machine';

  @override
  String get removeAtsign => 'Remove Atsign';

  @override
  String get selectAll => 'Select All';

  @override
  String get noAtsignsToRemove => 'No atsigns found to remove.';

  @override
  String get requestExpired =>
      'The original request has expired. Please submit again';

  @override
  String get required => 'Required';

  @override
  String get resendPin => 'Resend Pin';

  @override
  String retryFailedWithDetails(Object errorMessage) {
    return 'Retry failed: $errorMessage, will retry...';
  }

  @override
  String get roleAddNew => 'Add New Role';

  @override
  String get roleCreatingFailed => 'Failed to create role';

  @override
  String roleCreatingFailedWithDetails(Object errorMessage) {
    return 'Failed to create role: $errorMessage';
  }

  @override
  String get roleDelete => 'Delete Role';

  @override
  String roleDeleteConfirmation(Object roleName) {
    return 'Are you sure you want to delete the role \"$roleName\"? This action cannot be undone.';
  }

  @override
  String get roleDeletedSuccessfully => 'Role deleted successfully!';

  @override
  String get roleDeletingFailed => 'Failed to delete role';

  @override
  String roleDeletingFailedWithDetails(Object errorMessage) {
    return 'Failed to delete role: $errorMessage';
  }

  @override
  String roleLoadingFailedWithDetails(Object errorMessage) {
    return 'Failed to load role: $errorMessage';
  }

  @override
  String get roleNotFound => 'No roles found';

  @override
  String get roleNotLoaded => 'No role loaded';

  @override
  String get roles => 'Roles';

  @override
  String get roleSaveFailed => 'Failed to save role';

  @override
  String roleSaveFailedWithDetails(Object errorMessage) {
    return 'Failed to save role: $errorMessage';
  }

  @override
  String get roleSelectToViewDetails => 'Select a role to view details';

  @override
  String rolesLoadingFailedWithDetails(Object errorMessage) {
    return 'Failed to load roles: $errorMessage';
  }

  @override
  String get rolesRefresh => 'Refresh Roles';

  @override
  String get roleUpdatingFailed => 'Failed to update role';

  @override
  String roleUpdatingFailedWithDetails(Object errorMessage) {
    return 'Failed to update role: $errorMessage';
  }

  @override
  String get rootDomainDefault => 'Default (Prod)';

  @override
  String get rootDomainDemo => 'Demo (VE)';

  @override
  String get save => 'Save';

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
  String get selectorSubTitleAtsign => 'Enter your NoPorts Atsign below.';

  @override
  String get selectorSubTitleRootDomain => 'Enter the atDirectory domain.';

  @override
  String get selectorTitleAtsign => 'NoPorts Atsign';

  @override
  String get selectorTitleRootDomain => 'atDirectory Domain';

  @override
  String get serviceMapping => 'Service Mapping';

  @override
  String get servicesAllowed => 'Allowed Services';

  @override
  String get settings => 'Settings';

  @override
  String get settingsCouldNotFetch => 'Could not fetch settings';

  @override
  String get showWindow => 'Show Window';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInButtonDescription => 'Sign in with an activated Atsign';

  @override
  String get signout => 'Sign Out';

  @override
  String get socketconnectorClosedPrematurely =>
      'Socketconnector Closed Prematurely';

  @override
  String get sshStyle => 'Advanced';

  @override
  String get starting => 'Starting';

  @override
  String get status => 'Status';

  @override
  String get stopping => 'Stopping';

  @override
  String get submit => 'Submit';

  @override
  String get submitOtp => 'Submit OTP';

  @override
  String get success => 'Success';

  @override
  String get switchAtsign => 'Switch Atsign';

  @override
  String get switchAtsignDescription =>
      'Are you sure you want to switch Atsign?';

  @override
  String get switchAtsignNote => 'Note: Switching Atsign ends all connections.';

  @override
  String get syncCompleted => 'Sync completed. All profiles loaded.';

  @override
  String get syncInProgress =>
      'Sync in progress. Some profiles may still be loading.';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get unknownError => 'An unknown error occurred';

  @override
  String get uploadKey => 'Upload atKey';

  @override
  String get uploadKeyDescription => 'Select a local .atkey file';

  @override
  String get validationErrorAtsignField => 'Field must be a valid atsign';

  @override
  String get validationErrorDeviceNameField =>
      'Field can only contain lowercase letters, digits, underscores.';

  @override
  String get validationErrorEmptyField => 'This field cannot be left blank';

  @override
  String get validationErrorHostField =>
      'Field must be partially or fully qualified hostname or an IP address';

  @override
  String get validationErrorLocalPortField =>
      'Number must be between 1024 and 65535';

  @override
  String get validationErrorLongField => 'Field must be 1-36 characters long';

  @override
  String get validationErrorRelayField => 'Relay must be a valid atsign';

  @override
  String get validationErrorRemotePortField =>
      'Number must be between 1 and 65535';

  @override
  String get waitingForApproval => 'Waiting for approval...';

  @override
  String get errorServerUnavailable =>
      'The server is currently unavailable. Please try again later.';

  @override
  String get errorAtsignActivated => 'This atsign has already been activated.';

  @override
  String get msgAtsignUnreachable => 'The atsign server could not be reached.';

  @override
  String get errorAuthenticationFailed =>
      'Authentication failed. Please check your details and try again.';

  @override
  String get msgResponseTimeOut => 'The request timed out. Please try again.';

  @override
  String get whatAreAtKeys => 'What are atKeys?';

  @override
  String get whatIsAnAtsign => 'What is an Atsign?';

  @override
  String get whatIsAnAtsignDescription =>
      'An Atsign is both an address and a unique identifier for your device.';

  @override
  String get whereToAccept => 'Where to accept?';

  @override
  String get whereToAcceptDescription =>
      'Please approve the request in an app with a manager key.';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (Recommended)';

  @override
  String get errorEnrollmentRevoked =>
      'Your enrollment has been revoked. Please sign in again to request a new enrollment.';
}
