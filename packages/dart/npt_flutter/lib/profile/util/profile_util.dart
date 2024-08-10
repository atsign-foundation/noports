import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/env.dart';
import 'package:npt_flutter/profile/models/profile.dart';
import 'package:uuid/uuid.dart';

class ProfileUtil {
  static const String subNamespace = 'profiles';

  static AtKey getAtKeyForProfile(Profile profile) {
    return getAtKeyForProfileId(profile.uuid);
  }

  static AtKey getAtKeyForProfileId(String uuid) {
    return AtKey.self(
      '$uuid.$subNamespace',
      namespace: Env.namespace,
    ).build();
  }

  static String generateNewProfileUuid() {
    return const Uuid().v4();
  }
}
