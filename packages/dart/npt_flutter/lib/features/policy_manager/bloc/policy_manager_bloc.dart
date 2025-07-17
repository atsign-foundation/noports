import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/policy.dart';
import '../repositories/role_repository.dart';
import 'policy_manager_state.dart';
import 'policy_manager_event.dart';

class PolicyManagerBloc extends Bloc<PolicyManagerEvent, PolicyManagerState> {
  final RoleRepository _roleRepository;
  
  PolicyManagerBloc(this._roleRepository) : super(PolicyManagerInitial()) {
    on<PolicyManagerInitialEvent>(_onInitial);
    on<PolicyManagerLoadingRoles>(_onLoadingRoles);
    on<PolicyManagerRoleSelected>(_onRoleSelected);
    on<PolicyManagerRoleDeselected>(_onRoleDeselected);
    on<PolicyManagerStartEditing>(_onStartEditing);
    on<PolicyManagerStopEditing>(_onStopEditing);
    on<PolicyManagerSaveRole>(_onSaveRole);
    on<PolicyManagerCreateRole>(_onCreateRole);
    on<PolicyManagerDeleteRole>(_onDeleteRole);
    on<PolicyManagerUpdateRole>(_onUpdateRole);
    on<PolicyManagerCancelEdit>(_onCancelEdit);
  }

  void _onInitial(PolicyManagerInitialEvent event, Emitter<PolicyManagerState> emit) {
    emit(PolicyManagerInitial());
  }

  void _onLoadingRoles(PolicyManagerLoadingRoles event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading(roles: []));
    
    try {
      final roles = await _roleRepository.getAllRoles();
      emit(PolicyManagerLoaded(roles: roles));
    } catch (error) {
      emit(PolicyManagerError('Failed to load roles: $error'));
    }
  }

  void _onRoleSelected(PolicyManagerRoleSelected event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == event.roleId,
        orElse: () => currentState.roles.first,
      );
      
      emit(currentState.copyWith(selectedRole: selectedRole));
    }
  }

  void _onRoleDeselected(PolicyManagerRoleDeselected event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(clearSelectedRole: true));
    }
  }

  void _onStartEditing(PolicyManagerStartEditing event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == event.roleId,
        orElse: () => currentState.roles.first,
      );
      
      // Set the selected role and indicate editing mode
      emit(currentState.copyWith(selectedRole: selectedRole));
    }
  }

  void _onStopEditing(PolicyManagerStopEditing event, Emitter<PolicyManagerState> emit) {
    // This can be used to clear any editing-specific state
    // For now, we'll just maintain the current state
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith());
    }
  }

  void _onSaveRole(PolicyManagerSaveRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      // Update the loading state to show saving in progress
      emit(PolicyManagerLoading(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
      ));
      
      try {
        // TODO: Implement role save functionality in repository
        // await _roleRepository.saveRole(event.role);
        
        // Update the roles list with the saved role
        final updatedRoles = currentState.roles.map((role) {
          if (role.id == event.role.id) {
            return event.role;
          }
          return role;
        }).toList();
        
        emit(PolicyManagerLoaded(
          roles: updatedRoles,
          selectedRole: event.role,
        ));
      } catch (error) {
        emit(PolicyManagerError('Failed to save role: $error', roles: currentState.roles));
      }
    }
  }

  void _onCreateRole(PolicyManagerCreateRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      emit(PolicyManagerLoading(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
      ));
      
      try {
        // TODO: Implement role creation functionality in repository
        // await _roleRepository.createRole(event.role);
        
        // Add the new role to the roles list
        final updatedRoles = [...currentState.roles, event.role];
        
        emit(PolicyManagerLoaded(
          roles: updatedRoles,
          selectedRole: event.role,
        ));
      } catch (error) {
        emit(PolicyManagerError('Failed to create role: $error', roles: currentState.roles));
      }
    }
  }

  void _onDeleteRole(PolicyManagerDeleteRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      emit(PolicyManagerLoading(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
      ));
      
      try {
        // TODO: Implement role deletion functionality in repository
        // await _roleRepository.deleteRole(event.roleId);
        
        // Remove the role from the roles list
        final updatedRoles = currentState.roles.where((role) => role.id != event.roleId).toList();
        
        // Clear selected role if it was the one being deleted
        final selectedRole = currentState.selectedRole?.id == event.roleId 
            ? null 
            : currentState.selectedRole;
        
        emit(PolicyManagerLoaded(
          roles: updatedRoles,
          selectedRole: selectedRole,
        ));
      } catch (error) {
        emit(PolicyManagerError('Failed to delete role: $error', roles: currentState.roles));
      }
    }
  }

  void _onUpdateRole(PolicyManagerUpdateRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      emit(PolicyManagerLoading(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
      ));
      
      try {
        // TODO: Implement role update functionality in repository
        // await _roleRepository.updateRole(event.role);
        
        // Update the roles list with the updated role
        final updatedRoles = currentState.roles.map((role) {
          if (role.id == event.role.id) {
            return event.role;
          }
          return role;
        }).toList();
        
        emit(PolicyManagerLoaded(
          roles: updatedRoles,
          selectedRole: event.role,
        ));
      } catch (error) {
        emit(PolicyManagerError('Failed to update role: $error', roles: currentState.roles));
      }
    }
  }

  void _onCancelEdit(PolicyManagerCancelEdit event, Emitter<PolicyManagerState> emit) {
    // This can be used to revert any unsaved changes
    // For now, we'll just maintain the current state
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith());
    }
  }
}