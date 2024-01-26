import 'dart:io';

import 'package:noports_core/sshnp_foundation.dart';
import 'package:at_client/at_client.dart';
import 'package:sshnoports/src/extended_arg_parser.dart';
import 'package:at_utils/at_logger.dart';

typedef AtClientGenerator = Future<AtClient> Function(SshnpParams params);

Future<Sshnp> createSshnp(
  SshnpParams params, {
  AtClient? atClient,
  AtClientGenerator? atClientGenerator,
  SupportedSshClient sshClient = DefaultExtendedArgs.sshClient,
  bool legacyDaemon = DefaultExtendedArgs.legacyDaemon,
}) async {
  atClient ??= await atClientGenerator?.call(params);

  if (params.verbose) {
    AtSignLogger.root_level = 'INFO';
  }
  if (atClient == null) {
    throw ArgumentError(
        'atClient must be provided or atClientGenerator must be provided');
  }

  if (legacyDaemon) {
    if (params.authenticateDeviceToRvd ||
        params.authenticateClientToRvd ||
        params.encryptRvdTraffic ||
        params.discoverDaemonFeatures) {
      throw ArgumentError('When using --legacy-daemon, you must also'
          ' use these flags: --no-ac --no-ad --no-et --no-ddf');
    }
    // ignore: deprecated_member_use
    return Sshnp.unsigned(
      atClient: atClient,
      params: params,
    );
  }

  switch (sshClient) {
    case SupportedSshClient.openssh:
      return Sshnp.openssh(
        atClient: atClient,
        params: params,
      );
    case SupportedSshClient.dart:
      String identityFile = params.identityFile ??
          (throw ArgumentError(
            'Identity file is mandatory when using the dart client.',
          ));
      String pemText = await File(identityFile).readAsString();
      AtSshKeyPair identityKeyPair = AtSshKeyPair.fromPem(
        pemText,
        identifier: params.identityFile!,
        passphrase: params.identityPassphrase,
      );
      return Sshnp.dartPure(
        atClient: atClient,
        params: params,
        identityKeyPair: identityKeyPair,
      );
  }
}
