import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import '../models/policy.dart';

class RoleRepository {
  static const String groupsPolicyNamespace =
      'groups.policy.sshnp';

  Future<List<Role>> fetchRoles() async {
    final rolesJson = <String>[];
    const String regex = 'groups\\.policy\\.sshnp' r'@(.{1,55})$';

    List<String> groupAtKeyStrs = await atClient.getKeys(regex: regex);
    List<AtKey> groupAtKeys =
        groupAtKeyStrs.map((key) => AtKey.fromString(key)).toList();

    for (final AtKey atKey in groupAtKeys) {
      GetRequestOptions gro = GetRequestOptions()..useRemoteAtServer = true;
      AtValue atValue;
      try {
        atValue = await atClient.get(atKey, getRequestOptions: gro);
      } catch (e) {
        continue;
      }
      if (atValue.value == null) continue;
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
        App.log('[ERROR] fetchRoles: Failed to parse role JSON: $e'.loggable);
        continue;
      }
    }

    return roles;
  }

  Future<bool> updateExistingRole(Role role) async {
    if (role.id == null || role.id!.isEmpty) {
      App.log('[ERROR] updateExistingRole: Role ID is required for update'
          .loggable);
      return false;
    }

    AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();

    if (currentAtSign != null && !currentAtSign.startsWith('@')) {
      currentAtSign = '@$currentAtSign';
    }

    final String atKeyStr = '${role.id}.$groupsPolicyNamespace$currentAtSign';
    final String value = jsonEncode(role.toJson());

    try {
      PutRequestOptions pro = PutRequestOptions()..useRemoteAtServer = true;
      bool success = await atClient.put(AtKey.fromString(atKeyStr), value,
          putRequestOptions: pro);

      if (success) {
        try {
          await atClient.notificationService.notify(
            NotificationParams.forUpdate(
              AtKey.fromString('$currentAtSign:$atKeyStr'),
              value: jsonEncode(role),
            ),
          );
        } catch (notifyError) {
          App.log(
              '[WARNING] updateExistingRole: Failed to send notification: $notifyError'
                  .loggable);
        }
      }

      return success;
    } catch (e) {
      App.log('[ERROR] updateExistingRole: Failed to update role: $e'.loggable);
      return false;
    }
  }

  Future<bool> createNewRole(Role role) async {
    final AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();
    final String newRoleId = (await _maxGroupId + 1).toString();

    role.id = newRoleId;

    if (currentAtSign != null && !currentAtSign.startsWith('@')) {
      currentAtSign = '@$currentAtSign';
    }

    final String atKeyStr = '${role.id}.$groupsPolicyNamespace$currentAtSign';
    final String value = jsonEncode(role.toJson());

    try {
      final PutRequestOptions pro = PutRequestOptions()
        ..useRemoteAtServer = true;
      final bool success = await atClient.put(AtKey.fromString(atKeyStr), value,
          putRequestOptions: pro);

      if (success) {
        try {
          await atClient.notificationService.notify(
            NotificationParams.forUpdate(
              AtKey.fromString('$currentAtSign:$atKeyStr'),
              value: jsonEncode(role),
            ),
          );
        } catch (notifyError) {
          App.log(
              '[WARNING] createNewRole: Failed to send notification: $notifyError'
                  .loggable);
        }
      }

      return success;
    } catch (e) {
      App.log('[ERROR] createNewRole: Failed to create role: $e'.loggable);
      return false;
    }
  }

  Future<bool> deleteRole(String roleId) async {
    if (roleId.isEmpty) {
      App.log('[ERROR] deleteRole: Role ID is required for deletion'.loggable);
      return false;
    }

    final AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();

    if (currentAtSign != null && !currentAtSign.startsWith('@')) {
      currentAtSign = '@$currentAtSign';
    }

    final String atKeyStr = '$roleId.$groupsPolicyNamespace$currentAtSign';

    try {
      final DeleteRequestOptions dro = DeleteRequestOptions()
        ..useRemoteAtServer = true;
      bool success = await atClient.delete(AtKey.fromString(atKeyStr),
          deleteRequestOptions: dro);
      if (success) {
        try {
          await atClient.notificationService.notify(
            NotificationParams.forDelete(
              AtKey.fromString('$currentAtSign:$atKeyStr'),
            ),
          );
        } catch (notifyError) {
          App.log(
              '[WARNING] deleteRole: Failed to send notification: $notifyError'
                  .loggable);
        }
      }
      return success;
    } catch (e) {
      App.log('[ERROR] deleteRole: Failed to delete role: $e'.loggable);
      return false;
    }
  }

  Future<int> get _maxGroupId async {
    final roles = await fetchRoles();
    if (roles.isEmpty) return 0;

    int maxId = 0;
    for (final role in roles) {
      if (role.id != null) {
        final parsedId = int.tryParse(role.id!) ?? 0;
        if (parsedId > maxId) {
          maxId = parsedId;
        }
      }
    }
    return maxId;
  }
}