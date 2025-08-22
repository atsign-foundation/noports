import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/role_repository.dart';
import '../models/policy.dart';

part 'policy_manager_state.dart';

class PolicyManagerCubit extends Cubit<PolicyManagerState> {
  final RoleRepository _roleRepository;
  
  PolicyManagerCubit(this._roleRepository) : super(PolicyManagerInitial());

  void initialize() {
    emit(PolicyManagerInitial());
  }

  Future<void> loadRoles() async {
    emit(const PolicyManagerLoading());
    final roles = await _roleRepository.fetchRoles();
    emit(PolicyManagerRoleLoaded(roles: roles, isEditing: false));
  }

  void selectRole(String roleId) {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      if (currentState.isEditing) {
        return;
      }
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: selectedRole, isEditing: false));
    } else if (state is PolicyManagerViewLogsPageLoaded) {
      final currentState = state as PolicyManagerViewLogsPageLoaded;
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: selectedRole, isEditing: false));
    }
  }

  void deselectRole() {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, isEditing: false));
    }
  }

  void startEditing(String roleId) {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: selectedRole, isEditing: true));
    }
  }

  void stopEditing() {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: currentState.selectedRole, isEditing: false));
    }
  }

  Future<void> saveRole(Role role) async {
    emit(const PolicyManagerLoading());
    
    try {
      bool success = await _roleRepository.updateExistingRole(role);
      
      if (success) {
        final updatedRoles = await _roleRepository.fetchRoles();
        emit(PolicyManagerRoleLoaded(
          roles: updatedRoles,
          selectedRole: role,
          isEditing: false,
        ));
      } else {
        emit(const PolicyManagerError('Failed to save role'));
      }
    } catch (error) {
      emit(PolicyManagerError('Failed to save role: $error'));
    }
  }

  Future<void> createRole(Role role) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      
      final optimisticRole = Role(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: role.name,
        description: role.description,
        daemonAtSigns: role.daemonAtSigns,
        devices: role.devices,
        deviceGroups: role.deviceGroups,
        userAtSigns: role.userAtSigns,
      );
      final updatedRolesLocal = [...currentState.roles, optimisticRole];
      
      emit(PolicyManagerRoleLoaded(roles: updatedRolesLocal, selectedRole: optimisticRole, isEditing: false));
      
      try {
        bool success = await _roleRepository.createNewRole(role);
        
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          final createdRole = updatedRoles.firstWhere(
            (r) => r.name == role.name && r.description == role.description,
            orElse: () => role,
          );
          emit(PolicyManagerRoleLoaded(
            roles: updatedRoles,
            selectedRole: createdRole,
            isEditing: false,
          ));
        } else {
          emit(const PolicyManagerError('Failed to create role'));
          emit(PolicyManagerRoleLoaded(
            roles: currentState.roles,
            selectedRole: null,
            isEditing: false,
          ));
        }
      } catch (error) {
        emit(PolicyManagerError('Failed to create role: $error'));
        emit(PolicyManagerRoleLoaded(
          roles: currentState.roles,
          selectedRole: null,
          isEditing: false,
        ));
      }
    }
  }

  Future<void> deleteRole(String roleId) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      
      final updatedRolesLocal = currentState.roles.where((role) => role.id != roleId).toList();
      
      emit(PolicyManagerRoleLoaded(roles: updatedRolesLocal, selectedRole: null, isEditing: false));
      
      try {
        bool success = await _roleRepository.deleteRole(roleId);
        
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          emit(PolicyManagerRoleLoaded(roles: updatedRoles, selectedRole: null, isEditing: false));
        } else {
          emit(const PolicyManagerError('Failed to delete role'));
          emit(PolicyManagerRoleLoaded(
            roles: currentState.roles,
            selectedRole: currentState.selectedRole,
            isEditing: false,
          ));
        }
      } catch (error) {
        emit(PolicyManagerError('Failed to delete role: $error'));
        emit(PolicyManagerRoleLoaded(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
          isEditing: false,
        ));
      }
    }
  }

  Future<void> updateRole(Role role) async {
    emit(const PolicyManagerLoading());
    
    try {
      bool success = await _roleRepository.updateExistingRole(role);
      
      if (success) {
        final updatedRoles = await _roleRepository.fetchRoles();
        emit(PolicyManagerRoleLoaded(
          roles: updatedRoles,
          selectedRole: role,
          isEditing: false,
        ));
      } else {
        emit(const PolicyManagerError('Failed to update role'));
      }
    } catch (error) {
      emit(PolicyManagerError('Failed to update role: $error'));
    }
  }

  void cancelEdit() {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: currentState.selectedRole, isEditing: false));
    }
  }

  void startNewRole() {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      final emptyRole = Role.empty(name: '');
      emit(PolicyManagerRoleLoaded(
        roles: currentState.roles,
        selectedRole: emptyRole,
        isEditing: true,
      ));
    }
  }

  Future<void> showLogs() async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerViewLogsPageLoaded(
        roles: currentState.roles,
        selectedRole: null,
      ));
    } else if (state is PolicyManagerViewLogsPageLoaded) {
      return;
    } else if (state is PolicyManagerLoading && (state as PolicyManagerLoading).roles != null) {
      final currentState = state as PolicyManagerLoading;
      emit(PolicyManagerViewLogsPageLoaded(
        roles: currentState.roles!,
        selectedRole: null,
      ));
    } else {
      final roles = await _roleRepository.fetchRoles();
      emit(PolicyManagerViewLogsPageLoaded(
        roles: roles,
        selectedRole: null,
      ));
    }
  }

  void showRoles() {
    if (state is PolicyManagerViewLogsPageLoaded) {
      final currentState = state as PolicyManagerViewLogsPageLoaded;
      emit(PolicyManagerRoleLoaded(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
        isEditing: false,
      ));
    } else if (state is PolicyManagerRoleLoaded) {
      return;
    }
  }
}