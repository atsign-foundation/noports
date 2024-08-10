import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/env.dart';
import 'package:npt_flutter/profile/profile.dart';

class ProfileListRepository {
  const ProfileListRepository();

  Future<Iterable<String>?> getProfileUuids() async {
    AtClient atClient = AtClientManager.getInstance().atClient;

    // TODO: remove me later
    return ["npfs"];

    String namespace = Env.namespace ?? '';
    List<AtKey> keys;
    try {
      keys = await atClient.getAtKeys(
          regex: '\\.${ProfileUtil.subNamespace}\\.$namespace');
    } catch (_) {
      keys = [];
    }
    return keys.map((key) =>
        key.key.substring(0, key.key.indexOf('.${ProfileUtil.subNamespace}')));
  }
}
