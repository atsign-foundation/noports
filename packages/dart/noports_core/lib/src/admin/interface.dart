import 'package:at_client/at_client.dart';
import 'package:noports_core/admin.dart';

abstract interface class PolicyService {
  /// Get (some of) the permission groups known to this policy service.
  /// Method rather than getter, as we will add query parameters later
  Future<List<UserGroup>> getUserGroups();

  /// Get a group object by its name
  Future<UserGroup?> getUserGroup(String name);

  /// Add or update a group.
  Future<void> updateUserGroup(UserGroup group);

  /// Delete a group.
  /// Return true if deleted, false if not.
  Future<bool> deleteUserGroup(String groupId);

  /// Get (some of) the client-side users known to this policy service.
  /// Method rather than getter, as we will add query parameters later.
  Future<List<User>> getUsers();

  /// Get user object by its atSign
  Future<User?> getUser(String atSign);

  /// Add or update a user.
  Future<void> updateUser(User user);

  /// Delete a user.
  /// Return true if deleted, false if not.
  /// Throws a StateError if user is still a member of any group
  Future<bool> deleteUser(String atSign);

  /// Get the list of groups of which this user is a member.
  Future<List<UserGroup>> getGroupsForUser(String atSign);

  factory PolicyService.withAtClient({
    required AtClient atClient,
  }) {
    return PolicyServiceWithAtClient(
      atClient: atClient,
    );
  }
}

