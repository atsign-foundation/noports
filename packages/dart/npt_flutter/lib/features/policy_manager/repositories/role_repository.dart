import '../models/policy.dart';

abstract class RoleRepository {
  List<Role> get getRoles;
  Future<void> fetchRoles();
  Future<bool> updateExistingRole(Role role);
  Future<bool> createNewRole(Role role); // this method overwrites the role.id of the object you pass in
}