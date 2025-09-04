import '../../logging/models/loggable.dart';
import '../../logging/models/logging_bloc.dart';
import '../../policy/models/policy.dart';
import '../../policy/repositories/role_repository.dart';

part 'policy_form_state.dart';

class PolicyFormCubit extends LoggingCubit<PolicyFormState> {
  final RoleRepository _roleRepository;
  final void Function(String message)? onSuccess;
  final void Function()? onDeleted;

  PolicyFormCubit(
    this._roleRepository, {
    this.onSuccess,
    this.onDeleted,
  }) : super(const PolicyFormLoading());

  void _updateCurrentRole(Role updatedRole) {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      switch (currentState) {
        case PolicyFormEditingNew():
          emit(currentState.copyWith(currentRole: updatedRole));
        case PolicyFormEditingExisting():
          emit(currentState.copyWith(currentRole: updatedRole));
      }
    }
  }

  Future<void> initializeForm({Role? role}) async {
    if (role != null && role.id.isNotEmpty) {
      emit(PolicyFormEditingExisting(
        currentRole: role,
        originalRole: role,
        isSaving: false,
      ));
    } else {
      final int maxGroupId = await _roleRepository.getMaxGroupId();
      const String defaultName = '';
      final int newId = maxGroupId + 1;
      final emptyRole = Role.empty(id: newId.toString(), name: defaultName);
      emit(PolicyFormEditingNew(
        currentRole: emptyRole,
        isSaving: false,
      ));
    }
  }

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
      _updateCurrentRole(updatedRole);
    }
  }

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
      _updateCurrentRole(updatedRole);
    }
  }

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
      _updateCurrentRole(updatedRole);
    }
  }

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
      _updateCurrentRole(updatedRole);
    }
  }

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
      _updateCurrentRole(updatedRole);
    }
  }

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
      _updateCurrentRole(updatedRole);
    }
  }

  void cancelEditing() {
    if (state is PolicyFormEditingExisting) {
      final currentState = state as PolicyFormEditingExisting;
      emit(currentState.copyWith(
        currentRole: currentState.originalRole,
        isSaving: false,
      ));
    } else if (state is PolicyFormEditingNew) {
      final currentState = state as PolicyFormEditingNew;
      final emptyRole = Role.empty(id: '', name: '');
      emit(currentState.copyWith(
        currentRole: emptyRole,
        isSaving: false,
      ));
    }
  }

  Future<void> saveRole() async {
    if (state is PolicyFormEditing) {
      final currentState = state as PolicyFormEditing;
      
      switch (currentState) {
        case PolicyFormEditingNew():
          final editingState = currentState;
          emit(editingState.copyWith(isSaving: true));
          
          try {
            // For new roles, we already have the ID from initializeForm
            final success = await _roleRepository.updateRole(editingState.currentRole);
            if (success) {
              // Notify success
              onSuccess?.call('Role created successfully!');
              // Reset to loading state after successful save
              reset();
            } else {
              emit(PolicyFormError(
                message: 'Failed to save role',
                previousState: editingState.copyWith(isSaving: false),
              ));
            }
          } catch (error) {
            emit(PolicyFormError(
              message: 'Failed to save role: $error',
              previousState: editingState.copyWith(isSaving: false),
            ));
          }
          
        case PolicyFormEditingExisting():
          final editingState = currentState;
          emit(editingState.copyWith(isSaving: true));
          
          try {
            final success = await _roleRepository.updateRole(editingState.currentRole);
            if (success) {
              // Notify success
              onSuccess?.call('Role updated successfully!');
              // Reset to loading state after successful save
              reset();
            } else {
              emit(PolicyFormError(
                message: 'Failed to save role',
                previousState: editingState.copyWith(isSaving: false),
              ));
            }
          } catch (error) {
            emit(PolicyFormError(
              message: 'Failed to save role: $error',
              previousState: editingState.copyWith(isSaving: false),
            ));
          }
      }
    }
  }

  Future<void> deleteRole() async {
    if (state is PolicyFormEditingExisting) {
      final currentState = state as PolicyFormEditingExisting;
      
      final roleId = currentState.currentRole.id;
      if (roleId.isEmpty) return;

      emit(currentState.copyWith(isSaving: true));

      try {
        final success = await _roleRepository.deleteRole(roleId);
        
        if (success) {
          // Notify deletion
          onDeleted?.call();
          // Reset to loading state after successful delete
          reset();
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

  void recoverFromError() {
    if (state is PolicyFormError) {
      final errorState = state as PolicyFormError;
      emit(errorState.previousState);
    }
  }

  void reset() {
    emit(const PolicyFormLoading());
  }
}