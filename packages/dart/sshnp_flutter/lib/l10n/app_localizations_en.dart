// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accounts => 'Accounts';

  @override
  String get actions => 'Actions';

  @override
  String get add => 'Add';

  @override
  String get addKey => 'Add Key';

  @override
  String get addNewConnection => 'Add New Connection';

  @override
  String get addNewConnectionDescription =>
      'To create a new connection as fast as possible, only fill in required fields, the rest will auto populate by default. You can always change your configurations later.';

  @override
  String get advancedConfiguration => 'Advanced Configuration';

  @override
  String get atKeysFilePath => 'atKeys File';

  @override
  String get authenticateClientToRvd =>
      'Authenticate Client to Socket Rendezvous';

  @override
  String get authenticateClientToRvdTooltip =>
      'When true, client will authenticate itself to rvd';

  @override
  String get authenticateDeviceToRvd =>
      'Authenticate Device to Socket Rendezvous';

  @override
  String get authenticateDeviceToRvdTooltip =>
      'When true, Device will authenticate itself to rvd';

  @override
  String get availableConnections => 'Available Connections';

  @override
  String get backupYourKeys => 'Backup Your Keys';

  @override
  String get cancel => 'Cancel';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get clientAtsign => 'Client atsign';

  @override
  String get closeButton => 'Close';

  @override
  String get commands => 'Commands';

  @override
  String get connect => 'Connect';

  @override
  String get connectionConfiguration => 'Connection Configuration';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get copiedToClipboard => 'Copied to Clipboard';

  @override
  String get corruptedPrivateKey => 'Status: Private Key is corrupted';

  @override
  String get corruptedProfile => 'Status: profile is corrupted';

  @override
  String get connectionProfiles => 'Connection Profiles';

  @override
  String get currentConnectionsDescription =>
      'Create and manage connection profiles';

  @override
  String get createConnectionProfile => 'Start New Connection Profile';

  @override
  String get createConnectionProfileDesc =>
      'Click to set up a connection profile for SSH access to you remote device';

  @override
  String get delete => 'Delete';

  @override
  String get deleteButton => 'Delete';

  @override
  String get dest => 'Dest.';

  @override
  String get destination => 'Destination';

  @override
  String get device => 'Device Name';

  @override
  String get deviceTooltip => 'Receiving device name';

  @override
  String get edit => 'Edit';

  @override
  String get encryptRvdTraffic => 'Encrypt RVD Traffic';

  @override
  String get encryptRvdTrafficTooltip =>
      'When true, traffic via the socket rendezvous is encrypted, in addition to whatever encryption the traffic already has, (e.g. an ssh session)';

  @override
  String get error => 'Error';

  @override
  String get privateKeyFormFieldError =>
      'Unable to load the private key manager. Please try again.';

  @override
  String get export => 'Export';

  @override
  String get failed => 'Failed';

  @override
  String get faq => 'FAQ';

  @override
  String get from => 'From';

  @override
  String get getStartedTitle => 'Get Started!';

  @override
  String get getStartedSubtitle => 'Create your first connection';

  @override
  String get getStartedNoConnections => 'You currently have no connections';

  @override
  String get homeDirectory => 'Home Directory';

  @override
  String get homeDirectoryHint => 'The home directory on this host';

  @override
  String get host => 'SR Address (atSign) *';

  @override
  String get hostTooltip =>
      'atSign of srvd daemon or FQDN/IP address to connect back to';

  @override
  String get hostHintText => 'eg. @rv_am';

  @override
  String get hostSelection => 'Host Selection';

  @override
  String get import => 'Import';

  @override
  String get importProfile => 'Import Profile';

  @override
  String get keyFile => 'Key File';

  @override
  String get listDevices => 'List Devices';

  @override
  String get localPort => 'Client-side port for the ssh tunnel';

  @override
  String get localPortTooltip => 'Defaults to 0 (ask the o/s for a port)';

  @override
  String get localSshOptions => 'Local SSH Options';

  @override
  String get localSshOptionsTooltip =>
      'Add these commands to the local ssh command';

  @override
  String get localSshOptionsHint => 'Use \",\" to separate options';

  @override
  String get newSshKeyCreation => 'New SSH Key Creation';

  @override
  String get newText => 'New';

  @override
  String get noAtsignToReset => 'No atSigns are paired to reset.';

  @override
  String get note => 'Note';

  @override
  String get noteMessage => ': You cannot undo this action.';

  @override
  String get noTerminalSessions => 'No active terminal sessions';

  @override
  String get noTerminalSessionsHelp =>
      'Create a new session from the home screen';

  @override
  String get okButton => 'Ok';

  @override
  String get options => 'Options';

  @override
  String get onboardButtonDescription => 'Onboard with Client Address (atSign)';

  @override
  String get port => 'Remote Port';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privateKey => 'SSH Private Key *';

  @override
  String get privateKeyTooltip => 'Private Key for authentication';

  @override
  String get privateKeyDescription =>
      'Select the keys you want to use when establishing a connection with this profile';

  @override
  String get privateKeyNotFound => 'No Private Key Found';

  @override
  String get privateKeyNickname => 'Private Key Nickname';

  @override
  String get privateKeyNicknameToolTip => 'Identifier of the Private Key';

  @override
  String get privateKeyManagement => 'Private Key Management';

  @override
  String get privateKeyManagementDescription =>
      'Create and Configure your private key';

  @override
  String get privateKeyPassphrase => 'Private Key Passphrase';

  @override
  String get privatekeyPassPhraseTooltip => 'Passphrase of the Private Key';

  @override
  String profileName(String fieldStatus) {
    String _temp0 = intl.Intl.selectLogic(
      fieldStatus,
      {
        'required': 'Profile Name *',
        'other': 'Profile Name',
      },
    );
    return '$_temp0';
  }

  @override
  String get profileNameTooltip => 'Name of the profile to use';

  @override
  String get profileNameHintText => 'eg. Alice Linux VM';

  @override
  String get remoteSshdPort => 'Remote SSHD Port';

  @override
  String get remoteSshdPortTooltip =>
      'Port on which sshd is listening locally on the device host';

  @override
  String get remoteUsername => 'Session username';

  @override
  String get remoteUsernameTooltip =>
      'Username to use in the ssh session on the remote host';

  @override
  String get remoteUsernameHintText => 'eg. alice';

  @override
  String get removeButton => 'Remove';

  @override
  String get reset => 'Reset';

  @override
  String get resetDescription =>
      'This will remove the selected atSign and its details from this app only.';

  @override
  String get resetErrorText => 'Please select at least one atSign to reset';

  @override
  String get resetWarningText => 'Warning: This action cannot be undone';

  @override
  String get result => 'Result';

  @override
  String get rootDomain => 'atDirectory Root Domain';

  @override
  String get rootDomainTooltip => 'atDirectory domain';

  @override
  String get rsa => 'Legacy RSA Key';

  @override
  String get select => 'Select';

  @override
  String get selectAFile => 'Select a file';

  @override
  String get selectPrivateKey => 'Select Private Key';

  @override
  String get sendSshPublicKey => 'Share SSH Public Key';

  @override
  String get sendSshPublicKeyTooltip =>
      'When true, the ssh public key will be sent to the remote host for use in the ssh session';

  @override
  String get sessionId => 'Session ID';

  @override
  String get settings => 'Settings';

  @override
  String get support => 'Support';

  @override
  String get supportDescription =>
      'Our team of experts is here to help! Select your preferred method below';

  @override
  String get sourcePort => 'Source Port';

  @override
  String get socketRendezvousConfiguration => 'Socket Rendezvous Configuration';

  @override
  String get srvdAtsign => 'SR Address (atSign)';

  @override
  String get srvdAtsignTooltip => 'atSign of the socket rendezvous';

  @override
  String get sshAlgorithm => 'SSH Algorithm';

  @override
  String get sshButton => 'ssh';

  @override
  String sshKeyManagement(String newLine) {
    String _temp0 = intl.Intl.selectLogic(
      newLine,
      {
        'yes': 'SSH Key \nConfiguration',
        'no': 'SSH Key Management',
        'other': 'SSH Key Management',
      },
    );
    return '$_temp0';
  }

  @override
  String get sshnpdAtSign => 'Device Address (atSign) *';

  @override
  String get sshnpdAtSignHint =>
      'The atSign of the sshnpd we wish to communicate with';

  @override
  String get sshnpdAtSignTooltip => 'Receiving device atSign';

  @override
  String get sshnpdAtSignHintText => 'eg. @alice_device';

  @override
  String get sshPublicKey => 'SSH Public Key';

  @override
  String get status => 'Status';

  @override
  String get submit => 'Submit';

  @override
  String get success => 'Success';

  @override
  String get switchAtsign => 'Switch atSign';

  @override
  String get terminal => 'Terminal';

  @override
  String get terminalDescription => 'Connections currently running';

  @override
  String get to => 'To';

  @override
  String get tunnelUsername => 'Tunnel Username';

  @override
  String get tunnelUsernameTooltip =>
      'Username to use for the initial ssh tunnel';

  @override
  String get tunnelUsernameHintText => 'eg. alice';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'The user name on this host';

  @override
  String get uploadNewKey => 'Upload New Key';

  @override
  String get verbose => 'Verbose Logging';

  @override
  String get warning => 'Warning';

  @override
  String get warningMessage =>
      ' Are you sure you want to delete this configuration';

  @override
  String get yourKeys => 'Your Keys';

  @override
  String get welcomeTo => 'Welcome to';

  @override
  String get sshnpDesktopApp => 'SSHNP Desktop App';

  @override
  String get welcomeToDescription =>
      'Make your devices reachable while eliminating network attack surfaces & reducing administrative overhead.';
}
