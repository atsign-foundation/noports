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

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @activating.
  ///
  /// In en, this message translates to:
  /// **'Activating'**
  String get activating;

  /// No description provided for @activationAtsignFileStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Select a folder to save your .atKeys files'**
  String get activationAtsignFileStorageLocation;

  /// No description provided for @activationAtsignListDescription.
  ///
  /// In en, this message translates to:
  /// **'The following Atsigns will be activated:'**
  String get activationAtsignListDescription;

  /// No description provided for @activationButtonDescription.
  ///
  /// In en, this message translates to:
  /// **'Complete Activation and set up a new Atsign'**
  String get activationButtonDescription;

  /// No description provided for @activationComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete Activation'**
  String get activationComplete;

  /// No description provided for @activationFileBased.
  ///
  /// In en, this message translates to:
  /// **'File-based Activation'**
  String get activationFileBased;

  /// No description provided for @activationFileBasedDescription.
  ///
  /// In en, this message translates to:
  /// **'Please upload your activation file (.yaml).\nThis file is downloaded from your Management Portal.'**
  String get activationFileBasedDescription;

  /// No description provided for @activationFileErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Please use a valid activation file.'**
  String get activationFileErrorMessage;

  /// No description provided for @activationFileLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Processing File...'**
  String get activationFileLoadingMessage;

  /// No description provided for @activationFileSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Activation file uploaded successfully!'**
  String get activationFileSuccessMessage;

  /// No description provided for @activationFileUploadDragDropDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload or drag & drop your one-time activation file (.yaml)'**
  String get activationFileUploadDragDropDescription;

  /// No description provided for @activationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Activating, please wait until every Atsign has finished.'**
  String get activationInProgress;

  /// No description provided for @activationKeyStatusActivated.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get activationKeyStatusActivated;

  /// No description provided for @activationKeyStatusActivating.
  ///
  /// In en, this message translates to:
  /// **'Activating'**
  String get activationKeyStatusActivating;

  /// No description provided for @activationKeyStatusAlreadyActivated.
  ///
  /// In en, this message translates to:
  /// **'Already Activated'**
  String get activationKeyStatusAlreadyActivated;

  /// No description provided for @activationKeyStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get activationKeyStatusFailed;

  /// No description provided for @activationKeyStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get activationKeyStatusWaiting;

  /// No description provided for @activationManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Activation'**
  String get activationManual;

  /// No description provided for @activationRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry Failed'**
  String get activationRetryFailed;

  /// No description provided for @activationStatus.
  ///
  /// In en, this message translates to:
  /// **'Activation Status'**
  String get activationStatus;

  /// No description provided for @activationStatusActivating.
  ///
  /// In en, this message translates to:
  /// **'Activating'**
  String get activationStatusActivating;

  /// No description provided for @activationStatusCount.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total} Atsigns activated:'**
  String activationStatusCount(Object current, Object total);

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

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAtsign.
  ///
  /// In en, this message translates to:
  /// **'Add Atsign'**
  String get addAtsign;

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

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @alertDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get alertDialogTitle;

  /// No description provided for @allRightsReserved.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Atsign, All Rights Reserved'**
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
  /// **'Please select your Atsign'**
  String get atsignDialogSubtitle;

  /// No description provided for @atsignDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Atsign'**
  String get atsignDialogTitle;

  /// No description provided for @atsignFrom.
  ///
  /// In en, this message translates to:
  /// **'From Atsign'**
  String get atsignFrom;

  /// No description provided for @atsignsUser.
  ///
  /// In en, this message translates to:
  /// **'User Atsign'**
  String get atsignsUser;

  /// No description provided for @atsignsUserTooltip.
  ///
  /// In en, this message translates to:
  /// **'An Atsign like \"@alice\" that will be connecting to other devices'**
  String get atsignsUserTooltip;

  /// No description provided for @atsignTo.
  ///
  /// In en, this message translates to:
  /// **'To Atsign'**
  String get atsignTo;

  /// No description provided for @atsignUncreated.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an Atsign?'**
  String get atsignUncreated;

  /// No description provided for @authenticate.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get authenticate;

  /// No description provided for @authenticator.
  ///
  /// In en, this message translates to:
  /// **'Authenticator'**
  String get authenticator;

  /// No description provided for @authorisation.
  ///
  /// In en, this message translates to:
  /// **'Authorisation'**
  String get authorisation;

  /// No description provided for @autoStartApplication.
  ///
  /// In en, this message translates to:
  /// **'Auto-Start Client Application'**
  String get autoStartApplication;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backUp.
  ///
  /// In en, this message translates to:
  /// **'Back Up'**
  String get backUp;

  /// No description provided for @backUpAtKeys.
  ///
  /// In en, this message translates to:
  /// **'Back Up atKeys'**
  String get backUpAtKeys;

  /// No description provided for @backUpAtKeysIntroMsgFirst.
  ///
  /// In en, this message translates to:
  /// **'It is important to {saveOrBackup, select, save{save} other{backup}} your atKeys so that you can access your data from any device. \n\nIf you lose your atKeys, you will lose access to your data.'**
  String backUpAtKeysIntroMsgFirst(String saveOrBackup);

  /// No description provided for @backUpAtKeysIntroMsgLast.
  ///
  /// In en, this message translates to:
  /// **'\n\nYou can save additional backups from the Settings menu anytime.'**
  String get backUpAtKeysIntroMsgLast;

  /// No description provided for @backUpAtKeysMainMsg.
  ///
  /// In en, this message translates to:
  /// **'Your atKeys will be used to pair your Atsign with this and other devices in the future.\n\natKeys are cryptographic keys that are used to secure your Atsign. \n\nThey are unique to you and are used to encrypt and decrypt your data.'**
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

  /// No description provided for @connectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Connection closed, will retry...'**
  String get connectionClosed;

  /// No description provided for @connectionRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying connection (keep-alive)...'**
  String get connectionRetrying;

  /// No description provided for @connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connections;

  /// No description provided for @connectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out, will retry...'**
  String get connectionTimedOut;

  /// No description provided for @connectUriProtocolDescription.
  ///
  /// In en, this message translates to:
  /// **'This setting automatically launches the appropriate application after a connection is established, based on the selected protocol. If no protocol is selected, no application will be launched. Select the protocol to use for the connection.'**
  String get connectUriProtocolDescription;

  /// No description provided for @connectUriProtocolNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get connectUriProtocolNone;

  /// No description provided for @connectUriUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get connectUriUsername;

  /// No description provided for @connectUriUsernameDescription.
  ///
  /// In en, this message translates to:
  /// **'Optional username for protocols like SSH (e.g., user in ssh://user@host)'**
  String get connectUriUsernameDescription;

  /// No description provided for @couldNotLoadPreviousState.
  ///
  /// In en, this message translates to:
  /// **'Could not load previous state error'**
  String get couldNotLoadPreviousState;

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

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @deviceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get deviceAdd;

  /// No description provided for @deviceAtsign.
  ///
  /// In en, this message translates to:
  /// **'Device Atsign'**
  String get deviceAtsign;

  /// No description provided for @deviceAtsignDescription.
  ///
  /// In en, this message translates to:
  /// **'This is the Atsign associated with your device.'**
  String get deviceAtsignDescription;

  /// No description provided for @deviceAtsignDescriptionTwo.
  ///
  /// In en, this message translates to:
  /// **'An Atsign like \"@bob_device\", that will be connected to. This is also known as the daemon or npd machine that is running the daemon process that will be receiving connection requests where connections will be established to this device.'**
  String get deviceAtsignDescriptionTwo;

  /// No description provided for @deviceAtsigns.
  ///
  /// In en, this message translates to:
  /// **'Device Atsign'**
  String get deviceAtsigns;

  /// No description provided for @deviceEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Device'**
  String get deviceEdit;

  /// No description provided for @deviceGroup.
  ///
  /// In en, this message translates to:
  /// **'Device Group'**
  String get deviceGroup;

  /// No description provided for @deviceGroupAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Device Group'**
  String get deviceGroupAdd;

  /// No description provided for @deviceGroupEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Device Group'**
  String get deviceGroupEdit;

  /// No description provided for @deviceGroupNo.
  ///
  /// In en, this message translates to:
  /// **'No Device Group'**
  String get deviceGroupNo;

  /// No description provided for @deviceGroups.
  ///
  /// In en, this message translates to:
  /// **'Device Groups'**
  String get deviceGroups;

  /// No description provided for @deviceGroupsNotAdded.
  ///
  /// In en, this message translates to:
  /// **'No device groups added yet'**
  String get deviceGroupsNotAdded;

  /// No description provided for @deviceGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Daemon processes that specify the --dg option with a string will allow connections from user to the specified host:ports'**
  String get deviceGroupTooltip;

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

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @devicesNotAdded.
  ///
  /// In en, this message translates to:
  /// **'No devices added yet'**
  String get devicesNotAdded;

  /// No description provided for @devicesTooltip.
  ///
  /// In en, this message translates to:
  /// **'A device name string like \"default\" that is under a device Atsign. A device Atsign can have multiple device names, device names help distinguish individual device daemon processes. Adding a device name here will allow tunnels to be established from the user Atsign to this device Atsign/device name pair.'**
  String get devicesTooltip;

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
  /// **'No profiles found.\nCreate or Import a profile to start using NoPorts.'**
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

  /// No description provided for @errorActivationKeysConflict.
  ///
  /// In en, this message translates to:
  /// **'This Atsign was previously onboarded with a different set of keys. Remove it from the app and try again.'**
  String get errorActivationKeysConflict;

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
  /// **'The atKeys file you uploaded did not match the Atsign requested'**
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

  /// No description provided for @errorAtsignAlreadyPaired.
  ///
  /// In en, this message translates to:
  /// **'The Atsign {atsign} is already paired, please contact support.'**
  String errorAtsignAlreadyPaired(Object atsign);

  /// No description provided for @errorAtsignNotExist.
  ///
  /// In en, this message translates to:
  /// **'The Atsign you have requested doesn\'t exist in this root domain.'**
  String get errorAtsignNotExist;

  /// No description provided for @errorAtsignUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Atsign is unavailable. Make sure you have pressed \"Activate\" from your dashboard and have a stable internet connection.'**
  String get errorAtsignUnavailable;

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

  /// No description provided for @errorDuringStartupWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error during startup: {errorMessage}'**
  String errorDuringStartupWithDetails(Object errorMessage);

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

  /// No description provided for @errorSwitchAtsignFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch Atsign after activation.'**
  String get errorSwitchAtsignFailed;

  /// No description provided for @errorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {errorMessage},'**
  String errorWithDetails(Object errorMessage);

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

  /// No description provided for @fastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get fastest;

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
  /// **'The request will be displayed in the Authenticator under Requests in any app connected to your Atsign with manager keys.'**
  String get findOtp;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @groupAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Group'**
  String get groupAdd;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

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

  /// No description provided for @jsonCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON to Clipboard'**
  String get jsonCopyToClipboard;

  /// No description provided for @jsonPayloadCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'JSON payload copied to clipboard'**
  String get jsonPayloadCopiedToClipboard;

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

  /// No description provided for @localHost.
  ///
  /// In en, this message translates to:
  /// **'Local Host'**
  String get localHost;

  /// No description provided for @localHostDescription.
  ///
  /// In en, this message translates to:
  /// **'The hostname or IP address to bind to on your local machine'**
  String get localHostDescription;

  /// No description provided for @localPort.
  ///
  /// In en, this message translates to:
  /// **'Local Port'**
  String get localPort;

  /// No description provided for @localPortDescription.
  ///
  /// In en, this message translates to:
  /// **'The port you\'ll use on your local machine'**
  String get localPortDescription;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @logsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get logsClear;

  /// No description provided for @logsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'No logs available yet.\nActivity will appear here when policy requests are made.'**
  String get logsNotAvailable;

  /// No description provided for @logsNotAvailableStartMonitoring.
  ///
  /// In en, this message translates to:
  /// **'No logs available.\nStart monitoring from the Policy Manager to see activity.'**
  String get logsNotAvailableStartMonitoring;

  /// No description provided for @logsView.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get logsView;

  /// No description provided for @logType.
  ///
  /// In en, this message translates to:
  /// **'Log Type'**
  String get logType;

  /// No description provided for @manageAtsigns.
  ///
  /// In en, this message translates to:
  /// **'Manage Atsign'**
  String get manageAtsigns;

  /// No description provided for @minimal.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get minimal;

  /// No description provided for @monitoringActive.
  ///
  /// In en, this message translates to:
  /// **'Monitoring Active'**
  String get monitoringActive;

  /// No description provided for @monitoringInactive.
  ///
  /// In en, this message translates to:
  /// **'Monitoring Inactive'**
  String get monitoringInactive;

  /// No description provided for @monitoringStart.
  ///
  /// In en, this message translates to:
  /// **'Start Monitoring'**
  String get monitoringStart;

  /// No description provided for @monitoringStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Monitoring'**
  String get monitoringStop;

  /// No description provided for @myNoPortsMsg.
  ///
  /// In en, this message translates to:
  /// **'Retrieve yours in My NoPorts →'**
  String get myNoPortsMsg;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noAtsign.
  ///
  /// In en, this message translates to:
  /// **'No Atsign'**
  String get noAtsign;

  /// No description provided for @noAtsignsAdded.
  ///
  /// In en, this message translates to:
  /// **'No Atsign added yet'**
  String get noAtsignsAdded;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

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

  /// No description provided for @nptStartupTimedout.
  ///
  /// In en, this message translates to:
  /// **'Npt startup timed out'**
  String get nptStartupTimedout;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

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
  /// **'OR'**
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

  /// No description provided for @permitOpens.
  ///
  /// In en, this message translates to:
  /// **'Permit Opens: {permitOpens}'**
  String permitOpens(Object permitOpens);

  /// No description provided for @permitOpensHostPort.
  ///
  /// In en, this message translates to:
  /// **'Permit Opens (host:port)'**
  String get permitOpensHostPort;

  /// No description provided for @permitOpensNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No permit opens configured'**
  String get permitOpensNotConfigured;

  /// No description provided for @policy.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get policy;

  /// No description provided for @policyLogs.
  ///
  /// In en, this message translates to:
  /// **'Policy Logs'**
  String get policyLogs;

  /// No description provided for @policyManager.
  ///
  /// In en, this message translates to:
  /// **'Policy Manager'**
  String get policyManager;

  /// No description provided for @policyRequestPayload.
  ///
  /// In en, this message translates to:
  /// **'Policy Request Payload'**
  String get policyRequestPayload;

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

  /// No description provided for @profileKeepAlive.
  ///
  /// In en, this message translates to:
  /// **'🕺 Keep Alive'**
  String get profileKeepAlive;

  /// No description provided for @profileKeepAliveDescription.
  ///
  /// In en, this message translates to:
  /// **'Stay alive. If a session ends, create a new session and re-bind to the local port. Sessions can end due to being unused after a timeout or network issues.'**
  String get profileKeepAliveDescription;

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

  /// No description provided for @profilePort443.
  ///
  /// In en, this message translates to:
  /// **'Use Port 443'**
  String get profilePort443;

  /// No description provided for @profilePort443Description.
  ///
  /// In en, this message translates to:
  /// **'Forces the relay to use port 443 instead of an ephemeral port. Automatically enables ESCR relay authentication mode for security.'**
  String get profilePort443Description;

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
  /// **'Register'**
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

  /// No description provided for @remoteHostDescription.
  ///
  /// In en, this message translates to:
  /// **'The hostname or IP address of the service you are connecting to on the remote machine'**
  String get remoteHostDescription;

  /// No description provided for @remotePort.
  ///
  /// In en, this message translates to:
  /// **'Remote Port'**
  String get remotePort;

  /// No description provided for @remotePortDescription.
  ///
  /// In en, this message translates to:
  /// **'The port that will be used on the remote machine'**
  String get remotePortDescription;

  /// No description provided for @removeAtsign.
  ///
  /// In en, this message translates to:
  /// **'Remove Atsign'**
  String get removeAtsign;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @noAtsignsToRemove.
  ///
  /// In en, this message translates to:
  /// **'No atsigns found to remove.'**
  String get noAtsignsToRemove;

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

  /// No description provided for @retryFailedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Retry failed: {errorMessage}, will retry...'**
  String retryFailedWithDetails(Object errorMessage);

  /// No description provided for @roleAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add New Role'**
  String get roleAddNew;

  /// No description provided for @roleCreatingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create role'**
  String get roleCreatingFailed;

  /// No description provided for @roleCreatingFailedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to create role: {errorMessage}'**
  String roleCreatingFailedWithDetails(Object errorMessage);

  /// No description provided for @roleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Role'**
  String get roleDelete;

  /// No description provided for @roleDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the role \"{roleName}\"? This action cannot be undone.'**
  String roleDeleteConfirmation(Object roleName);

  /// No description provided for @roleDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Role deleted successfully!'**
  String get roleDeletedSuccessfully;

  /// No description provided for @roleDeletingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete role'**
  String get roleDeletingFailed;

  /// No description provided for @roleDeletingFailedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete role: {errorMessage}'**
  String roleDeletingFailedWithDetails(Object errorMessage);

  /// No description provided for @roleLoadingFailedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load role: {errorMessage}'**
  String roleLoadingFailedWithDetails(Object errorMessage);

  /// No description provided for @roleNotFound.
  ///
  /// In en, this message translates to:
  /// **'No roles found'**
  String get roleNotFound;

  /// No description provided for @roleNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'No role loaded'**
  String get roleNotLoaded;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// No description provided for @roleSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save role'**
  String get roleSaveFailed;

  /// No description provided for @roleSaveFailedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to save role: {errorMessage}'**
  String roleSaveFailedWithDetails(Object errorMessage);

  /// No description provided for @roleSelectToViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Select a role to view details'**
  String get roleSelectToViewDetails;

  /// No description provided for @rolesLoadingFailedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load roles: {errorMessage}'**
  String rolesLoadingFailedWithDetails(Object errorMessage);

  /// No description provided for @rolesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh Roles'**
  String get rolesRefresh;

  /// No description provided for @roleUpdatingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update role'**
  String get roleUpdatingFailed;

  /// No description provided for @roleUpdatingFailedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update role: {errorMessage}'**
  String roleUpdatingFailedWithDetails(Object errorMessage);

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

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

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
  /// **'Enter your NoPorts Atsign below.'**
  String get selectorSubTitleAtsign;

  /// No description provided for @selectorSubTitleRootDomain.
  ///
  /// In en, this message translates to:
  /// **'Enter the atDirectory domain.'**
  String get selectorSubTitleRootDomain;

  /// No description provided for @selectorTitleAtsign.
  ///
  /// In en, this message translates to:
  /// **'NoPorts Atsign'**
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

  /// No description provided for @servicesAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed Services'**
  String get servicesAllowed;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsCouldNotFetch.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch settings'**
  String get settingsCouldNotFetch;

  /// No description provided for @showWindow.
  ///
  /// In en, this message translates to:
  /// **'Show Window'**
  String get showWindow;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInButtonDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with an activated Atsign'**
  String get signInButtonDescription;

  /// No description provided for @signout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signout;

  /// No description provided for @socketconnectorClosedPrematurely.
  ///
  /// In en, this message translates to:
  /// **'Socketconnector Closed Prematurely'**
  String get socketconnectorClosedPrematurely;

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

  /// No description provided for @switchAtsign.
  ///
  /// In en, this message translates to:
  /// **'Switch Atsign'**
  String get switchAtsign;

  /// No description provided for @switchAtsignDescription.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to switch Atsign?'**
  String get switchAtsignDescription;

  /// No description provided for @switchAtsignNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Switching Atsign ends all connections.'**
  String get switchAtsignNote;

  /// No description provided for @syncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sync completed. All profiles loaded.'**
  String get syncCompleted;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync in progress. Some profiles may still be loading.'**
  String get syncInProgress;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

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

  /// No description provided for @validationErrorHostField.
  ///
  /// In en, this message translates to:
  /// **'Field must be partially or fully qualified hostname or an IP address'**
  String get validationErrorHostField;

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

  /// No description provided for @errorServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The server is currently unavailable. Please try again later.'**
  String get errorServerUnavailable;

  /// No description provided for @errorAtsignActivated.
  ///
  /// In en, this message translates to:
  /// **'This atsign has already been activated.'**
  String get errorAtsignActivated;

  /// No description provided for @msgAtsignUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The atsign server could not be reached.'**
  String get msgAtsignUnreachable;

  /// No description provided for @errorAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please check your details and try again.'**
  String get errorAuthenticationFailed;

  /// No description provided for @msgResponseTimeOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get msgResponseTimeOut;

  /// No description provided for @whatAreAtKeys.
  ///
  /// In en, this message translates to:
  /// **'What are atKeys?'**
  String get whatAreAtKeys;

  /// No description provided for @whatIsAnAtsign.
  ///
  /// In en, this message translates to:
  /// **'What is an Atsign?'**
  String get whatIsAnAtsign;

  /// No description provided for @whatIsAnAtsignDescription.
  ///
  /// In en, this message translates to:
  /// **'An Atsign is both an address and a unique identifier for your device.'**
  String get whatIsAnAtsignDescription;

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
