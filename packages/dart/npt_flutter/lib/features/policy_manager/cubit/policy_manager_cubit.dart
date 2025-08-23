import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/role_repository.dart';
import '../models/policy.dart';

part 'policy_manager_state.dart';

class PolicyManagerCubit extends Cubit<PolicyManagerState> {
  final RoleRepository _roleRepository;
  
  PolicyManagerCubit(this._roleRepository) : super(const PolicyManagerLoading());

  /// Load all roles and enter browsing mode
  Future<void> loadRoles() async {
    emit(const PolicyManagerLoading(operation: 'Loading roles'));
    try {
      final roles = await _roleRepository.fetchRoles();
      emit(PolicyManagerLoaded(
        roles: roles,
        viewMode: PolicyManagerViewMode.rolesBrowsing,
      ));
    } catch (e) {
      emit(PolicyManagerError(
        'Failed to load roles: $e',
        operation: 'loadRoles',
      ));
    }
  }

  /// Select a role for viewing (read-only)
  void selectRoleForViewing(String roleId) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      if (!currentState.canSelectRole) return;
      
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      
      emit(currentState.copyWith(
        selectedRole: selectedRole,
        viewMode: PolicyManagerViewMode.roleViewing,
      ));
    }
  }

  /// Start editing an existing role
  void startEditingRole(String roleId) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      final roleToEdit = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      
      emit(currentState.copyWith(
        selectedRole: roleToEdit,
        viewMode: PolicyManagerViewMode.roleEditing,
      ));
    }
  }

  /// Start creating a new role
  void startCreatingRole() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      final emptyRole = Role.empty(name: '');
      emit(currentState.copyWith(
        selectedRole: emptyRole,
        viewMode: PolicyManagerViewMode.roleCreating,
      ));
    }
  }

  /// Cancel editing or creating and return to appropriate state
  void cancelEditing() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      if (currentState.isRoleCreating) {
        // Return to browsing mode when canceling creation
        emit(currentState.copyWith(
          clearSelectedRole: true,
          viewMode: PolicyManagerViewMode.rolesBrowsing,
        ));
      } else if (currentState.isRoleEditing && currentState.hasSelectedRole) {
        // Return to viewing mode when canceling edit
        emit(currentState.copyWith(
          viewMode: PolicyManagerViewMode.roleViewing,
        ));
      }
    }
  }

  /// Exit viewing mode and return to browsing
  void exitViewing() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      if (currentState.isRoleViewing) {
        emit(currentState.copyWith(
          clearSelectedRole: true,
          viewMode: PolicyManagerViewMode.rolesBrowsing,
        ));
      }
    }
  }

  /// Create a new role
  Future<void> createRole(Role role) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      if (!currentState.isRoleCreating) return;
      
      emit(const PolicyManagerLoading(operation: 'Creating role'));
      
      try {
        final success = await _roleRepository.createNewRole(role);
        if (success) {
          // Refresh roles and show the created role
          final updatedRoles = await _roleRepository.fetchRoles();
          final createdRole = updatedRoles.firstWhere(
            (r) => r.name == role.name && r.description == role.description,
            orElse: () => updatedRoles.last,
          );
          
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            selectedRole: createdRole,
            viewMode: PolicyManagerViewMode.roleViewing,
          ));
        } else {
          emit(PolicyManagerError(
            'Failed to create role',
            operation: 'createRole',
            previousViewMode: currentState.viewMode,
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        emit(PolicyManagerError(
          'Failed to create role: $error',
          operation: 'createRole',
          previousViewMode: currentState.viewMode,
          previousRoles: currentState.roles,
          previousSelectedRole: currentState.selectedRole,
        ));
      }
    }
  }

  /// Update an existing role
  Future<void> updateRole(Role role) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      if (!currentState.isRoleEditing) return;
      
      emit(const PolicyManagerLoading(operation: 'Updating role'));
      
      try {
        final success = await _roleRepository.updateExistingRole(role);
        if (success) {
          // Refresh roles and stay in viewing mode
          final updatedRoles = await _roleRepository.fetchRoles();
          final updatedRole = updatedRoles.firstWhere(
            (r) => r.id == role.id,
            orElse: () => role,
          );
          
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            selectedRole: updatedRole,
            viewMode: PolicyManagerViewMode.roleViewing,
          ));
        } else {
          emit(PolicyManagerError(
            'Failed to update role',
            operation: 'updateRole',
            previousViewMode: currentState.viewMode,
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        emit(PolicyManagerError(
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
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      emit(const PolicyManagerLoading(operation: 'Deleting role'));
      
      try {
        final success = await _roleRepository.deleteRole(roleId);
        if (success) {
          // Refresh roles and return to browsing
          final updatedRoles = await _roleRepository.fetchRoles();
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            viewMode: PolicyManagerViewMode.rolesBrowsing,
          ));
        } else {
          emit(PolicyManagerError(
            'Failed to delete role',
            operation: 'deleteRole',
            previousViewMode: currentState.viewMode,
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        emit(PolicyManagerError(
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
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      emit(currentState.copyWith(
        clearSelectedRole: true,
        viewMode: PolicyManagerViewMode.logsViewing,
      ));
    }
  }

  /// Return to roles browsing mode from logs
  void showRoles() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      if (currentState.isLogsViewing) {
        emit(currentState.copyWith(
          viewMode: PolicyManagerViewMode.rolesBrowsing,
        ));
      }
    }
  }

  /// Recover from error state if possible
  void recoverFromError() {
    if (state is PolicyManagerError) {
      final errorState = state as PolicyManagerError;
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
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      // Maintain current view mode and selection after refresh
      await loadRoles();
      
      if (state is PolicyManagerLoaded) {
        final refreshedState = state as PolicyManagerLoaded;
        
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