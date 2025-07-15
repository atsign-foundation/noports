import 'package:flutter/material.dart';
import '../../models/policy.dart';

class PolicyUtils {
  PolicyUtils._();

  /// Creates a new role with the given name and unique ID
  static Role createNewRole(String name) {
    return Role.empty(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
  }

  /// Creates a copy of a role with updated name
  static Role copyRoleWithName(Role role, String name) {
    return Role(
      id: role.id,
      name: name,
      description: role.description,
      deviceAtSigns: role.deviceAtSigns,
      deviceNames: role.deviceNames,
      deviceGroups: role.deviceGroups,
      userAtSigns: role.userAtSigns,
    );
  }

  /// Creates a copy of a role with updated description
  static Role copyRoleWithDescription(Role role, String description) {
    return Role(
      id: role.id,
      name: role.name,
      description: description,
      deviceAtSigns: role.deviceAtSigns,
      deviceNames: role.deviceNames,
      deviceGroups: role.deviceGroups,
      userAtSigns: role.userAtSigns,
    );
  }

  /// Creates a copy of a role with updated device AtSigns
  static Role copyRoleWithDeviceAtSigns(Role role, List<String> deviceAtSigns) {
    return Role(
      id: role.id,
      name: role.name,
      description: role.description,
      deviceAtSigns: deviceAtSigns.map((e) => DeviceAtSign(atSign: e)).toList(),
      deviceNames: role.deviceNames,
      deviceGroups: role.deviceGroups,
      userAtSigns: role.userAtSigns,
    );
  }

  /// Creates a copy of a role with updated device names
  static Role copyRoleWithDeviceNames(Role role, List<String> deviceNames) {
    return Role(
      id: role.id,
      name: role.name,
      description: role.description,
      deviceAtSigns: role.deviceAtSigns,
      deviceNames: deviceNames.map((e) => Device(name: e, permitOpens: [])).toList(),
      deviceGroups: role.deviceGroups,
      userAtSigns: role.userAtSigns,
    );
  }

  /// Creates a copy of a role with updated device groups
  static Role copyRoleWithDeviceGroups(Role role, List<String> deviceGroups) {
    return Role(
      id: role.id,
      name: role.name,
      description: role.description,
      deviceAtSigns: role.deviceAtSigns,
      deviceNames: role.deviceNames,
      deviceGroups: deviceGroups.map((e) => DeviceGroup(name: e, permitOpens: [])).toList(),
      userAtSigns: role.userAtSigns,
    );
  }

  /// Creates a copy of a role with updated user AtSigns
  static Role copyRoleWithUserAtSigns(Role role, List<String> userAtSigns) {
    return Role(
      id: role.id,
      name: role.name,
      description: role.description,
      deviceAtSigns: role.deviceAtSigns,
      deviceNames: role.deviceNames,
      deviceGroups: role.deviceGroups,
      userAtSigns: userAtSigns.map((e) => UserAtSign(atSign: e)).toList(),
    );
  }

  /// Updates a role in a list of roles
  static List<Role> updateRoleInList(List<Role> roles, Role updatedRole) {
    return roles.map((role) {
      return role.id == updatedRole.id ? updatedRole : role;
    }).toList();
  }

  /// Removes a role from a list of roles
  static List<Role> removeRoleFromList(List<Role> roles, Role roleToRemove) {
    return roles.where((role) => role.id != roleToRemove.id).toList();
  }

  /// Validates if a string is not empty after trimming
  static bool isValidInput(String? input) {
    return input != null && input.trim().isNotEmpty;
  }

  /// Shows a success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Shows an error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Shows an info snackbar
  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}