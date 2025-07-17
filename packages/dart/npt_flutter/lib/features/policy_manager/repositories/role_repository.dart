import '../models/policy.dart';

abstract class RoleRepository {
  Future<List<Role>> getAllRoles();
  Future<Role?> getRoleById(String id);
}