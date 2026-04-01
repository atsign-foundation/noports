import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:config/config.dart';

class SharedOptions {
  static const OptionGroup atsignGroup = OptionGroup("atSign Options");
  static const OptionGroup runtimeGroup = OptionGroup("Runtime Options");
  // atSign Options Group
  static const ConfigOptionBase<String> keyfile = StringOption(
    argName: 'key-file',
    configKey: '/atsign/keys',
    argAliases: ['keyFile'],
    argAbbrev: 'k',
    mandatory: false,
    helpText:
        'Sending atSign\'s keyFile if not in ~/.atsign/keys/'
        '  Alias: --keyFile',
    group: atsignGroup,
  );

  static const ConfigOptionBase<Directory> storagePath = DirOption(
    argName: 'storage-path',
    configKey: '/runtime/storage-path',
    argAliases: ['storage-dir'],
    mandatory: false,
    helpText:
        'Directory for local storage.'
        r' Defaults to $HOME/.atsign/storage/$atSign/.npd/$deviceName/',
    group: runtimeGroup,
  );

  static const ConfigOptionBase<String> passPhrase = StringOption(
    argName: 'pass-phrase',
    configKey: '/atsign/passphrase',
    argAliases: ['passPhrase'],
    argAbbrev: 'P',
    mandatory: false,
    defaultsTo: '',
    helpText:
        'Pass phrase to encrypt/decrypt the password protected atKeys file',
    hide: true,
  );

  static const ConfigOptionBase<String> atsign = StringOption(
    argName: 'atsign',
    configKey: '/atsign/atsign',
    argAbbrev: 'a',
    mandatory: true,
    helpText: 'atSign of this device',
    group: atsignGroup,
  );

  static const ConfigOptionBase<String> rootServer = StringOption(
    argName: 'root-server',
    configKey: '/atsign/root',
    argAliases: ['root-domain'],
    mandatory: false,
    defaultsTo: 'root.atsign.org',
    helpText:
        'atDirectory domain.'
        ' Alias (for backwards compatibility): --root-domain',
    group: atsignGroup,
  );

  //runtime group
  static const ConfigOptionBase<bool> help = FlagOption(
    argName: 'help',
    defaultsTo: false,
    helpText: 'Show usage',
    group: runtimeGroup,
  );
  static const ConfigOptionBase<bool> verbose = FlagOption(
    argName: 'verbose',
    configKey: '/runtime/verbose',
    argAbbrev: 'v',
    defaultsTo: false,
    helpText: 'More logging (INFO and above)',
    group: runtimeGroup,
  );
  static const ConfigOptionBase<bool> debug = FlagOption(
    argName: 'debug',
    configKey: '/runtime/debug',
    defaultsTo: false,
    helpText: 'All logging (FINEST and above)',
    group: runtimeGroup,
  );

  static const ConfigOptionBase<bool> version = FlagOption(
    argName: 'version',
    configKey: '/runtime/version',
    defaultsTo: false,
    helpText: 'Show version',
    group: runtimeGroup,
  );
}

class AtsignParams {
  final Atsign atSign;
  final String rootDomain;
  final String passPhrase;
  final String atKeysFilePath;
  final String storagePath;
  final bool verbose;
  final bool debug;

  AtsignParams({
    required this.atSign,
    required this.rootDomain,
    required this.passPhrase,
    required this.atKeysFilePath,
    required this.storagePath,
    required this.verbose,
    required this.debug,
  });
}
