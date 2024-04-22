import 'dart:io';

import 'package:args/args.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/common/validation_utils.dart';

class SshnpdParams {
  final String device;
  final String username;
  final String homeDirectory;
  final List<String> managerAtsigns;
  final String atKeysFilePath;
  final String deviceAtsign;
  final bool verbose;
  final bool makeDeviceInfoVisible;
  final bool addSshPublicKeys;
  final SupportedSshClient sshClient;
  final String rootDomain;
  final int localSshdPort;
  final String ephemeralPermissions;
  final SupportedSshAlgorithm sshAlgorithm;
  final String? storagePath;
  final String permitOpen;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  SshnpdParams({
    required this.device,
    required this.username,
    required this.homeDirectory,
    required this.managerAtsigns,
    required this.atKeysFilePath,
    required this.deviceAtsign,
    required this.verbose,
    required this.makeDeviceInfoVisible,
    required this.addSshPublicKeys,
    required this.sshClient,
    required this.rootDomain,
    required this.localSshdPort,
    required this.ephemeralPermissions,
    required this.sshAlgorithm,
    required this.storagePath,
    required this.permitOpen,
  }) {
    if (invalidDeviceName(device)) {
      throw ArgumentError(invalidDeviceNameMsg);
    }
  }

  static Future<SshnpdParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String deviceAtsign = r['atsign'];
    List<String> managerAtsigns = r['managers']
        .toString()
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .toList();
    String homeDirectory = getHomeDirectory()!;

    // Do we have a device ?
    String device = r['device'];

    SupportedSshClient sshClient = SupportedSshClient.values.firstWhere(
        (c) => c.toString() == r['ssh-client'],
        orElse: () => DefaultSshnpdArgs.sshClient);

    // Do we have an ASCII ?
    if (invalidDeviceName(device)) {
      throw ArgumentError(invalidDeviceNameMsg);
    }
    bool makeDeviceInfoVisible = r['un-hide'];
    if (r.wasParsed('hide')) {
      makeDeviceInfoVisible = !r['hide'];
    }
    return SshnpdParams(
      device: r['device'],
      username: getUserName(throwIfNull: true)!,
      homeDirectory: homeDirectory,
      managerAtsigns: managerAtsigns,
      atKeysFilePath: r['key-file'] ??
          getDefaultAtKeysFilePath(homeDirectory, deviceAtsign),
      deviceAtsign: deviceAtsign,
      verbose: r['verbose'],
      makeDeviceInfoVisible: makeDeviceInfoVisible,
      addSshPublicKeys: r['sshpublickey'],
      sshClient: sshClient,
      rootDomain: r['root-domain'],
      localSshdPort:
          int.tryParse(r['local-sshd-port']) ?? DefaultSshnpdArgs.localSshdPort,
      ephemeralPermissions: r['ephemeral-permissions'],
      sshAlgorithm: SupportedSshAlgorithm.fromString(r['ssh-algorithm']),
      storagePath: r['storage-path'],
      permitOpen: r['permit-open'],
    );
  }

  static ArgParser _createArgParser() {
    var parser = ArgParser(
      usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : null,
      showAliasesInUsage: true,
    );

    // Basic arguments
    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/',
    );
    parser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign of this device',
    );
    parser.addOption(
      'managers',
      aliases: ['manager'],
      abbr: 'm',
      mandatory: true,
      help: 'atSign or list of atSigns (comma separated)'
          ' that this device will accept requests from',
    );
    parser.addOption(
      'device',
      abbr: 'd',
      mandatory: false,
      defaultsTo: "default",
      help: 'This daemon will operate with this device name;'
          ' allows multiple devices to share an atSign.'
          ' $deviceNameFormatHelp',
    );

    parser.addFlag(
      'sshpublickey',
      abbr: 's',
      defaultsTo: false,
      help: 'When set, will update authorized_keys'
          ' to include public key sent by manager',
    );
    parser.addFlag(
      'hide',
      abbr: 'h',
      negatable: false,
      defaultsTo: false,
      help: 'Hides the device from advertising its information to the manager'
          ' atSign. Even with this enabled, sshnpd will still respond to ping'
          ' requests from the manager. (This takes priority over -u / --un-hide)',
    );
    parser.addFlag(
      'un-hide',
      abbr: 'u',
      aliases: const ['username'],
      defaultsTo: true,
      hide: true,
      callback: (bool unhide) {
        if (unhide) {
          stderr.writeln(
              "[WARN] -u, --un-hide is deprecated, since it is now on by default."
              " Use --hide if you want to disable device information sharing.");
        }
      },
    );
    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );

    parser.addOption('ssh-client',
        mandatory: false,
        defaultsTo: DefaultSshnpdArgs.sshClient.toString(),
        allowed: SupportedSshClient.values
            .map(
              (c) => c.toString(),
            )
            .toList(),
        help: 'What to use for outbound ssh connections.');

    parser.addOption(
      'root-domain',
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory domain',
    );

    parser.addOption(
      'local-sshd-port',
      help: 'port on which sshd is listening locally on localhost',
      defaultsTo: DefaultSshnpdArgs.localSshdPort.toString(),
      mandatory: false,
    );

    parser.addOption('ephemeral-permissions',
        help: 'The permissions which will be added to the authorized_keys file'
            ' for the ephemeral public keys which are generated when a client'
            ' is connecting via forward ssh'
            ' e.g. PermitOpen="host-1:3389",PermitOpen="localhost:80"',
        defaultsTo: '',
        mandatory: false);

    parser.addOption(
      'ssh-algorithm',
      defaultsTo: DefaultArgs.sshAlgorithm.toString(),
      help: 'Use RSA 4096 keys rather than the default ED25519 keys',
      allowed: SupportedSshAlgorithm.values.map((c) => c.toString()).toList(),
    );

    parser.addOption(
      'storage-path',
      mandatory: false,
      help: 'Directory for local storage.'
          r' Defaults to $HOME/.sshnp/${atSign}/storage',
    );

    parser.addOption(
      'permit-open',
      aliases: ['po'],
      mandatory: false,
      defaultsTo: 'localhost:22,localhost:3389',
      help: 'Comma separated-list of host:port to which the daemon will permit'
          ' a connection from an authorized client. Hosts may be dns names or'
          ' ip addresses.',
    );

    return parser;
  }
}
