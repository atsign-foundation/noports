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
      await _roleRepository.fetchRoles();
      final roles = _roleRepository.getRoles;
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
        bool success = await _roleRepository.updateExistingRole(event.role);
        
        if (success) {
          // Get updated roles from repository
          final updatedRoles = _roleRepository.getRoles;
          
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            selectedRole: event.role,
          ));
        } else {
          emit(PolicyManagerError('Failed to save role', roles: currentState.roles));
        }
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
        bool success = await _roleRepository.createNewRole(event.role);
        
        if (success) {
          // Get updated roles from repository
          final updatedRoles = _roleRepository.getRoles;
          
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            selectedRole: event.role,
          ));
        } else {
          emit(PolicyManagerError('Failed to create role', roles: currentState.roles));
        }
      } catch (error) {
        emit(PolicyManagerError('Failed to create role: $error', roles: currentState.roles));
      }
    }
  }

  void _onDeleteRole(PolicyManagerDeleteRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      
      final optimisticRoles = currentState.roles.where((role) => role.id != event.roleId).toList();
      
      emit(PolicyManagerLoaded(
        roles: optimisticRoles,
        selectedRole: null,
      ));
      
      try {
        bool success = await _roleRepository.deleteRole(event.roleId);
        
        if (success) {
          // Refresh roles to ensure consistency with backend
          await _roleRepository.fetchRoles();
          final updatedRoles = _roleRepository.getRoles;
          
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            selectedRole: null,
          ));
        } else {
          emit(PolicyManagerError('Failed to delete role', roles: currentState.roles));
        }
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
        bool success = await _roleRepository.updateExistingRole(event.role);
        
        if (success) {
          final updatedRoles = _roleRepository.getRoles;
          
          emit(PolicyManagerLoaded(
            roles: updatedRoles,
            selectedRole: event.role,
          ));
        } else {
          emit(PolicyManagerError('Failed to update role', roles: currentState.roles));
        }
      } catch (error) {
        emit(PolicyManagerError('Failed to update role: $error', roles: currentState.roles));
      }
    }
  }

  void _onCancelEdit(PolicyManagerCancelEdit event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith());
    }
  }
}