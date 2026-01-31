import 'package:at_client_mobile/at_client_mobile.dart';

/// Replacement for at_backupkey_flutter's BackUpKeyService
/// This provides the same functionality without the problematic plugin
class BackUpKeyService {
  static Future<Map<String, String>> getEncryptedKeys(String atsign) async {
    Map<String, String> result = {};
    try {
      // Get the encrypted keys from the keychain
      result = await KeyChainManager.getInstance().getEncryptedKeys(atsign);

      // Get the AES key (self encryption key)
      final aesKey = (await KeyChainManager.getInstance().readAtsign(
        name: atsign,
      ))?.selfEncryptionKey;

      if (aesKey != null) {
        result[atsign] = aesKey;
      }
    } catch (e) {
      result = {};
    }
    return result;
  }
}
