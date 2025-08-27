import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy/models/policy.dart';
import '../../policy/repositories/role_repository.dart';

part 'policy_form_state.dart';

class PolicyFormCubit extends Cubit<PolicyFormState> {
  final RoleRepository _roleRepository;

  PolicyFormCubit(this._roleRepository) : super(const PolicyFormInitial());

  /// Initialize the form with a role (for editing) or create a new empty role
  void initializeForm({Role? role}) {
    if (role != null) {
      emit(PolicyFormEditing(
        currentRole: role,
        originalRole: role,
        isNewRole: role.id == null || role.id!.isEmpty,
        isSaving: false,
      ));
    } else {
      final emptyRole = Role.empty(name: '');
      emit(PolicyFormEditing(
        currentRole: emptyRole,
        originalRole: emptyRole,
        isNewRole: true,
        isSaving: false,
      ));
    }
  }

  /// Update the role name
  void updateRoleName(String name) {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      final updatedRole = Role(
        id: currentState.currentRole.id,
        name: name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      
      emit(currentState.copyWith(currentRole: updatedRole));
    }
  }

  /// Update the role description
  void updateRoleDescription(String description) {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      final updatedRole = Role(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      
      emit(currentState.copyWith(currentRole: updatedRole));
    }
  }

  /// Update daemon atSigns
  void updateDaemonAtSigns(List<String> daemonAtSigns) {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      final updatedRole = Role(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      
      emit(currentState.copyWith(currentRole: updatedRole));
    }
  }

  /// Update devices
  void updateDevices(List<Device> devices) {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      final updatedRole = Role(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      
      emit(currentState.copyWith(currentRole: updatedRole));
    }
  }

  /// Update device groups
  void updateDeviceGroups(List<DeviceGroup> deviceGroups) {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      final updatedRole = Role(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      
      emit(currentState.copyWith(currentRole: updatedRole));
    }
  }

  /// Update user atSigns
  void updateUserAtSigns(List<String> userAtSigns) {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      final updatedRole = Role(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: userAtSigns,
      );
      
      emit(currentState.copyWith(currentRole: updatedRole));
    }
  }

  /// Cancel editing and reset to original role
  void cancelEditing() {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      emit(currentState.copyWith(
        currentRole: currentState.originalRole,
        isSaving: false,
      ));
    }
  }

  /// Save the current role
  Future<void> saveRole() async {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      
      emit(currentState.copyWith(isSaving: true));

      try {
        bool success;
        if (currentState.isNewRole) {
          success = await _roleRepository.createNewRole(currentState.currentRole);
        } else {
          success = await _roleRepository.updateExistingRole(currentState.currentRole);
        }

        if (success) {
          emit(PolicyFormSuccess(
            savedRole: currentState.currentRole,
            wasNewRole: currentState.isNewRole,
          ));
        } else {
          emit(PolicyFormError(
            message: 'Failed to save role',
            previousState: currentState.copyWith(isSaving: false),
          ));
        }
      } catch (error) {
        emit(PolicyFormError(
          message: 'Failed to save role: $error',
          previousState: currentState.copyWith(isSaving: false),
        ));
      }
    }
  }

  /// Delete the current role
  Future<void> deleteRole() async {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      
      // Can't delete a role that hasn't been saved yet
      if (currentState.isNewRole) return;
      
      final roleId = currentState.currentRole.id;
      if (roleId == null || roleId.isEmpty) return;

      emit(currentState.copyWith(isSaving: true));

      try {
        final success = await _roleRepository.deleteRole(roleId);
        
        if (success) {
          emit(PolicyFormDeleted(deletedRole: currentState.currentRole));
        } else {
          emit(PolicyFormError(
            message: 'Failed to delete role',
            previousState: currentState.copyWith(isSaving: false),
          ));
        }
      } catch (error) {
        emit(PolicyFormError(
          message: 'Failed to delete role: $error',
          previousState: currentState.copyWith(isSaving: false),
        ));
      }
    }
  }

  /// Recover from error state
  void recoverFromError() {
    if (state is PolicyFormError) {
      final errorState = state as PolicyFormError;
      emit(errorState.previousState);
    }
  }

  /// Reset form to initial state
  void reset() {
    emit(const PolicyFormInitial());
  }
}