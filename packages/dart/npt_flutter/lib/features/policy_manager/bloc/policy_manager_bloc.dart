import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/role_repository.dart';
import '../models/policy.dart';
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
    on<PolicyManagerStartNewRole>(_onStartNewRole);
  }

  void _onInitial(PolicyManagerInitialEvent event, Emitter<PolicyManagerState> emit) {
    emit(PolicyManagerInitial());
  }

  void _onLoadingRoles(PolicyManagerLoadingRoles event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading());
    
    try {
      final roles = await _roleRepository.fetchRoles();
      emit(PolicyManagerLoaded(roles: roles));
    } catch (error) {
      emit(PolicyManagerError('Failed to load roles: $error'));
    }
  }

  void _onRoleSelected(PolicyManagerRoleSelected event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == event.roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      
      emit(PolicyManagerLoaded(roles: currentState.roles, selectedRole: selectedRole));
    }
  }

  void _onRoleDeselected(PolicyManagerRoleDeselected event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(PolicyManagerLoaded(roles: currentState.roles));
    }
  }

  void _onStartEditing(PolicyManagerStartEditing event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == event.roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      
      emit(PolicyManagerLoaded(roles: currentState.roles, selectedRole: selectedRole));
    }
  }

  void _onStopEditing(PolicyManagerStopEditing event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(PolicyManagerLoaded(roles: currentState.roles));
    }
  }

  void _onSaveRole(PolicyManagerSaveRole event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading());
    
    try {
      bool success = await _roleRepository.updateExistingRole(event.role);
      
      if (success) {
        final updatedRoles = await _roleRepository.fetchRoles();
        emit(PolicyManagerLoaded(
          roles: updatedRoles,
          selectedRole: event.role,
        ));
      } else {
        emit(const PolicyManagerError('Failed to save role'));
      }
    } catch (error) {
      emit(PolicyManagerError('Failed to save role: $error'));
    }
  }

  void _onCreateRole(PolicyManagerCreateRole event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading());
    
    try {
      bool success = await _roleRepository.createNewRole(event.role);
      
      if (success) {
        // Fetch updated roles after successful creation
        final updatedRoles = await _roleRepository.fetchRoles();
        final createdRole = updatedRoles.firstWhere(
          (role) => role.name == event.role.name && role.description == event.role.description,
          orElse: () => event.role,
        );
        emit(PolicyManagerLoaded(
          roles: updatedRoles,
          selectedRole: createdRole,
        ));
      } else {
        emit(const PolicyManagerError('Failed to create role'));
      }
    } catch (error) {
      emit(PolicyManagerError('Failed to create role: $error'));
    }
  }

  void _onDeleteRole(PolicyManagerDeleteRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      // Keep roles visible during deletion by passing them to loading state
      emit(PolicyManagerLoading(selectedRole: currentState.selectedRole, roles: currentState.roles));
      
      try {
        bool success = await _roleRepository.deleteRole(event.roleId);
        
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          // Clear selectedRole since the role was deleted
          emit(PolicyManagerLoaded(roles: updatedRoles, selectedRole: null));
        } else {
          // Preserve current roles on failure and show error
          emit(const PolicyManagerError('Failed to delete role'));
          // Immediately restore the loaded state with current roles
          emit(PolicyManagerLoaded(
            roles: currentState.roles,
            selectedRole: currentState.selectedRole,
          ));
        }
      } catch (error) {
        // Preserve current roles on error and show error
        emit(PolicyManagerError('Failed to delete role: $error'));
        // Immediately restore the loaded state with current roles
        emit(PolicyManagerLoaded(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
        ));
      }
    }
  }

  void _onUpdateRole(PolicyManagerUpdateRole event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading());
    
    try {
      bool success = await _roleRepository.updateExistingRole(event.role);
      
      if (success) {
        final updatedRoles = await _roleRepository.fetchRoles();
        emit(PolicyManagerLoaded(
          roles: updatedRoles,
          selectedRole: event.role,
        ));
      } else {
        emit(const PolicyManagerError('Failed to update role'));
      }
    } catch (error) {
      emit(PolicyManagerError('Failed to update role: $error'));
    }
  }

  void _onCancelEdit(PolicyManagerCancelEdit event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(PolicyManagerLoaded(roles: currentState.roles));
    }
  }

  void _onStartNewRole(PolicyManagerStartNewRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      // Create an empty role for editing without server call
      final emptyRole = Role.empty(name: '');
      emit(PolicyManagerLoaded(
        roles: currentState.roles,
        selectedRole: emptyRole,
      ));
    }
  }
}