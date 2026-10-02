import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:npt_flutter/app.dart';

import '../models/policy.dart';

class RoleRepository {
  static const String groupsPolicyNamespace = 'groups.policy.sshnp';

  Future<List<FetchedRole>> fetchRoles() async {
    final rolesJson = <String>[];
    final AtClient atClient = AtClientManager.getInstance().atClient;
    Atsign? currentAtsign = atClient.getCurrentAtSign()?.toAtsign();
    if (currentAtsign == null) {
      App.log('[ERROR] fetchRoles: Current atsign is null'.loggable);
      return [];
    }

    final String regex = 'groups\\.policy\\.sshnp$currentAtsign';

    final List<String> groupAtKeyStrs = await atClient.getKeys(
      regex: regex,
      useRemoteAtServer: true,
    );
    final List<AtKey> groupAtKeys = groupAtKeyStrs
        .map((key) => AtKey.fromString(key))
        .toList();

    for (final AtKey atKey in groupAtKeys) {
      final GetRequestOptions gro = GetRequestOptions()
        ..useRemoteAtServer = true;
      AtValue atValue;
      try {
        atValue = await atClient.get(atKey, getRequestOptions: gro);
      } catch (e) {
        App.log(
          '[ERROR] fetchRoles: Failed to get value for key $atKey: $e ... Continuing anyways :/'
              .loggable,
        );
        continue;
      }
      if (atValue.value == null) {
        continue;
      }
      final String groupJsonStr = atValue.value;
      rolesJson.add(groupJsonStr);
    }

    final roles = <FetchedRole>[];

    for (final roleJsonStr in rolesJson) {
      try {
        final roleJson = jsonDecode(roleJsonStr) as Map<String, dynamic>;
        final role = FetchedRole.fromJson(roleJson);
        roles.add(role);
      } catch (e) {
        App.log('[ERROR] fetchRoles: Failed to parse role JSON: $e'.loggable);
        continue;
      }
    }

    return roles;
  }

  Future<String?> putNewRole(final RoleInProgress roleInProgress) async {
    final AtClient atClient = AtClientManager.getInstance().atClient;
    Atsign? currentAtsign = atClient.getCurrentAtSign()?.toAtsign();

    if (currentAtsign == null) {
      App.log('[ERROR] updateExistingRole: Current atsign is null'.loggable);
      return null;
    }

    final int maxId = await getMaxGroupId();
    final int newId = maxId + 1;

    FetchedRole newRole = FetchedRole.fromRoleInProgress(
      id: newId.toString(),
      roleInProgress: roleInProgress,
    );

    final String atKeyStr =
        '${newRole.id}.$groupsPolicyNamespace$currentAtsign';
    final String value = jsonEncode(newRole.toJson());

    try {
      final PutRequestOptions pro = PutRequestOptions()
        ..useRemoteAtServer = true;
      final bool success = await atClient.put(
        AtKey.fromString(atKeyStr),
        value,
        putRequestOptions: pro,
      );

      if (success) {
        try {
          AtKey notifKey = AtKey.fromString('$currentAtsign:$atKeyStr');
          notifKey.metadata.namespaceAware = false;
          App.log(
            '[INFO] putNewRole: Sending UPDATE notification $notifKey'.loggable,
          );
          await atClient.notificationService.notify(
            NotificationParams.forUpdate(notifKey, value: jsonEncode(newRole)),
          );
        } catch (notifyError) {
          App.log(
            '[WARNING] updateExistingRole: Failed to send notification: $notifyError'
                .loggable,
          );
        }
      }
      return success ? newId.toString() : null;
    } catch (e) {
      App.log('[ERROR] updateExistingRole: Failed to update role: $e'.loggable);
      return null;
    }
  }

  Future<bool> updateExistingRole(final FetchedRole role) async {
    if (role.id.isEmpty) {
      App.log('[ERROR] updateRole: Role ID is required for update'.loggable);
      return false;
    }

    final AtClient atClient = AtClientManager.getInstance().atClient;
    Atsign? currentAtsign = atClient.getCurrentAtSign()?.toAtsign();

    if (currentAtsign == null) {
      App.log('[ERROR] updateExistingRole: Current atsign is null'.loggable);
      return false;
    }

    final String atKeyStr = '${role.id}.$groupsPolicyNamespace$currentAtsign';
    final String value = jsonEncode(role.toJson());

    try {
      final PutRequestOptions pro = PutRequestOptions()
        ..useRemoteAtServer = true;
      final bool success = await atClient.put(
        AtKey.fromString(atKeyStr),
        value,
        putRequestOptions: pro,
      );

      if (success) {
        try {
          AtKey notifKey = AtKey.fromString('$currentAtsign:$atKeyStr');
          notifKey.metadata.namespaceAware = false;
          App.log(
            '[INFO] updateExistingRole: Sending UPDATE notification $notifKey'
                .loggable,
          );
          await atClient.notificationService.notify(
            NotificationParams.forUpdate(notifKey, value: jsonEncode(role)),
          );
        } catch (notifyError) {
          App.log(
            '[WARNING] updateExistingRole: Failed to send notification: $notifyError'
                .loggable,
          );
        }
      }
      return success;
    } catch (e) {
      App.log('[ERROR] updateExistingRole: Failed to update role: $e'.loggable);
      return false;
    }
  }

  Future<bool> deleteRole(final String roleId) async {
    if (roleId.isEmpty) {
      App.log('[ERROR] deleteRole: Role ID is required for deletion'.loggable);
      return false;
    }

    final AtClient atClient = AtClientManager.getInstance().atClient;
    Atsign? currentAtsign = atClient.getCurrentAtSign()?.toAtsign();

    if (currentAtsign == null) {
      App.log('[ERROR] deleteRole: Current atsign is null'.loggable);
      return false;
    }

    final String atKeyStr = '$roleId.$groupsPolicyNamespace$currentAtsign';

    try {
      final DeleteRequestOptions dro = DeleteRequestOptions()
        ..useRemoteAtServer = true;
      bool success = await atClient.delete(
        AtKey.fromString(atKeyStr),
        deleteRequestOptions: dro,
      );
      if (success) {
        try {
          AtKey notifKey = AtKey.fromString('$currentAtsign:$atKeyStr');
          notifKey.metadata.namespaceAware = false;
          App.log(
            '[INFO] deleteRole: Sending DELETE notification $notifKey'.loggable,
          );
          await atClient.notificationService.notify(
            NotificationParams.forDelete(notifKey),
          );
        } catch (notifyError) {
          App.log(
            '[WARNING] deleteRole: Failed to send notification: $notifyError'
                .loggable,
          );
        }
      }
      return success;
    } catch (e) {
      App.log('[ERROR] deleteRole: Failed to delete role: $e'.loggable);
      return false;
    }
  }

  Future<int> getMaxGroupId() async {
    final List<FetchedRole> roles = await fetchRoles();
    if (roles.isEmpty) return 0;

    int maxId = 0;
    for (final role in roles) {
      final parsedId = int.tryParse(role.id) ?? 0;
      if (parsedId > maxId) {
        maxId = parsedId;
      }
    }
    return maxId;
  }
}
