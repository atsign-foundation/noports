import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/constants.dart';
import 'package:uuid/uuid.dart' as u;

class Uuid {
  final String uuid;
  const Uuid(this.uuid);

  static const String profilesSubNamespace = 'profiles';

  AtKey toProfileAtKey({String? sharedBy}) {
    var key = AtKey.self(
      '$uuid.$profilesSubNamespace',
      namespace: Constants.namespace,
    );
    if (sharedBy != null) key.sharedBy(sharedBy);
    return key.build();
  }

  static String generate() {
    return const u.Uuid().v4();
  }
}
