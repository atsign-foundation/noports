import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import '../models/policy.dart';
import 'role_repository.dart';

class RoleRepositoryImpl implements RoleRepository {
  List<Role> _roles = [];

  @override
  List<Role> get getRoles => _roles;

  @override
  Future<void> fetchRoles() async {
    final rolesJson = <String>[];

    AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();
    
    // Remove @ symbol if present since AtKey expects atSign without @
    if (currentAtSign != null && currentAtSign.startsWith('@')) {
      currentAtSign = currentAtSign.substring(1);
    }
    
    App.log('[DEBUG] fetchRoles: currentAtSign = "$currentAtSign"'.loggable);
    
    const String regex = r'^[a-zA-Z0-9]+\.groups\.policy\.sshnp@[a-zA-Z0-9]+$';

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

    PutRequestOptions pro = PutRequestOptions()..useRemoteAtServer = true;
    AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();
    
    // Remove @ symbol if present since AtKey expects atSign without @
    if (currentAtSign != null && currentAtSign.startsWith('@')) {
      currentAtSign = currentAtSign.substring(1);
    }
    
    App.log('[DEBUG] updateExistingRole: currentAtSign = "$currentAtSign"'.loggable);
    
    if (currentAtSign == null || currentAtSign.isEmpty) {
      App.log('[ERROR] updateExistingRole: Cannot get current atSign'.loggable);
      return false;
    }
    
    final String atKeyStr = '${role.id}.groups.policy.sshnp@$currentAtSign';
    final String value = jsonEncode(role.toJson());

    try {
      bool success = await atClient.put(AtKey.fromString(atKeyStr), value, putRequestOptions: pro);
      
      if (success) {
        // Update the role in cache
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
    PutRequestOptions pro = PutRequestOptions()..useRemoteAtServer = true;
    AtClient atClient = AtClientManager.getInstance().atClient;
    String? currentAtSign = atClient.getCurrentAtSign();
    
    // Remove @ symbol if present since AtKey expects atSign without @
    if (currentAtSign != null && currentAtSign.startsWith('@')) {
      currentAtSign = currentAtSign.substring(1);
    }
    
    App.log('[DEBUG] createNewRole: currentAtSign = "$currentAtSign"'.loggable);
    
    if (currentAtSign == null || currentAtSign.isEmpty) {
      App.log('[ERROR] createNewRole: Cannot get current atSign'.loggable);
      return false;
    }
    
    // Generate a new unique ID for the role
    final String newRoleId = (_maxGroupId + 1).toString();

    // Overwrite the role.id as specified in the interface
    role.id = newRoleId;

    final String atKeyStr = '${role.id}.groups.policy.sshnp@$currentAtSign';
    final String value = jsonEncode(role.toJson());
    
    App.log('[DEBUG] createNewRole: role.id = "${role.id}"'.loggable);
    App.log('[DEBUG] createNewRole: atKeyStr = "$atKeyStr"'.loggable);
    App.log('[DEBUG] createNewRole: value = "$value"'.loggable);

    try {
      bool success = await atClient.put(AtKey.fromString(atKeyStr), value, putRequestOptions: pro);
      
      if (success) {
        // Add the new role to cache
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
      // Update existing role
      _roles[existingIndex] = role;
    } else {
      // Add new role if not found (shouldn't happen in updateExistingRole)
      _roles.add(role);
    }
  }

  /// Helper method to get the maximum existing role ID (for reference)
  int get _maxGroupId {
    if (_roles.isEmpty) return 0;
    
    int maxId = 0;
    for (final role in _roles) {
      if (role.id != null) {
        // Try to parse as int, fall back to 0 if not numeric
        final parsedId = int.tryParse(role.id!) ?? 0;
        if (parsedId > maxId) {
          maxId = parsedId;
        }
      }
    }
    return maxId;
  }
}