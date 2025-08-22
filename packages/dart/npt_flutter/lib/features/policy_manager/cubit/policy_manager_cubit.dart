import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/role_repository.dart';
import '../models/policy.dart';

part 'policy_manager_state.dart';

class PolicyManagerCubit extends Cubit<PolicyManagerState> {
  final RoleRepository _roleRepository;
  
  PolicyManagerCubit(this._roleRepository) : super(const PolicyManagerLoading());

  Future<void> loadRoles() async {
    emit(const PolicyManagerLoading());
    try {
      final roles = await _roleRepository.fetchRoles();
      emit(PolicyManagerLoaded(roles: roles));
    } catch (e) {
      emit(PolicyManagerError('Failed to load roles: $e'));
    }
  }

  void selectRole(String roleId) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      if (currentState.isEditing) return;
      
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(currentState.copyWith(selectedRole: selectedRole));
    }
  }

  void deselectRole() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(clearSelectedRole: true));
    }
  }

  void startEditing(String roleId) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      
      emit(currentState.copyWith(
        selectedRole: selectedRole,
        isEditing: true,
      ));
    }
  }

  void stopEditing() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(isEditing: false));
    }
  }

  void startNewRole() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final emptyRole = Role.empty(name: '');
      emit(currentState.copyWith(
        selectedRole: emptyRole,
        isEditing: true,
      ));
    }
  }

  Future<void> createRole(Role role) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      // Optimistic update
      final optimisticRole = Role(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: role.name,
        description: role.description,
        daemonAtSigns: role.daemonAtSigns,
        devices: role.devices,
        deviceGroups: role.deviceGroups,
        userAtSigns: role.userAtSigns,
      );
      
      final updatedRoles = [...currentState.roles, optimisticRole];
      emit(PolicyManagerLoaded(
        roles: updatedRoles,
        selectedRole: optimisticRole,
        isEditing: false,
      ));
      
      try {
        final success = await _roleRepository.createNewRole(role);
        if (success) {
          // Refresh from server to get the actual created role
          final serverRoles = await _roleRepository.fetchRoles();
          final createdRole = serverRoles.firstWhere(
            (r) => r.name == role.name && r.description == role.description,
            orElse: () => optimisticRole,
          );
          emit(PolicyManagerLoaded(
            roles: serverRoles,
            selectedRole: createdRole,
          ));
        } else {
          // Rollback on failure
          emit(PolicyManagerLoaded(roles: currentState.roles));
          emit(PolicyManagerError(
            'Failed to create role',
            previousRoles: currentState.roles,
          ));
        }
      } catch (error) {
        // Rollback on error
        emit(PolicyManagerLoaded(roles: currentState.roles));
        emit(PolicyManagerError(
          'Failed to create role: $error',
          previousRoles: currentState.roles,
        ));
      }
    }
  }

  Future<void> updateRole(Role role) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(const PolicyManagerLoading());
      
      try {
        final success = await _roleRepository.updateExistingRole(role);
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            selectedRole: role,
          ));
        } else {
          emit(PolicyManagerLoaded(
            roles: currentState.roles,
            selectedRole: currentState.selectedRole,
          ));
          emit(PolicyManagerError(
            'Failed to update role',
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        emit(PolicyManagerLoaded(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
        ));
        emit(PolicyManagerError(
          'Failed to update role: $error',
          previousRoles: currentState.roles,
          previousSelectedRole: currentState.selectedRole,
        ));
      }
    }
  }

  Future<void> deleteRole(String roleId) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      // Optimistic update
      final updatedRoles = currentState.roles.where((role) => role.id != roleId).toList();
      emit(PolicyManagerLoaded(roles: updatedRoles));
      
      try {
        final success = await _roleRepository.deleteRole(roleId);
        if (success) {
          final serverRoles = await _roleRepository.fetchRoles();
          emit(PolicyManagerLoaded(roles: serverRoles));
        } else {
          // Rollback on failure
          emit(PolicyManagerLoaded(
            roles: currentState.roles,
            selectedRole: currentState.selectedRole,
          ));
          emit(PolicyManagerError(
            'Failed to delete role',
            previousRoles: currentState.roles,
            previousSelectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        // Rollback on error
        emit(PolicyManagerLoaded(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
        ));
        emit(PolicyManagerError(
          'Failed to delete role: $error',
          previousRoles: currentState.roles,
          previousSelectedRole: currentState.selectedRole,
        ));
      }
    }
  }

  void showLogs() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(
        currentView: PolicyManagerView.logs,
        clearSelectedRole: true,
      ));
    }
  }

  void showRoles() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(currentView: PolicyManagerView.roles));
    }
  }

  void cancelEdit() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(isEditing: false));
    }
  }

  /// Helper method to recover from error state
  void recoverFromError() {
    if (state is PolicyManagerError) {
      final errorState = state as PolicyManagerError;
      if (errorState.previousRoles != null) {
        emit(PolicyManagerLoaded(
          roles: errorState.previousRoles!,
          selectedRole: errorState.previousSelectedRole,
        ));
      } else {
        loadRoles();
      }
    }
  }
}