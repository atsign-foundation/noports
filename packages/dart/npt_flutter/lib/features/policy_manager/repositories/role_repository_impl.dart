import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import '../models/policy.dart';
import 'role_repository.dart';

class RoleRepositoryImpl implements RoleRepository {
  static const String groupsPolicyNamespace = 'groups.policy.sshnp'; // TODO move string somewhere
  
  List<Role> _roles = [];

  @override
  List<Role> get getRoles => _roles;

  @override
  Future<void> fetchRoles() async {
    final rolesJson = <String>[];
    AtClient atClient = AtClientManager.getInstance().atClient;
    const String regex = r'^[a-zA-Z0-9]+\.' + groupsPolicyNamespace + r'@[a-zA-Z0-9]+$';

    try {
      List<String> groupAtKeyStrs = await atClient.getKeys(regex: regex);
      List<AtKey> groupAtKeys = groupAtKeyStrs.map((key) => AtKey.fromString(key)).toList();

      for (final AtKey atKey in groupAtKeys) {
        final AtValue atValue = await atClient.get(atKey);
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

      _roles = roles;
    } catch (e) {
      App.log('[ERROR] fetchRoles: Failed to fetch roles: $e'.loggable);
      _roles = [];
    }
  }

  @override
  Future<bool> updateExistingRole(Role role) async {
    if (role.id == null || role.id!.isEmpty) {
      App.log('[ERROR] updateExistingRole: Role ID is required for update'.loggable);
      return false;
    }

    // PutRequestOptions pro = PutRequestOptions()..useRemoteAtServer = true;
    AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();

    // ensure currentAtSign is not null and starts with '@'
    if (currentAtSign != null && !currentAtSign.startsWith('@')) {
      currentAtSign = '@$currentAtSign';
    }

    final String atKeyStr = '${role.id}.$groupsPolicyNamespace$currentAtSign';
    final String value = jsonEncode(role.toJson());

    try {
      // bool success = await atClient.put(AtKey.fromString(atKeyStr), value, putRequestOptions: pro);
      bool success = await atClient.put(AtKey.fromString(atKeyStr), value);
      if (success) {
        _updateRoleInCache(role);
      }
      
      return success;
    } catch (e) {
      App.log('[ERROR] updateExistingRole: Failed to update role: $e'.loggable);
      return false;
    }
  }

  @override
  Future<bool> createNewRole(Role role) async {
    // final PutRequestOptions pro = PutRequestOptions()..useRemoteAtServer = true;
    final AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();
    final String newRoleId = (_maxGroupId + 1).toString();

    role.id = newRoleId;

    // ensure currentAtSign is not null and starts with '@'
    if (currentAtSign != null && !currentAtSign.startsWith('@')) {
      currentAtSign = '@$currentAtSign';
    }

    final String atKeyStr = '${role.id}.$groupsPolicyNamespace$currentAtSign';
    final String value = jsonEncode(role.toJson());

    try {
      // bool success = await atClient.put(AtKey.fromString(atKeyStr), value, putRequestOptions: pro);
      bool success = await atClient.put(AtKey.fromString(atKeyStr), value);
      if (success) {
        _roles.add(role);
      }
      return success;
    } catch (e) {
      App.log('[ERROR] createNewRole: Failed to create role: $e'.loggable);
      return false;
    }
  }

  void _updateRoleInCache(Role role) {
    final existingIndex = _roles.indexWhere((r) => r.id == role.id);
    
    if (existingIndex != -1) {
      _roles[existingIndex] = role;
    } else {
      _roles.add(role);
    }
  }

  @override
  Future<bool> deleteRole(String roleId) async {
    if (roleId.isEmpty) {
      App.log('[ERROR] deleteRole: Role ID is required for deletion'.loggable);
      return false;
    }

    final AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();

    // ensure currentAtSign is not null and starts with '@'
    if (currentAtSign != null && !currentAtSign.startsWith('@')) {
      currentAtSign = '@$currentAtSign';
    }

    final String atKeyStr = '$roleId.$groupsPolicyNamespace$currentAtSign';
    // final DeleteRequestOptions dro = DeleteRequestOptions()..useRemoteAtServer = true;

    try {
      // bool success = await atClient.delete(AtKey.fromString(atKeyStr), deleteRequestOptions: dro);
      bool success = await atClient.delete(AtKey.fromString(atKeyStr));
      if (success) {
        _removeRoleFromCache(roleId);
      }
      return success;
    } catch (e) {
      App.log('[ERROR] deleteRole: Failed to delete role: $e'.loggable);
      return false;
    }
  }

  void _removeRoleFromCache(String roleId) {
    _roles.removeWhere((r) => r.id == roleId);
  }

  int get _maxGroupId {
    if (_roles.isEmpty) return 0;
    
    int maxId = 0;
    for (final role in _roles) {
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