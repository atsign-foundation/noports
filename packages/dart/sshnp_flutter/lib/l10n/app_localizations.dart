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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addKey.
  ///
  /// In en, this message translates to:
  /// **'Add Key'**
  String get addKey;

  /// No description provided for @addNewConnection.
  ///
  /// In en, this message translates to:
  /// **'Add New Connection'**
  String get addNewConnection;

  /// No description provided for @addNewConnectionDescription.
  ///
  /// In en, this message translates to:
  /// **'To create a new connection as fast as possible, only fill in required fields, the rest will auto populate by default. You can always change your configurations later.'**
  String get addNewConnectionDescription;

  /// No description provided for @advancedConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Advanced Configuration'**
  String get advancedConfiguration;

  /// No description provided for @atKeysFilePath.
  ///
  /// In en, this message translates to:
  /// **'atKeys File'**
  String get atKeysFilePath;

  /// No description provided for @authenticateClientToRvd.
  ///
  /// In en, this message translates to:
  /// **'Authenticate Client to Socket Rendezvous'**
  String get authenticateClientToRvd;

  /// No description provided for @authenticateClientToRvdTooltip.
  ///
  /// In en, this message translates to:
  /// **'When true, client will authenticate itself to rvd'**
  String get authenticateClientToRvdTooltip;

  /// No description provided for @authenticateDeviceToRvd.
  ///
  /// In en, this message translates to:
  /// **'Authenticate Device to Socket Rendezvous'**
  String get authenticateDeviceToRvd;

  /// No description provided for @authenticateDeviceToRvdTooltip.
  ///
  /// In en, this message translates to:
  /// **'When true, Device will authenticate itself to rvd'**
  String get authenticateDeviceToRvdTooltip;

  /// No description provided for @availableConnections.
  ///
  /// In en, this message translates to:
  /// **'Available Connections'**
  String get availableConnections;

  /// No description provided for @backupYourKeys.
  ///
  /// In en, this message translates to:
  /// **'Backup Your Keys'**
  String get backupYourKeys;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @clientAtsign.
  ///
  /// In en, this message translates to:
  /// **'Client atsign'**
  String get clientAtsign;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @commands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commands;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectionConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Connection Configuration'**
  String get connectionConfiguration;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to Clipboard'**
  String get copiedToClipboard;

  /// No description provided for @corruptedPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Status: Private Key is corrupted'**
  String get corruptedPrivateKey;

  /// No description provided for @corruptedProfile.
  ///
  /// In en, this message translates to:
  /// **'Status: profile is corrupted'**
  String get corruptedProfile;

  /// No description provided for @connectionProfiles.
  ///
  /// In en, this message translates to:
  /// **'Connection Profiles'**
  String get connectionProfiles;

  /// No description provided for @currentConnectionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and manage connection profiles'**
  String get currentConnectionsDescription;

  /// No description provided for @createConnectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Start New Connection Profile'**
  String get createConnectionProfile;

  /// No description provided for @createConnectionProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'Click to set up a connection profile for SSH access to you remote device'**
  String get createConnectionProfileDesc;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @dest.
  ///
  /// In en, this message translates to:
  /// **'Dest.'**
  String get dest;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get device;

  /// No description provided for @deviceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Receiving device name'**
  String get deviceTooltip;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @encryptRvdTraffic.
  ///
  /// In en, this message translates to:
  /// **'Encrypt RVD Traffic'**
  String get encryptRvdTraffic;

  /// No description provided for @encryptRvdTrafficTooltip.
  ///
  /// In en, this message translates to:
  /// **'When true, traffic via the socket rendezvous is encrypted, in addition to whatever encryption the traffic already has, (e.g. an ssh session)'**
  String get encryptRvdTrafficTooltip;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @privateKeyFormFieldError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the private key manager. Please try again.'**
  String get privateKeyFormFieldError;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @getStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Get Started!'**
  String get getStartedTitle;

  /// No description provided for @getStartedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first connection'**
  String get getStartedSubtitle;

  /// No description provided for @getStartedNoConnections.
  ///
  /// In en, this message translates to:
  /// **'You currently have no connections'**
  String get getStartedNoConnections;

  /// No description provided for @homeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Home Directory'**
  String get homeDirectory;

  /// No description provided for @homeDirectoryHint.
  ///
  /// In en, this message translates to:
  /// **'The home directory on this host'**
  String get homeDirectoryHint;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'SR Address (atSign) *'**
  String get host;

  /// No description provided for @hostTooltip.
  ///
  /// In en, this message translates to:
  /// **'atSign of srvd daemon or FQDN/IP address to connect back to'**
  String get hostTooltip;

  /// No description provided for @hostHintText.
  ///
  /// In en, this message translates to:
  /// **'eg. @rv_am'**
  String get hostHintText;

  /// No description provided for @hostSelection.
  ///
  /// In en, this message translates to:
  /// **'Host Selection'**
  String get hostSelection;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importProfile.
  ///
  /// In en, this message translates to:
  /// **'Import Profile'**
  String get importProfile;

  /// No description provided for @keyFile.
  ///
  /// In en, this message translates to:
  /// **'Key File'**
  String get keyFile;

  /// No description provided for @listDevices.
  ///
  /// In en, this message translates to:
  /// **'List Devices'**
  String get listDevices;

  /// No description provided for @localPort.
  ///
  /// In en, this message translates to:
  /// **'Client-side port for the ssh tunnel'**
  String get localPort;

  /// No description provided for @localPortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Defaults to 0 (ask the o/s for a port)'**
  String get localPortTooltip;

  /// No description provided for @localSshOptions.
  ///
  /// In en, this message translates to:
  /// **'Local SSH Options'**
  String get localSshOptions;

  /// No description provided for @localSshOptionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add these commands to the local ssh command'**
  String get localSshOptionsTooltip;

  /// No description provided for @localSshOptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Use \",\" to separate options'**
  String get localSshOptionsHint;

  /// No description provided for @newSshKeyCreation.
  ///
  /// In en, this message translates to:
  /// **'New SSH Key Creation'**
  String get newSshKeyCreation;

  /// No description provided for @newText.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newText;

  /// No description provided for @noAtsignToReset.
  ///
  /// In en, this message translates to:
  /// **'No atSigns are paired to reset.'**
  String get noAtsignToReset;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @noteMessage.
  ///
  /// In en, this message translates to:
  /// **': You cannot undo this action.'**
  String get noteMessage;

  /// No description provided for @noTerminalSessions.
  ///
  /// In en, this message translates to:
  /// **'No active terminal sessions'**
  String get noTerminalSessions;

  /// No description provided for @noTerminalSessionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a new session from the home screen'**
  String get noTerminalSessionsHelp;

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get okButton;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @onboardButtonDescription.
  ///
  /// In en, this message translates to:
  /// **'Onboard with Client Address (atSign)'**
  String get onboardButtonDescription;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Remote Port'**
  String get port;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'SSH Private Key *'**
  String get privateKey;

  /// No description provided for @privateKeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Private Key for authentication'**
  String get privateKeyTooltip;

  /// No description provided for @privateKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the keys you want to use when establishing a connection with this profile'**
  String get privateKeyDescription;

  /// No description provided for @privateKeyNotFound.
  ///
  /// In en, this message translates to:
  /// **'No Private Key Found'**
  String get privateKeyNotFound;

  /// No description provided for @privateKeyNickname.
  ///
  /// In en, this message translates to:
  /// **'Private Key Nickname'**
  String get privateKeyNickname;

  /// No description provided for @privateKeyNicknameToolTip.
  ///
  /// In en, this message translates to:
  /// **'Identifier of the Private Key'**
  String get privateKeyNicknameToolTip;

  /// No description provided for @privateKeyManagement.
  ///
  /// In en, this message translates to:
  /// **'Private Key Management'**
  String get privateKeyManagement;

  /// No description provided for @privateKeyManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and Configure your private key'**
  String get privateKeyManagementDescription;

  /// No description provided for @privateKeyPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Private Key Passphrase'**
  String get privateKeyPassphrase;

  /// No description provided for @privatekeyPassPhraseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Passphrase of the Private Key'**
  String get privatekeyPassPhraseTooltip;

  /// Required fields
  ///
  /// In en, this message translates to:
  /// **'{fieldStatus, select, required{Profile Name *} other{Profile Name}}'**
  String profileName(String fieldStatus);

  /// No description provided for @profileNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Name of the profile to use'**
  String get profileNameTooltip;

  /// No description provided for @profileNameHintText.
  ///
  /// In en, this message translates to:
  /// **'eg. Alice Linux VM'**
  String get profileNameHintText;

  /// No description provided for @remoteSshdPort.
  ///
  /// In en, this message translates to:
  /// **'Remote SSHD Port'**
  String get remoteSshdPort;

  /// No description provided for @remoteSshdPortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Port on which sshd is listening locally on the device host'**
  String get remoteSshdPortTooltip;

  /// No description provided for @remoteUsername.
  ///
  /// In en, this message translates to:
  /// **'Session username'**
  String get remoteUsername;

  /// No description provided for @remoteUsernameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Username to use in the ssh session on the remote host'**
  String get remoteUsernameTooltip;

  /// No description provided for @remoteUsernameHintText.
  ///
  /// In en, this message translates to:
  /// **'eg. alice'**
  String get remoteUsernameHintText;

  /// No description provided for @removeButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetDescription.
  ///
  /// In en, this message translates to:
  /// **'This will remove the selected atSign and its details from this app only.'**
  String get resetDescription;

  /// No description provided for @resetErrorText.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one atSign to reset'**
  String get resetErrorText;

  /// No description provided for @resetWarningText.
  ///
  /// In en, this message translates to:
  /// **'Warning: This action cannot be undone'**
  String get resetWarningText;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @rootDomain.
  ///
  /// In en, this message translates to:
  /// **'atDirectory Root Domain'**
  String get rootDomain;

  /// No description provided for @rootDomainTooltip.
  ///
  /// In en, this message translates to:
  /// **'atDirectory domain'**
  String get rootDomainTooltip;

  /// No description provided for @rsa.
  ///
  /// In en, this message translates to:
  /// **'Legacy RSA Key'**
  String get rsa;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectAFile.
  ///
  /// In en, this message translates to:
  /// **'Select a file'**
  String get selectAFile;

  /// No description provided for @selectPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Select Private Key'**
  String get selectPrivateKey;

  /// No description provided for @sendSshPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Share SSH Public Key'**
  String get sendSshPublicKey;

  /// No description provided for @sendSshPublicKeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'When true, the ssh public key will be sent to the remote host for use in the ssh session'**
  String get sendSshPublicKeyTooltip;

  /// No description provided for @sessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get sessionId;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @supportDescription.
  ///
  /// In en, this message translates to:
  /// **'Our team of experts is here to help! Select your preferred method below'**
  String get supportDescription;

  /// No description provided for @sourcePort.
  ///
  /// In en, this message translates to:
  /// **'Source Port'**
  String get sourcePort;

  /// No description provided for @socketRendezvousConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Socket Rendezvous Configuration'**
  String get socketRendezvousConfiguration;

  /// No description provided for @srvdAtsign.
  ///
  /// In en, this message translates to:
  /// **'SR Address (atSign)'**
  String get srvdAtsign;

  /// No description provided for @srvdAtsignTooltip.
  ///
  /// In en, this message translates to:
  /// **'atSign of the socket rendezvous'**
  String get srvdAtsignTooltip;

  /// No description provided for @sshAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'SSH Algorithm'**
  String get sshAlgorithm;

  /// No description provided for @sshButton.
  ///
  /// In en, this message translates to:
  /// **'ssh'**
  String get sshButton;

  /// split text on new line
  ///
  /// In en, this message translates to:
  /// **'{newLine, select, yes{SSH Key \nConfiguration} no{SSH Key Management} other{SSH Key Management}}'**
  String sshKeyManagement(String newLine);

  /// No description provided for @sshnpdAtSign.
  ///
  /// In en, this message translates to:
  /// **'Device Address (atSign) *'**
  String get sshnpdAtSign;

  /// No description provided for @sshnpdAtSignHint.
  ///
  /// In en, this message translates to:
  /// **'The atSign of the sshnpd we wish to communicate with'**
  String get sshnpdAtSignHint;

  /// No description provided for @sshnpdAtSignTooltip.
  ///
  /// In en, this message translates to:
  /// **'Receiving device atSign'**
  String get sshnpdAtSignTooltip;

  /// No description provided for @sshnpdAtSignHintText.
  ///
  /// In en, this message translates to:
  /// **'eg. @alice_device'**
  String get sshnpdAtSignHintText;

  /// No description provided for @sshPublicKey.
  ///
  /// In en, this message translates to:
  /// **'SSH Public Key'**
  String get sshPublicKey;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @switchAtsign.
  ///
  /// In en, this message translates to:
  /// **'Switch atSign'**
  String get switchAtsign;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @terminalDescription.
  ///
  /// In en, this message translates to:
  /// **'Connections currently running'**
  String get terminalDescription;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @tunnelUsername.
  ///
  /// In en, this message translates to:
  /// **'Tunnel Username'**
  String get tunnelUsername;

  /// No description provided for @tunnelUsernameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Username to use for the initial ssh tunnel'**
  String get tunnelUsernameTooltip;

  /// No description provided for @tunnelUsernameHintText.
  ///
  /// In en, this message translates to:
  /// **'eg. alice'**
  String get tunnelUsernameHintText;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'The user name on this host'**
  String get usernameHint;

  /// No description provided for @uploadNewKey.
  ///
  /// In en, this message translates to:
  /// **'Upload New Key'**
  String get uploadNewKey;

  /// No description provided for @verbose.
  ///
  /// In en, this message translates to:
  /// **'Verbose Logging'**
  String get verbose;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @warningMessage.
  ///
  /// In en, this message translates to:
  /// **' Are you sure you want to delete this configuration'**
  String get warningMessage;

  /// No description provided for @yourKeys.
  ///
  /// In en, this message translates to:
  /// **'Your Keys'**
  String get yourKeys;

  /// No description provided for @welcomeTo.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcomeTo;

  /// No description provided for @sshnpDesktopApp.
  ///
  /// In en, this message translates to:
  /// **'SSHNP Desktop App'**
  String get sshnpDesktopApp;

  /// No description provided for @welcomeToDescription.
  ///
  /// In en, this message translates to:
  /// **'Make your devices reachable while eliminating network attack surfaces & reducing administrative overhead.'**
  String get welcomeToDescription;
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
      'that was used.');
}
