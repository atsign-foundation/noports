import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/common/create_at_client_cli.dart';
import 'package:sshnoports/common/supported_ssh_clients.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshrv/sshrv.dart';
import 'package:sshnoports/version.dart';
import 'package:uuid/uuid.dart';

import 'package:sshnoports/common/defaults.dart' as defaults;

part 'sshnpd_impl.dart';
part 'sshnpd_params.dart';

abstract class SSHNPD {
  static const String namespace = 'sshnp';

  abstract final AtSignLogger logger;

  /// The [AtClient] used to communicate with sshnpd and sshrvd
  abstract AtClient atClient;

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================
  /// The user name on this host
  abstract final String username;

  /// The home directory on this host
  abstract final String homeDirectory;

  /// The device name on this host
  abstract final String device;

  String get deviceAtsign;

  abstract final String managerAtsign;

  /// The ssh client to use when doing reverse ssh
  abstract final SupportedSshClient sshClient;

  /// Defaults to false.
  ///
  /// When true, sshnpd should
  /// 1. notify a value for `@managerAtSign:username.$device.sshnp@deviceAtSign`
  /// when it starts
  /// 2. create a `@managerAtSign:device_info.$device.sshnp@deviceAtSign`
  /// record when it starts, and update it periodically thereafter
  ///
  /// When false, neither of the above should happen
  abstract final bool makeDeviceInfoVisible;

  /// When true, sshnpd will respond to requests to add public keys to its
  /// authorized_keys file.
  /// This flag should default to false.
  abstract final bool addSshPublicKeys;

  /// true once [init] has completed
  @visibleForTesting
  bool initialized = false;

  /// Port that local sshd is listening on localhost interface
  /// Default set to [defaultLocalSshdPort]
  abstract final int localSshdPort;

  /// Permissions which are added to the authorized_keys file when adding
  /// a newly-generated ephemeral public key.
  /// e.g. PermitOpen="host-1:3389",PermitOpen="localhost:80"
  ///
  /// Note that PermitOpen="localhost:localSshdPort" will always be added
  abstract final String ephemeralPermissions;

  /// When false, we generate [sshPublicKey] and [sshPrivateKey] using ed25519.
  /// When true, we generate [sshPublicKey] and [sshPrivateKey] using RSA.
  /// Defaults to false
  abstract final bool rsa;

  factory SSHNPD(
      {
      // final fields
      required AtClient atClient,
      required String username,
      required String homeDirectory,
      required String device,
      required String managerAtsign,
      required SupportedSshClient sshClient,
      required bool makeDeviceInfoVisible,
      required bool addSshPublicKeys,
      required int localSshdPort,
      required String ephemeralPermissions,
      required bool rsa}) {
    return SSHNPDImpl(
        atClient: atClient,
        username: username,
        homeDirectory: homeDirectory,
        device: device,
        managerAtsign: managerAtsign,
        sshClient: sshClient,
        makeDeviceInfoVisible: makeDeviceInfoVisible,
        addSshPublicKeys: addSshPublicKeys,
        localSshdPort: localSshdPort,
        ephemeralPermissions: ephemeralPermissions,
        rsa: rsa);
  }

  static Future<SSHNPD> fromCommandLineArgs(List<String> args) async {
    return SSHNPDImpl.fromCommandLineArgs(args);
  }

  /// Must be run after construction, to complete initialization
  /// - Ensure that initialization is only performed once.
  /// - If the object has already been initialized, it throws a StateError indicating that initialization cannot be performed again.
  Future<void> init();

  /// Must be run after [init], to start the sshnpd service
  /// - Starts connectivity listener to receive requests from sshnp
  /// - Subscribes to notifications matching the pattern '$device\.$nameSpace@', with decryption enabled.
  /// - Listens for notifications and handles different notification types ('privatekey', 'sshpublickey', 'sshd').
  /// - If a 'privatekey' notification is received, it extracts and stores the private key.
  /// - If an 'sshpublickey' notification is received, Checks if the SSH public key is valid, Appends the SSH public key to the authorized_keys file in the user's SSH directory if it is not already present
  /// - If an 'sshd' notification is received, it triggers the sshCallback function to handle the SSH callback request.
  Future<void> run();
}
