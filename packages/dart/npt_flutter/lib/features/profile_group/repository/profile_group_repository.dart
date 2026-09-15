import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/util/constants.dart';

class ProfileGroupRepository {
  final AtClient? _atClient;

  ProfileGroupRepository({AtClient? atClient}) : _atClient = atClient;

  AtClient get _client => _atClient ?? AtClientManager.getInstance().atClient;

  static AtKey getProfileGroupAtKey({String? sharedBy}) {
    final builder = AtKey.self(
      Constants.profileGroupKeyName,
      namespace: Constants.namespace,
    );
    if (sharedBy != null) builder.sharedBy(sharedBy);
    return builder.build();
  }

  /// Returns the stored groups, an empty [ProfileGroupData] when nothing has
  /// been stored yet, or null when the value could not be read.
  Future<ProfileGroupData?> getProfileGroups() async {
    final Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    final AtKey key = getProfileGroupAtKey(sharedBy: atsign);

    try {
      final AtValue value = await _client.get(key);
      if (value.value == null) return const ProfileGroupData();
      final dynamic json = jsonDecode(value.value);
      if (json is! Map) {
        throw 'profile groups from the atServer is not a Map';
      }
      return ProfileGroupData.fromJson(Map<String, dynamic>.from(json));
    } on AtKeyNotFoundException {
      return const ProfileGroupData();
    } on KeyNotFoundException {
      return const ProfileGroupData();
    } catch (e) {
      App.log('[ERROR] getProfileGroups: $e'.loggable);
      return null;
    }
  }

  Future<bool> putProfileGroups(ProfileGroupData data) async {
    final Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    final AtKey key = getProfileGroupAtKey(sharedBy: atsign);
    try {
      return await _client.put(key, jsonEncode(data.toJson()));
    } catch (e) {
      App.log('[ERROR] putProfileGroups: $e'.loggable);
      return false;
    }
  }
}
