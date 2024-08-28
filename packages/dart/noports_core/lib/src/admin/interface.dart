import 'package:at_client/at_client.dart';
import 'package:noports_core/admin.dart';

abstract interface class PolicyService {
  /// Get (some of) the permission groups known to this policy service.
  /// Method rather than getter, as we will add query parameters later
  Future<List<UserGroup>> getUserGroups();

  /// Get a group object by its ID
  Future<UserGroup?> getUserGroup(String id);

  /// Create a group. Must not already have an `id`
  Future<UserGroup> createUserGroup(UserGroup group);

  /// Update a group. Must already have an `id`
  Future<void> updateUserGroup(UserGroup group);

  /// Delete a group.
  /// Return true if deleted, false if not.
  Future<bool> deleteUserGroup(String id);

  factory PolicyService.withAtClient({
    required AtClient atClient,
  }) {
    return PolicyServiceWithAtClient(
      atClient: atClient,
    );
  }
}

