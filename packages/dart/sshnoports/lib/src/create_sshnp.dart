import 'dart:io';

import 'package:noports_core/sshnp_foundation.dart';
import 'package:at_client/at_client.dart';
import 'package:sshnoports/src/extended_arg_parser.dart';
import 'package:at_utils/at_utils.dart';

typedef AtClientGenerator = Future<AtClient> Function(SshnpParams params);

Future<Sshnp> createSshnp(
  SshnpParams params, {
  AtClient? atClient,
  AtClientGenerator? atClientGenerator,
  SupportedSshClient sshClient = DefaultExtendedArgs.sshClient,
  void Function(String message)? onProgress,
}) async {
  atClient ??= await atClientGenerator?.call(params);

  if (params.verbose) {
    AtSignLogger.root_level = 'INFO';
  }
  if (atClient == null) {
    throw ArgumentError(
        'atClient must be provided or atClientGenerator must be provided');
  }

  // If srvdAtSign is not provided, or is a comma-separated list,
  // auto select the best rv
  if (params.srvdAtSign.isEmpty || params.srvdAtSign.contains(',')) {
    onProgress?.call(
      'No relay supplied, will find the lowest-latency relay available; '
      'this may take up to 25 seconds',
    );
    final srvd = params.srvdAtSign.replaceAll(' ', '');
    final rvSelector = RelaySelector(
      atClient: atClient,
      clientAtSign: params.clientAtSign,
      sshnpdAtSign: params.sshnpdAtSign,
      device: params.device,
      rootDomain: params.rootDomain,
    );
    List<Atsign>? rvAtSigns;

    if (srvd.contains(',')) {
      // parse comma-separated list of rvAtSigns
      rvAtSigns = srvd.split(',').map((s) => s.toAtsign()).toList();
    }

    final bestRv = await rvSelector.selectBestRelay(rvAtSigns: rvAtSigns);
    params = SshnpParams.merge(params, SshnpPartialParams(srvdAtSign: bestRv));
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
