import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/common/supported_ssh_clients.dart';
import 'package:sshnoports/sshnpd/sshnpd_impl.dart';

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

  /// Whether this device should be hidden from sshnpd or not
  abstract final bool isHidden;

  /// true once [init] has completed
  @visibleForTesting
  bool initialized = false;

  factory SSHNPD({
    // final fields
    required AtClient atClient,
    required String username,
    required String homeDirectory,
    required String device,
    required String managerAtsign,
    required SupportedSshClient sshClient,
    bool isHidden = true,
  }) {
    return SSHNPDImpl(
      atClient: atClient,
      username: username,
      homeDirectory: homeDirectory,
      device: device,
      managerAtsign: managerAtsign,
      sshClient: sshClient,
      isHidden: isHidden,
    );
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
