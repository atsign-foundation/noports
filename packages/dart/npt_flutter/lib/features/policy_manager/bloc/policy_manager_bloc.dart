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
    on<PolicyManagerShowLogs>(_onShowLogs);
    on<PolicyManagerShowRoles>(_onShowRoles);
  }

  void _onInitial(PolicyManagerInitialEvent event, Emitter<PolicyManagerState> emit) {
    emit(PolicyManagerInitial());
  }

  void _onLoadingRoles(PolicyManagerLoadingRoles event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading());
    final roles = await _roleRepository.fetchRoles();
    emit(PolicyManagerRoleLoaded(roles: roles, isEditing: false));
  }

  void _onRoleSelected(PolicyManagerRoleSelected event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      if (currentState.isEditing) {
        return;
      }
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == event.roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: selectedRole, isEditing: false));
    } else if (state is PolicyManagerViewLogsPageLoaded) {
      final currentState = state as PolicyManagerViewLogsPageLoaded;
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == event.roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: selectedRole, isEditing: false));
    }
  }

  void _onRoleDeselected(PolicyManagerRoleDeselected event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, isEditing: false));
    }
  }

  void _onStartEditing(PolicyManagerStartEditing event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      final selectedRole = currentState.roles.isNotEmpty
          ? currentState.roles.firstWhere(
              (role) => role.id == event.roleId,
              orElse: () => currentState.roles.first,
            )
          : null;
      
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: selectedRole, isEditing: true));
    }
  }

  void _onStopEditing(PolicyManagerStopEditing event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: currentState.selectedRole, isEditing: false));
    }
  }

  void _onSaveRole(PolicyManagerSaveRole event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading());
    
    try {
      bool success = await _roleRepository.updateExistingRole(event.role);
      
      if (success) {
        final updatedRoles = await _roleRepository.fetchRoles();
        emit(PolicyManagerRoleLoaded(
          roles: updatedRoles,
          selectedRole: event.role,
          isEditing: false,
        ));
      } else {
        emit(const PolicyManagerError('Failed to save role'));
      }
    } catch (error) {
      emit(PolicyManagerError('Failed to save role: $error'));
    }
  }

  void _onCreateRole(PolicyManagerCreateRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      
      // Optimistically add the new role to the local state immediately
      final optimisticRole = Role(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: event.role.name,
        description: event.role.description,
        daemonAtSigns: event.role.daemonAtSigns,
        devices: event.role.devices,
        deviceGroups: event.role.deviceGroups,
        userAtSigns: event.role.userAtSigns,
      );
      final updatedRolesLocal = [...currentState.roles, optimisticRole];
      
      // Show the new role immediately (optimistic update)
      emit(PolicyManagerRoleLoaded(roles: updatedRolesLocal, selectedRole: optimisticRole, isEditing: false));
      
      try {
        bool success = await _roleRepository.createNewRole(event.role);
        
        if (success) {
          // Fetch updated roles from server to get correct IDs and sync state
          final updatedRoles = await _roleRepository.fetchRoles();
          final createdRole = updatedRoles.firstWhere(
            (role) => role.name == event.role.name && role.description == event.role.description,
            orElse: () => event.role,
          );
          emit(PolicyManagerRoleLoaded(
            roles: updatedRoles,
            selectedRole: createdRole,
            isEditing: false,
          ));
        } else {
          // Revert to original state on failure and show error
          emit(const PolicyManagerError('Failed to create role'));
          // Immediately restore the loaded state with original roles
          emit(PolicyManagerRoleLoaded(
            roles: currentState.roles,
            selectedRole: null,
            isEditing: false,
          ));
        }
      } catch (error) {
        // Revert to original state on error and show error
        emit(PolicyManagerError('Failed to create role: $error'));
        // Immediately restore the loaded state with original roles
        emit(PolicyManagerRoleLoaded(
          roles: currentState.roles,
          selectedRole: null,
          isEditing: false,
        ));
      }
    }
  }

  void _onDeleteRole(PolicyManagerDeleteRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      
      // Immediately remove the role from the local state for better UX
      final updatedRolesLocal = currentState.roles.where((role) => role.id != event.roleId).toList();
      
      // Show the updated list immediately (optimistic update)
      emit(PolicyManagerRoleLoaded(roles: updatedRolesLocal, selectedRole: null, isEditing: false));
      
      try {
        bool success = await _roleRepository.deleteRole(event.roleId);
        
        if (success) {
          // Confirm deletion was successful by fetching from server
          final updatedRoles = await _roleRepository.fetchRoles();
          emit(PolicyManagerRoleLoaded(roles: updatedRoles, selectedRole: null, isEditing: false));
        } else {
          // Revert to original state on failure and show error
          emit(const PolicyManagerError('Failed to delete role'));
          // Immediately restore the loaded state with original roles
          emit(PolicyManagerRoleLoaded(
            roles: currentState.roles,
            selectedRole: currentState.selectedRole,
            isEditing: false,
          ));
        }
      } catch (error) {
        // Revert to original state on error and show error  
        emit(PolicyManagerError('Failed to delete role: $error'));
        // Immediately restore the loaded state with original roles
        emit(PolicyManagerRoleLoaded(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
          isEditing: false,
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
        emit(PolicyManagerRoleLoaded(
          roles: updatedRoles,
          selectedRole: event.role,
          isEditing: false,
        ));
      } else {
        emit(const PolicyManagerError('Failed to update role'));
      }
    } catch (error) {
      emit(PolicyManagerError('Failed to update role: $error'));
    }
  }

  void _onCancelEdit(PolicyManagerCancelEdit event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerRoleLoaded(roles: currentState.roles, selectedRole: currentState.selectedRole, isEditing: false));
    }
  }

  void _onStartNewRole(PolicyManagerStartNewRole event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      // Create an empty role for editing without server call
      final emptyRole = Role.empty(name: '');
      emit(PolicyManagerRoleLoaded(
        roles: currentState.roles,
        selectedRole: emptyRole,
        isEditing: true,
      ));
    }
  }

  void _onShowLogs(PolicyManagerShowLogs event, Emitter<PolicyManagerState> emit) async {
    if (state is PolicyManagerRoleLoaded) {
      final currentState = state as PolicyManagerRoleLoaded;
      emit(PolicyManagerViewLogsPageLoaded(
        roles: currentState.roles,
        selectedRole: null, // Clear selected role when switching to logs
      ));
    } else if (state is PolicyManagerViewLogsPageLoaded) {
      // Already in logs view, do nothing
      return;
    } else if (state is PolicyManagerLoading && (state as PolicyManagerLoading).roles != null) {
      // If we're in loading state but have roles cached, use them
      final currentState = state as PolicyManagerLoading;
      emit(PolicyManagerViewLogsPageLoaded(
        roles: currentState.roles!,
        selectedRole: null,
      ));
    } else {
      // Load roles first, then switch to logs view
      final roles = await _roleRepository.fetchRoles();
      emit(PolicyManagerViewLogsPageLoaded(
        roles: roles,
        selectedRole: null,
      ));
    }
  }

  void _onShowRoles(PolicyManagerShowRoles event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerViewLogsPageLoaded) {
      final currentState = state as PolicyManagerViewLogsPageLoaded;
      emit(PolicyManagerRoleLoaded(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
        isEditing: false,
      ));
    } else if (state is PolicyManagerRoleLoaded) {
      // Already in roles view, do nothing
      return;
    }
  }
}