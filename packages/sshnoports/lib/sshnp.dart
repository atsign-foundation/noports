import 'package:noports_core/sshnp_foundation.dart';
import 'package:at_client/at_client.dart';

typedef AtClientGenerator = Future<AtClient> Function(SshnpParams params);

Future<Sshnp> sshnpFromParamsWithFileBindings(
  SshnpParams params, {
  AtClient? atClient,
  AtClientGenerator? atClientGenerator,
}) async {
  atClient ??= await atClientGenerator?.call(params);

  if (atClient == null) {
    throw ArgumentError(
        'atClient must be provided or atClientGenerator must be provided');
  }

  if (params.legacyDaemon) {
    return Sshnp.unsigned(
      atClient: atClient,
      params: params,
    );
  }

  switch (params.sshClient) {
    case SupportedSshClient.exec:
      return Sshnp.execLocal(
        atClient: atClient,
        params: params,
      );
    case SupportedSshClient.dart:
      return Sshnp.dartLocal(
        atClient: atClient,
        params: params,
      );
  }
}
