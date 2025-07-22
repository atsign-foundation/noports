import '../models/policy.dart';

abstract class RoleRepository {
  Future<List<Role>> fetchRoles();
  Future<bool> updateExistingRole(Role role);
  Future<bool> createNewRole(Role role); // this method overwrites the role.id of the object you pass in
  Future<bool> deleteRole(String roleId);
}