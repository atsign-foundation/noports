import '../../logging/models/loggable.dart';
import '../../logging/models/logging_bloc.dart';
import '../repositories/role_repository.dart';
import '../models/policy.dart';

part 'policy_state.dart';

class PolicyCubit extends LoggingCubit<PolicyState> {
  final RoleRepository _roleRepository;

  PolicyCubit(this._roleRepository) : super(const PolicyInitial());

  Future<void> loadRoles() async {
    emit(const PolicyLoading(operation: 'Loading roles'));
    try {
      final List<FetchedRole> roles = await _roleRepository.fetchRoles();
      emit(PolicyBrowsingRoles(roles: roles));
    } catch (e) {
      emit(PolicyError('Failed to load roles: $e', operation: 'loadRoles'));
    }
  }

  Future<void> updateExistingRole(FetchedRole role) async {
    if (state is PolicyEditingRole) {
      final currentState = state as PolicyEditingRole;
      emit(const PolicyLoading(operation: 'Updating role'));
      try {
        final success = await _roleRepository.updateExistingRole(role);
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          final updatedRole = updatedRoles.firstWhere(
            (r) => r.id == role.id,
            orElse: () => role,
          );

          emit(
            PolicyViewingRole(
              roles: updatedRoles,
              selectedRole: updatedRole,
            ),
          );
        } else {
          emit(
            PolicyError(
              'Failed to update role',
              operation: 'updateRole',
              previousState: currentState,
            ),
          );
        }
      } catch (error) {
        emit(
          PolicyError(
            'Failed to update role: $error',
            operation: 'updateRole',
            previousState: currentState,
          ),
        );
      }
    }
  }

  Future<void> deleteRole(String roleId) async {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;

      emit(const PolicyLoading(operation: 'Deleting role'));

      try {
        final success = await _roleRepository.deleteRole(roleId);
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          emit(PolicyBrowsingRoles(roles: updatedRoles));
        } else {
          emit(
            PolicyError(
              'Failed to delete role',
              operation: 'deleteRole',
              previousState: currentState,
            ),
          );
        }
      } catch (error) {
        emit(
          PolicyError(
            'Failed to delete role: $error',
            operation: 'deleteRole',
            previousState: currentState,
          ),
        );
      }
    }
  }

  void selectRoleForViewing(String roleId) {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      if (state is PolicyEditingRole || state is PolicyCreatingRole) {
        return;
      }
      if (state is PolicyViewingRole &&
          (state as PolicyViewingRole).selectedRole.id == roleId) {
        return;
      }
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(
        PolicyViewingRole(
          roles: currentState.roles,
          selectedRole: selectedRole,
        ),
      );
    }
  }

  void startEditingRole(String roleId) {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      final roleToEdit = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(
        PolicyEditingRole(
          roles: currentState.roles,
          selectedRole: roleToEdit,
        ),
      );
    }
  }

  void startCreatingRole() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      emit(
        PolicyCreatingRole(
          roles: currentState.roles,
        ),
      );
    }
  }

  void cancelEditing() {
    if (state is PolicyCreatingRole) {
      final currentState = state as PolicyCreatingRole;
      emit(PolicyBrowsingRoles(roles: currentState.roles));
    } else if (state is PolicyEditingRole) {
      final currentState = state as PolicyEditingRole;
      emit(
        PolicyViewingRole(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
        ),
      );
    }
  }

  void exitViewing() {
    if (state is PolicyViewingRole) {
      final currentState = state as PolicyViewingRole;
      emit(PolicyBrowsingRoles(roles: currentState.roles));
    }
  }

  void showLogs() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      emit(PolicyViewingLogs(roles: currentState.roles));
    }
  }

  void showRoles() {
    if (state is PolicyViewingLogs) {
      final currentState = state as PolicyViewingLogs;
      emit(PolicyBrowsingRoles(roles: currentState.roles));
    }
  }

  void recoverFromError() {
    if (state is PolicyError) {
      final errorState = state as PolicyError;
      final recoverableState = errorState.recoverableState;

      if (recoverableState != null) {
        emit(recoverableState);
      } else {
        loadRoles();
      }
    }
  }
}
