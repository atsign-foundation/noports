import 'package:at_client/at_client.dart';

/// Checks if the provided atSign's atServer has been properly activated with a public RSA key.
/// `atClient` must be authenticated
/// `atSign` is the atSign to check
Future<bool> atSignIsActivated(final AtClient atClient, String atSign) async {
  final Metadata metadata = Metadata()
    ..isPublic = true
    ..namespaceAware = false;

  final AtKey publicKey = AtKey()
    ..sharedBy = atSign
    ..key = 'publickey'
    ..metadata = metadata;

  try {
    await atClient.get(publicKey);
    return true;
  } catch (e) {
    return false;
  }
}