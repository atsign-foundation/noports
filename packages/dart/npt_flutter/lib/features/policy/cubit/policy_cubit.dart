import '../../logging/models/loggable.dart';
import '../../logging/models/logging_bloc.dart';
import '../repositories/role_repository.dart';
import '../models/policy.dart';

part 'policy_state.dart';

class PolicyCubit extends LoggingCubit<PolicyState> {
  final RoleRepository _roleRepository;

  PolicyCubit(this._roleRepository) : super(const PolicyLoading());

  Future<void> loadRoles() async {
    emit(const PolicyLoading(operation: 'Loading roles'));
    try {
      final roles = await _roleRepository.fetchRoles();
      emit(PolicyLoaded(
        roles: roles,
        viewMode: PolicyViewMode.rolesBrowsing,
      ));
    } catch (e) {
      emit(PolicyError(
        'Failed to load roles: $e',
        operation: 'loadRoles',
      ));
    }
  }

  void selectRoleForViewing(String roleId) {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      if (!currentState.canSelectRole) return;
      if (currentState.isRoleViewing && currentState.selectedRole?.id == roleId) {
        return;
      }
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(currentState.copyWith(
        selectedRole: selectedRole,
        viewMode: PolicyViewMode.roleViewing,
      ));
    }
  }

  void startEditingRole(String roleId) {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      final roleToEdit = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(currentState.copyWith(
        selectedRole: roleToEdit,
        viewMode: PolicyViewMode.roleEditing,
      ));
    }
  }

  void startCreatingRole() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      final emptyRole = Role.empty(name: '');
      emit(currentState.copyWith(
        selectedRole: emptyRole,
        viewMode: PolicyViewMode.roleCreating,
      ));
    }
  }

  void cancelEditing() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      if (currentState.isRoleCreating) {
        emit(currentState.copyWith(
          clearSelectedRole: true,
          viewMode: PolicyViewMode.rolesBrowsing,
        ));
      } else if (currentState.isRoleEditing && currentState.hasSelectedRole) {
        emit(currentState.copyWith(
          viewMode: PolicyViewMode.roleViewing,
        ));
      }
    }
  }

  void exitViewing() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      if (currentState.isRoleViewing) {
        emit(currentState.copyWith(
          clearSelectedRole: true,
          viewMode: PolicyViewMode.rolesBrowsing,
        ));
      }
    }
  }

  Future<void> createRole(Role role) async {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      if (!currentState.isRoleCreating) return;

      emit(const PolicyLoading(operation: 'Creating role'));

      try {
        final success = await _roleRepository.createNewRole(role);
        if (success) {
          // Refresh roles and show the created role
          final updatedRoles = await _roleRepository.fetchRoles();
          final createdRole = updatedRoles.firstWhere(
            (r) => r.name == role.name && r.description == role.description,
            orElse: () => updatedRoles.last,
          );

          emit(PolicyLoaded(
            roles: updatedRoles,
            selectedRole: createdRole,
            viewMode: PolicyViewMode.roleViewing,
          ));
        } else {
          emit(PolicyError(
            'Failed to create role',
            operation: 'createRole',
            previousViewMode: currentState.viewMode,
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        emit(PolicyError(
          'Failed to create role: $error',
          operation: 'createRole',
          previousViewMode: currentState.viewMode,
          previousRoles: currentState.roles,
          previousSelectedRole: currentState.selectedRole,
        ));
      }
    }
  }

  Future<void> updateRole(Role role) async {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      if (!currentState.isRoleEditing) return;

      emit(const PolicyLoading(operation: 'Updating role'));

      try {
        final success = await _roleRepository.updateExistingRole(role);
        if (success) {
          // Refresh roles and stay in viewing mode
          final updatedRoles = await _roleRepository.fetchRoles();
          final updatedRole = updatedRoles.firstWhere(
            (r) => r.id == role.id,
            orElse: () => role,
          );

          emit(PolicyLoaded(
            roles: updatedRoles,
            selectedRole: updatedRole,
            viewMode: PolicyViewMode.roleViewing,
          ));
        } else {
          emit(PolicyError(
            'Failed to update role',
            operation: 'updateRole',
            previousViewMode: currentState.viewMode,
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        emit(PolicyError(
          'Failed to update role: $error',
          operation: 'updateRole',
          previousViewMode: currentState.viewMode,
          previousRoles: currentState.roles,
          previousSelectedRole: currentState.selectedRole,
        ));
      }
    }
  }

  /// Delete a role
  Future<void> deleteRole(String roleId) async {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      
      emit(const PolicyLoading(operation: 'Deleting role'));
      
      try {
        final success = await _roleRepository.deleteRole(roleId);
        if (success) {
          // Refresh roles and return to browsing
          final updatedRoles = await _roleRepository.fetchRoles();
          emit(PolicyLoaded(
            roles: updatedRoles,
            viewMode: PolicyViewMode.rolesBrowsing,
          ));
        } else {
          emit(PolicyError(
            'Failed to delete role',
            operation: 'deleteRole',
            previousViewMode: currentState.viewMode,
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        emit(PolicyError(
          'Failed to delete role: $error',
          operation: 'deleteRole',
          previousViewMode: currentState.viewMode,
          previousRoles: currentState.roles,
          previousSelectedRole: currentState.selectedRole,
        ));
      }
    }
  }

  /// Switch to logs viewing mode
  void showLogs() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      
      emit(currentState.copyWith(
        clearSelectedRole: true,
        viewMode: PolicyViewMode.logsViewing,
      ));
    }
  }

  /// Return to roles browsing mode from logs
  void showRoles() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      
      if (currentState.isLogsViewing) {
        emit(currentState.copyWith(
          viewMode: PolicyViewMode.rolesBrowsing,
        ));
      }
    }
  }

  /// Recover from error state if possible
  void recoverFromError() {
    if (state is PolicyError) {
      final errorState = state as PolicyError;
      final recoverableState = errorState.recoverableState;
      
      if (recoverableState != null) {
        emit(recoverableState);
      } else {
        // Fallback to loading roles
        loadRoles();
      }
    }
  }

  /// Force refresh current view
  Future<void> refresh() async {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      
      // Maintain current view mode and selection after refresh
      await loadRoles();
      
      if (state is PolicyLoaded) {
        final refreshedState = state as PolicyLoaded;
        
        // Try to restore the previous view mode and selection
        if (currentState.hasSelectedRole && currentState.selectedRole?.id != null) {
          final stillExists = refreshedState.roles.any(
            (role) => role.id == currentState.selectedRole!.id,
          );
          
          if (stillExists) {
            final updatedRole = refreshedState.roles.firstWhere(
              (role) => role.id == currentState.selectedRole!.id,
            );
            
            emit(refreshedState.copyWith(
              selectedRole: updatedRole,
              viewMode: currentState.viewMode,
            ));
          }
        } else {
          // Restore view mode without selection
          emit(refreshedState.copyWith(
            viewMode: currentState.viewMode,
          ));
        }
      }
    }
  }
}