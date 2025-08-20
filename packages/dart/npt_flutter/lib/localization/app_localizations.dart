import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('zh'),
    Locale.fromSubtags(
      languageCode: 'zh',
      countryCode: 'CH',
      scriptCode: 'Hans',
    ),
    Locale.fromSubtags(
      languageCode: 'zh',
      countryCode: 'HK',
      scriptCode: 'Hant',
    ),
  ];

  /// No description provided for @activationStatusActivating.
  ///
  /// In en, this message translates to:
  /// **'Activating'**
  String get activationStatusActivating;

  /// No description provided for @activationStatusOtpWait.
  ///
  /// In en, this message translates to:
  /// **'Please enter the OTP from your email'**
  String get activationStatusOtpWait;

  /// No description provided for @activationStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing for activation'**
  String get activationStatusPreparing;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNew;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @alertDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get alertDialogTitle;

  /// No description provided for @allRightsReserved.
  ///
  /// In en, this message translates to:
  /// **'@ 2025 Atsign, All Rights Reserved'**
  String get allRightsReserved;

  /// No description provided for @americas.
  ///
  /// In en, this message translates to:
  /// **'Americas'**
  String get americas;

  /// No description provided for @approveInstructions.
  ///
  /// In en, this message translates to:
  /// **'Please approve request in app with manager keys'**
  String get approveInstructions;

  /// No description provided for @asiaPacific.
  ///
  /// In en, this message translates to:
  /// **'Asia-Pacific'**
  String get asiaPacific;

  /// No description provided for @atDirectory.
  ///
  /// In en, this message translates to:
  /// **'AtDirectory'**
  String get atDirectory;

  /// No description provided for @atDirectorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the domain you want to use'**
  String get atDirectorySubtitle;

  /// No description provided for @atsignDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please select your atSign'**
  String get atsignDialogSubtitle;

  /// No description provided for @atsignDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'AtSign'**
  String get atsignDialogTitle;

  /// No description provided for @atsignUncreated.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an atSign?'**
  String get atsignUncreated;

  /// No description provided for @authenticate.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get authenticate;

  /// No description provided for @authorisation.
  ///
  /// In en, this message translates to:
  /// **'Authorisation'**
  String get authorisation;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backUpAtKeys.
  ///
  /// In en, this message translates to:
  /// **'Back Up atKeys'**
  String get backUpAtKeys;

  /// No description provided for @backUpAtKeysIntroMsgFirst.
  ///
  /// In en, this message translates to:
  /// **'It is important to back up your atKeys so that you can access your data from any device. \n\nIf you lose your atKeys, you will lose access to your data.'**
  String get backUpAtKeysIntroMsgFirst;

  /// No description provided for @backUpAtKeysIntroMsgLast.
  ///
  /// In en, this message translates to:
  /// **'\n\nYou can save additional backups from the Settings menu anytime.'**
  String get backUpAtKeysIntroMsgLast;

  /// No description provided for @backUpAtKeysMainMsg.
  ///
  /// In en, this message translates to:
  /// **'Your atKeys will be used to pair your atSign with this and other devices in the future.\n\natKeys are cryptographic keys that are used to secure your atSign. \n\nThey are unique to you and are used to encrypt and decrypt your data.'**
  String get backUpAtKeysMainMsg;

  /// No description provided for @backupKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Please select a file to export to:'**
  String get backupKeyDialogTitle;

  /// No description provided for @backupYourKey.
  ///
  /// In en, this message translates to:
  /// **'Back Up Your Key'**
  String get backupYourKey;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clientAtsignDescription.
  ///
  /// In en, this message translates to:
  /// **'An atSign is a resolvable address\nassigned to a device.'**
  String get clientAtsignDescription;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @dashboardView.
  ///
  /// In en, this message translates to:
  /// **'Dashboard View'**
  String get dashboardView;

  /// No description provided for @debugDumpLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Dev: Dump Logs to terminal'**
  String get debugDumpLogTitle;

  /// No description provided for @defaultRelaySelection.
  ///
  /// In en, this message translates to:
  /// **'Default Relay Selection'**
  String get defaultRelaySelection;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @demo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo;

  /// No description provided for @demoDescription.
  ///
  /// In en, this message translates to:
  /// **'Click here to load the test profile.'**
  String get demoDescription;

  /// No description provided for @demoTextButton.
  ///
  /// In en, this message translates to:
  /// **'Try Now'**
  String get demoTextButton;

  /// No description provided for @deviceAtsign.
  ///
  /// In en, this message translates to:
  /// **'Device atSign'**
  String get deviceAtsign;

  /// No description provided for @deviceAtsignDescription.
  ///
  /// In en, this message translates to:
  /// **'This is the atSign associated with your device.'**
  String get deviceAtsignDescription;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// No description provided for @deviceNameDescription.
  ///
  /// In en, this message translates to:
  /// **'This is the name of your remote device.'**
  String get deviceNameDescription;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @discord.
  ///
  /// In en, this message translates to:
  /// **'Discord Support'**
  String get discord;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get email;

  /// No description provided for @emptyProfileMessage.
  ///
  /// In en, this message translates to:
  /// **'No profiles found\nCreate or Import a profile to start using NoPorts.'**
  String get emptyProfileMessage;

  /// No description provided for @enableLogging.
  ///
  /// In en, this message translates to:
  /// **'Enable Logging'**
  String get enableLogging;

  /// No description provided for @enroll.
  ///
  /// In en, this message translates to:
  /// **'Enroll'**
  String get enroll;

  /// No description provided for @enrollApproved.
  ///
  /// In en, this message translates to:
  /// **'Enrollment request approved'**
  String get enrollApproved;

  /// No description provided for @enrollDenied.
  ///
  /// In en, this message translates to:
  /// **'Enrollment request denied'**
  String get enrollDenied;

  /// No description provided for @enrollRequestDenied.
  ///
  /// In en, this message translates to:
  /// **'Enrollment request denied'**
  String get enrollRequestDenied;

  /// No description provided for @enrollWithAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Enroll with Authenticator'**
  String get enrollWithAuthenticator;

  /// No description provided for @enrollWithAuthenticatorDescription.
  ///
  /// In en, this message translates to:
  /// **'Authenticate through app with manager keys'**
  String get enrollWithAuthenticatorDescription;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorAtKeySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save the atKeys file: {error}'**
  String errorAtKeySaveFailed(Object error);

  /// No description provided for @errorAtKeysFileProcessFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to process the atKeys file'**
  String get errorAtKeysFileProcessFailed;

  /// No description provided for @errorAtKeysInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid atKeys file detected'**
  String get errorAtKeysInvalid;

  /// No description provided for @errorAtKeysUploadedMismatch.
  ///
  /// In en, this message translates to:
  /// **'The atKeys file you uploaded did not match the atSign requested'**
  String get errorAtKeysUploadedMismatch;

  /// No description provided for @errorAtServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Failed to retrieve the atserver status, make sure you have a stable internet connection.'**
  String get errorAtServerUnavailable;

  /// No description provided for @errorAtServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the atServer, make sure you have a stable internet connection.'**
  String get errorAtServerUnreachable;

  /// No description provided for @errorAtSignAlreadyPaired.
  ///
  /// In en, this message translates to:
  /// **'The atSign {atsign} is already paired, please contact support.'**
  String errorAtSignAlreadyPaired(Object atsign);

  /// No description provided for @errorAtSignNotExist.
  ///
  /// In en, this message translates to:
  /// **'The atSign you have requested doesn\'t exist in this root domain.'**
  String get errorAtSignNotExist;

  /// No description provided for @errorAtSignUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The atSign is unavailable. Make sure you have pressed \"Activate\" from your dashboard and have a stable internet connection.'**
  String get errorAtSignUnavailable;

  /// No description provided for @errorAuthenticatinFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed.'**
  String get errorAuthenticatinFailed;

  /// No description provided for @errorAuthenticationTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Authentication timed out.'**
  String get errorAuthenticationTimedOut;

  /// No description provided for @errorOtpRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to request an OTP, try resending, or contact support if the issue persists.'**
  String get errorOtpRequestFailed;

  /// No description provided for @errorOtpVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify the OTP with the activation server, please try again. Contact support if the issue persists.'**
  String get errorOtpVerificationFailed;

  /// No description provided for @errorProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load this profile'**
  String get errorProfileLoadFailed;

  /// No description provided for @errorRootDomainNotSupported.
  ///
  /// In en, this message translates to:
  /// **'The specified root domain is not supported by automatic activation.'**
  String get errorRootDomainNotSupported;

  /// No description provided for @errorSwitchAtSignFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch atSigns after activation.'**
  String get errorSwitchAtSignFailed;

  /// No description provided for @europe.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get europe;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export Logs'**
  String get exportLogs;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @fileFormatInvalid.
  ///
  /// In en, this message translates to:
  /// **'The document format is invalid. Please upload a valid file.'**
  String get fileFormatInvalid;

  /// No description provided for @fileFormatInvalidDetails.
  ///
  /// In en, this message translates to:
  /// **'The profiles section is missing or incorrectly formatted. Please check the document.'**
  String get fileFormatInvalidDetails;

  /// No description provided for @fileImported.
  ///
  /// In en, this message translates to:
  /// **'File Imported'**
  String get fileImported;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'File Saved'**
  String get fileSaved;

  /// No description provided for @findOtp.
  ///
  /// In en, this message translates to:
  /// **'The request will be displayed in the Authenticator under Requests in any app connected to your atSign with manager keys.'**
  String get findOtp;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'Import File'**
  String get importFile;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @invalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get invalidOtp;

  /// No description provided for @json.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get json;

  /// No description provided for @keys.
  ///
  /// In en, this message translates to:
  /// **'Upload atKeys'**
  String get keys;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @localPort.
  ///
  /// In en, this message translates to:
  /// **'Local Port'**
  String get localPort;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @minimal.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get minimal;

  /// No description provided for @myNoPortsMsg.
  ///
  /// In en, this message translates to:
  /// **'Retrieve yours in '**
  String get myNoPortsMsg;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noAtsign.
  ///
  /// In en, this message translates to:
  /// **'No atSign'**
  String get noAtsign;

  /// No description provided for @noEmailClientAvailable.
  ///
  /// In en, this message translates to:
  /// **'No email client available'**
  String get noEmailClientAvailable;

  /// No description provided for @noName.
  ///
  /// In en, this message translates to:
  /// **'No Name'**
  String get noName;

  /// No description provided for @noPorts.
  ///
  /// In en, this message translates to:
  /// **'NoPorts'**
  String get noPorts;

  /// No description provided for @onboard.
  ///
  /// In en, this message translates to:
  /// **'Onboard'**
  String get onboard;

  /// No description provided for @onboardingButtonStatusPicking.
  ///
  /// In en, this message translates to:
  /// **'Waiting for file to be picked'**
  String get onboardingButtonStatusPicking;

  /// No description provided for @onboardingButtonStatusProcessingFile.
  ///
  /// In en, this message translates to:
  /// **'Processing file'**
  String get onboardingButtonStatusProcessingFile;

  /// No description provided for @onboardingError.
  ///
  /// In en, this message translates to:
  /// **'An error has occurred'**
  String get onboardingError;

  /// No description provided for @onboardingSubTitle.
  ///
  /// In en, this message translates to:
  /// **'to NoPorts Desktop'**
  String get onboardingSubTitle;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get onboardingTitle;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get or;

  /// No description provided for @overrideAllProfile.
  ///
  /// In en, this message translates to:
  /// **'Override all profiles with default relay selection'**
  String get overrideAllProfile;

  /// No description provided for @pasteProfile.
  ///
  /// In en, this message translates to:
  /// **'Paste Profile'**
  String get pasteProfile;

  /// No description provided for @pasteProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste the JSON/YAML content here'**
  String get pasteProfileDescription;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This profile will be permanently deleted.'**
  String get profileDeleteMessage;

  /// No description provided for @profileDeleteSecondaryMessage.
  ///
  /// In en, this message translates to:
  /// **'Some profiles are running and won\'t be deleted, stop those profiles first to delete them.'**
  String get profileDeleteSecondaryMessage;

  /// No description provided for @profileDeleteSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Selected profiles will be permanently deleted.'**
  String get profileDeleteSelectedMessage;

  /// No description provided for @profileExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Filetype'**
  String get profileExportDialogTitle;

  /// No description provided for @profileExportMessage.
  ///
  /// In en, this message translates to:
  /// **'What filetype would you like to export as?'**
  String get profileExportMessage;

  /// No description provided for @profileExportSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'What filetype would you like to export selected profiles as?'**
  String get profileExportSelectedMessage;

  /// No description provided for @profileFailedLoaded.
  ///
  /// In en, this message translates to:
  /// **'Profile failed to load'**
  String get profileFailedLoaded;

  /// No description provided for @profileFailedSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Profile failed to save'**
  String get profileFailedSaveMessage;

  /// No description provided for @profileFailedUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'No reason provided'**
  String get profileFailedUnknownMessage;

  /// No description provided for @profileImportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Import Method'**
  String get profileImportDialogTitle;

  /// No description provided for @profileImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import file'**
  String get profileImportFailed;

  /// No description provided for @profileImportSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'How would you like to import a profile?'**
  String get profileImportSelectedMessage;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get profileName;

  /// No description provided for @profileNameDescription.
  ///
  /// In en, this message translates to:
  /// **'This will be the name of your configurations.'**
  String get profileNameDescription;

  /// No description provided for @profileRunningActionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Cannot perform this action while profile is running.'**
  String get profileRunningActionDeniedMessage;

  /// No description provided for @profileRunningCloseMsgStart.
  ///
  /// In en, this message translates to:
  /// **'The following profile(s) are connected:'**
  String get profileRunningCloseMsgStart;

  /// No description provided for @profilesFailedLoaded.
  ///
  /// In en, this message translates to:
  /// **'Profiles failed to load'**
  String get profilesFailedLoaded;

  /// No description provided for @profileStatusFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get profileStatusFailedLoad;

  /// No description provided for @profileStatusFailedSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to Save'**
  String get profileStatusFailedSave;

  /// No description provided for @profileStatusFailedStart.
  ///
  /// In en, this message translates to:
  /// **'Failed to start'**
  String get profileStatusFailedStart;

  /// No description provided for @profileStatusLoaded.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get profileStatusLoaded;

  /// No description provided for @profileStatusLoadedMessage.
  ///
  /// In en, this message translates to:
  /// **'Currently Disconnected'**
  String get profileStatusLoadedMessage;

  /// No description provided for @profileStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get profileStatusLoading;

  /// No description provided for @profileStatusStarted.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get profileStatusStarted;

  /// No description provided for @profileStatusStartedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get profileStatusStartedMessage;

  /// No description provided for @profileStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting Up'**
  String get profileStatusStarting;

  /// No description provided for @profileStatusStopping.
  ///
  /// In en, this message translates to:
  /// **'Shutting Off'**
  String get profileStatusStopping;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'register'**
  String get register;

  /// No description provided for @relay.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get relay;

  /// No description provided for @relayDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose from our existing relays or create a new one.'**
  String get relayDescription;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @remoteHost.
  ///
  /// In en, this message translates to:
  /// **'Remote Host'**
  String get remoteHost;

  /// No description provided for @remotePort.
  ///
  /// In en, this message translates to:
  /// **'Remote Port'**
  String get remotePort;

  /// No description provided for @requestExpired.
  ///
  /// In en, this message translates to:
  /// **'The original request has expired. Please submit again'**
  String get requestExpired;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @resendPin.
  ///
  /// In en, this message translates to:
  /// **'Resend Pin'**
  String get resendPin;

  /// No description provided for @resetAtsign.
  ///
  /// In en, this message translates to:
  /// **'Reset atSign'**
  String get resetAtsign;

  /// No description provided for @rootDomainDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (Prod)'**
  String get rootDomainDefault;

  /// No description provided for @rootDomainDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo (VE)'**
  String get rootDomainDemo;

  /// No description provided for @saveAtKeys.
  ///
  /// In en, this message translates to:
  /// **'Save atKeys'**
  String get saveAtKeys;

  /// No description provided for @saveLater.
  ///
  /// In en, this message translates to:
  /// **'Save Later'**
  String get saveLater;

  /// No description provided for @selectEnrollMethod.
  ///
  /// In en, this message translates to:
  /// **'Select your enrolment method'**
  String get selectEnrollMethod;

  /// No description provided for @selectExportFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a file to export to:'**
  String get selectExportFile;

  /// No description provided for @selectKey.
  ///
  /// In en, this message translates to:
  /// **'Select atKey'**
  String get selectKey;

  /// No description provided for @selectorSubTitleAtsign.
  ///
  /// In en, this message translates to:
  /// **'Enter your NoPorts atSign below.'**
  String get selectorSubTitleAtsign;

  /// No description provided for @selectorSubTitleRootDomain.
  ///
  /// In en, this message translates to:
  /// **'Enter the atDirectory domain (previously called root domain).'**
  String get selectorSubTitleRootDomain;

  /// No description provided for @selectorTitleAtsign.
  ///
  /// In en, this message translates to:
  /// **'NoPorts atSign'**
  String get selectorTitleAtsign;

  /// No description provided for @selectorTitleRootDomain.
  ///
  /// In en, this message translates to:
  /// **'atDirectory Domain'**
  String get selectorTitleRootDomain;

  /// No description provided for @serviceMapping.
  ///
  /// In en, this message translates to:
  /// **'Service Mapping'**
  String get serviceMapping;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @showWindow.
  ///
  /// In en, this message translates to:
  /// **'Show Window'**
  String get showWindow;

  /// No description provided for @signout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signout;

  /// No description provided for @sshStyle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sshStyle;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get starting;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get stopping;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @submitOtp.
  ///
  /// In en, this message translates to:
  /// **'Submit OTP'**
  String get submitOtp;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @switchAtSign.
  ///
  /// In en, this message translates to:
  /// **'Switch atSign'**
  String get switchAtSign;

  /// No description provided for @switchAtSignDescription.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to switch atSigns?'**
  String get switchAtSignDescription;

  /// No description provided for @switchAtSignNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Switching atSigns ends all connections.'**
  String get switchAtSignNote;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync in progress. Some profiles may still be loading.'**
  String get syncInProgress;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get unknownError;

  /// No description provided for @uploadKey.
  ///
  /// In en, this message translates to:
  /// **'Upload atKey'**
  String get uploadKey;

  /// No description provided for @uploadKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a local .atkey file'**
  String get uploadKeyDescription;

  /// No description provided for @validationErrorAtsignField.
  ///
  /// In en, this message translates to:
  /// **'Field must be a valid atsign'**
  String get validationErrorAtsignField;

  /// No description provided for @validationErrorDeviceNameField.
  ///
  /// In en, this message translates to:
  /// **'Field can only contain lowercase letters, digits, underscores.'**
  String get validationErrorDeviceNameField;

  /// No description provided for @validationErrorEmptyField.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be left blank'**
  String get validationErrorEmptyField;

  /// No description provided for @validationErrorLocalPortField.
  ///
  /// In en, this message translates to:
  /// **'Number must be between 1024 and 65535'**
  String get validationErrorLocalPortField;

  /// No description provided for @validationErrorLongField.
  ///
  /// In en, this message translates to:
  /// **'Field must be 1-36 characters long'**
  String get validationErrorLongField;

  /// No description provided for @validationErrorRelayField.
  ///
  /// In en, this message translates to:
  /// **'Relay must be a valid atsign'**
  String get validationErrorRelayField;

  /// No description provided for @validationErrorRemoteHostField.
  ///
  /// In en, this message translates to:
  /// **'Field must be partially or fully qualified hostname or an IP address'**
  String get validationErrorRemoteHostField;

  /// No description provided for @validationErrorRemotePortField.
  ///
  /// In en, this message translates to:
  /// **'Number must be between 1 and 65535'**
  String get validationErrorRemotePortField;

  /// No description provided for @waitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval...'**
  String get waitingForApproval;

  /// No description provided for @whatAreAtKeys.
  ///
  /// In en, this message translates to:
  /// **'What are atKeys?'**
  String get whatAreAtKeys;

  /// No description provided for @whatIsClientAtsign.
  ///
  /// In en, this message translates to:
  /// **'What is a NoPorts atSign?'**
  String get whatIsClientAtsign;

  /// No description provided for @whereToAccept.
  ///
  /// In en, this message translates to:
  /// **'Where to accept?'**
  String get whereToAccept;

  /// No description provided for @whereToAcceptDescription.
  ///
  /// In en, this message translates to:
  /// **'Please approve the request in an app with a manager key.'**
  String get whereToAcceptDescription;

  /// No description provided for @yaml.
  ///
  /// In en, this message translates to:
  /// **'YAML'**
  String get yaml;

  /// No description provided for @yamlRecommended.
  ///
  /// In en, this message translates to:
  /// **'YAML (Recommended)'**
  String get yamlRecommended;

  /// No description provided for @policyManager.
  ///
  /// In en, this message translates to:
  /// **'Policy Manager'**
  String get policyManager;
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
      <String>['en', 'es', 'pt', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script+country codes are specified.
  switch (locale.toString()) {
    case 'zh_Hans_CH':
      return AppLocalizationsZhHansCh();
    case 'zh_Hant_HK':
      return AppLocalizationsZhHantHk();
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
