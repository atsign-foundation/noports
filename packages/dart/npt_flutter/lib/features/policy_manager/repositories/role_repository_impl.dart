import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import 'package:uuid/uuid.dart';
import '../models/policy.dart';
import 'role_repository.dart';

class RoleRepositoryImpl implements RoleRepository {
  @override
  Future<List<Role>> getAllRoles() async {
    final rolesJson = <String>[]; // placeholder

    AtClient atClient = AtClientManager.getInstance().atClient;
    const String regex =
        r'^[a-zA-Z0-9]+\.groups\.policy\.sshnp@[a-zA-Z0-9]+$'; // TODO move constant somewhere

    List<String> groupAtKeyStrs = await atClient.getKeys(
        regex:
            regex); // holds a list of strings, each string represents an atKey string
    List<AtKey> groupAtKeys =
        groupAtKeyStrs.map((key) => AtKey.fromString(key)).toList();

    for (final AtKey atKey in groupAtKeys) {
      final AtValue atValue =
          await atClient.get(atKey); // the group JSON string
      final String groupJsonStr = atValue.value;
      rolesJson.add(groupJsonStr);
    }

    final roles = <Role>[];

    for (final roleJsonStr in rolesJson) {
      try {
        final roleJson = jsonDecode(roleJsonStr) as Map<String, dynamic>;
        final role = Role.fromJson(roleJson);
        roles.add(role);
      } catch (e) {
        App.log('[ERROR] getAllRoles: Failed to parse role JSON: $e'.loggable);
        continue;
      }
    }

    return roles;
  }

  @override
  Future<Role?> getRoleById(String id) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    final String regex =
        r'^' + RegExp.escape(id) + r'\.groups\.policy\.sshnp@[a-zA-Z0-9]+$';

    List<String> groupAtKeyStrs = await atClient.getKeys(regex: regex);

    if (groupAtKeyStrs.isEmpty) {
      return null;
    }

    try {
      AtKey atKey = AtKey.fromString(groupAtKeyStrs.first);
      final AtValue atValue = await atClient.get(atKey);
      final String groupJsonStr = atValue.value;
      final roleJson = jsonDecode(groupJsonStr) as Map<String, dynamic>;
      return Role.fromJson(roleJson);
    } catch (e) {
      App.log('[ERROR] getRoleById: Failed to parse role JSON: $e'.loggable);
      return null;
    }
  }

  // @override
  // Future<Role> addRole(Role role) async {
  //   return Role()
  // }

  // @override
  // Future<Role> updateRole(Role role) async {
  //   return role;
  // }

  // @override
  // Future<void> deleteRole(String id) async {}

  String generateId() {
    const uuid = Uuid();
    return uuid.v4();
  }
}
