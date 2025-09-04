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
      emit(RolesBrowsingState(roles: roles));
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
      if (state is RoleEditingState || state is RoleCreatingState) return;
      if (state is RoleViewingState && (state as RoleViewingState).selectedRole.id == roleId) {
        return;
      }
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(RoleViewingState(
        roles: currentState.roles,
        selectedRole: selectedRole,
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
      emit(RoleEditingState(
        roles: currentState.roles,
        selectedRole: roleToEdit,
      ));
    }
  }

  void startCreatingRole() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      final emptyRole = Role.empty(id: '', name: '');
      emit(RoleCreatingState(
        roles: currentState.roles,
        selectedRole: emptyRole,
      ));
    }
  }

  void cancelEditing() {
    if (state is RoleCreatingState) {
      final currentState = state as RoleCreatingState;
      emit(RolesBrowsingState(roles: currentState.roles));
    } else if (state is RoleEditingState) {
      final currentState = state as RoleEditingState;
      emit(RoleViewingState(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
      ));
    }
  }

  void exitViewing() {
    if (state is RoleViewingState) {
      final currentState = state as RoleViewingState;
      emit(RolesBrowsingState(roles: currentState.roles));
    }
  }

  Future<void> createRole(Role role) async {
    if (state is RoleCreatingState) {
      final currentState = state as RoleCreatingState;

      emit(const PolicyLoading(operation: 'Creating role'));

      try {
        final success = await _roleRepository.updateRole(role);
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          final createdRole = updatedRoles.firstWhere(
            (r) => r.name == role.name && r.description == role.description,
            orElse: () => updatedRoles.last,
          );

          emit(RoleViewingState(
            roles: updatedRoles,
            selectedRole: createdRole,
          ));
        } else {
          emit(PolicyError(
            'Failed to create role',
            operation: 'createRole',
            previousState: currentState,
          ));
        }
      } catch (error) {
        emit(PolicyError(
          'Failed to create role: $error',
          operation: 'createRole',
          previousState: currentState,
        ));
      }
    }
  }

  Future<void> updateRole(Role role) async {
    if (state is RoleEditingState) {
      final currentState = state as RoleEditingState;

      emit(const PolicyLoading(operation: 'Updating role'));

      try {
        final success = await _roleRepository.updateRole(role);
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          final updatedRole = updatedRoles.firstWhere(
            (r) => r.id == role.id,
            orElse: () => role,
          );

          emit(RoleViewingState(
            roles: updatedRoles,
            selectedRole: updatedRole,
          ));
        } else {
          emit(PolicyError(
            'Failed to update role',
            operation: 'updateRole',
            previousState: currentState,
          ));
        }
      } catch (error) {
        emit(PolicyError(
          'Failed to update role: $error',
          operation: 'updateRole',
          previousState: currentState,
        ));
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
          emit(RolesBrowsingState(roles: updatedRoles));
        } else {
          emit(PolicyError(
            'Failed to delete role',
            operation: 'deleteRole',
            previousState: currentState,
          ));
        }
      } catch (error) {
        emit(PolicyError(
          'Failed to delete role: $error',
          operation: 'deleteRole',
          previousState: currentState,
        ));
      }
    }
  }

  void showLogs() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      emit(LogsViewingState(roles: currentState.roles));
    }
  }

  void showRoles() {
    if (state is LogsViewingState) {
      final currentState = state as LogsViewingState;
      emit(RolesBrowsingState(roles: currentState.roles));
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

  Future<void> refresh() async {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      
      await loadRoles();
      
      if (state is RolesBrowsingState) {
        final refreshedState = state as RolesBrowsingState;
        
        if (currentState is RoleViewingState) {
          final selectedRoleId = currentState.selectedRole.id;
          final stillExists = refreshedState.roles.any(
            (role) => role.id == selectedRoleId,
          );
          
          if (stillExists) {
            final updatedRole = refreshedState.roles.firstWhere(
              (role) => role.id == selectedRoleId,
            );
            emit(RoleViewingState(
              roles: refreshedState.roles,
              selectedRole: updatedRole,
            ));
          }
        } else if (currentState is RoleEditingState) {
          final selectedRoleId = currentState.selectedRole.id;
          final stillExists = refreshedState.roles.any(
            (role) => role.id == selectedRoleId,
          );
          
          if (stillExists) {
            final updatedRole = refreshedState.roles.firstWhere(
              (role) => role.id == selectedRoleId,
            );
            emit(RoleEditingState(
              roles: refreshedState.roles,
              selectedRole: updatedRole,
            ));
          }
        } else if (currentState is LogsViewingState) {
          emit(LogsViewingState(roles: refreshedState.roles));
        }
      }
    }
  }
}