import '../../logging/models/loggable.dart';
import '../../logging/models/logging_bloc.dart';
import '../../policy/models/policy.dart';
import '../../policy/repositories/role_repository.dart';

part 'policy_form_state.dart';

class PolicyFormCubit extends LoggingCubit<PolicyFormState> {
  final RoleRepository _roleRepository;
  final void Function(String message)? onSuccess;
  final void Function()? onDeleted;

  PolicyFormCubit(this._roleRepository, {this.onSuccess, this.onDeleted})
    : super(const PolicyFormLoading());

  void initializeFormNew() async {
    emit(const PolicyFormLoading(operation: 'Initializing new role form'));
    final roleInProgress = RoleInProgress.empty();
    emit(PolicyFormEditingNewRole(roleInProgress: roleInProgress));
  }

  Future<void> initializeFormExisting(String roleId) async {
    final backupState = state;
    emit(const PolicyFormLoading(operation: 'Loading existing role'));
    try {
      final roles = await _roleRepository.fetchRoles();
      final FetchedRole existingRole = roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => throw Exception('Role not found'),
      );
      emit(PolicyFormEditingExistingRole(currentRole: existingRole));
    } catch (error) {
      emit(
        PolicyFormError(
          message: 'Failed to load role: $error',
          previousState: backupState,
        ),
      );
    }
  }

  /// Example: updateExistingRole((current) => current.copyWith(name: 'New Name'));
  void updateExistingRole(FetchedRole Function(FetchedRole current) updater) {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final updatedRole = updater(currentState.currentRole);
      emit(currentState.copyWith(currentRole: updatedRole));
    }
  }

  void updateRoleField<T>(
    T value,
    FetchedRole Function(FetchedRole role, T value) fieldUpdater,
  ) {
    updateExistingRole((current) => fieldUpdater(current, value));
  }

  void cancelEditing() {
    if (state is PolicyFormEditingExistingRole) {
      final PolicyFormEditingExistingRole currentState =
          state as PolicyFormEditingExistingRole;
      emit(
        currentState.copyWith(
          currentRole: currentState.originalRole
        ),
      );
    } else if (state is PolicyFormEditingNewRole) {
      final RoleInProgress emptyRole = RoleInProgress.empty();
      emit(PolicyFormEditingNewRole(roleInProgress: emptyRole));
    }
  }

  Future<void> saveRole() async {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      emit(currentState.copyWith(isSaving: true));

      try {
        final success = await _roleRepository.updateExistingRole(currentState.currentRole);

        if (success) {
          onSuccess?.call('Role saved successfully');
          emit(const PolicyFormLoading());
        } else {
          emit(
            PolicyFormError(
              message: 'Failed to save role',
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      } catch (error) {
        emit(
          PolicyFormError(
            message: 'Failed to save role: $error',
            previousState: currentState.copyWith(isSaving: false),
          ),
        );
      }
    } else if( state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      emit(currentState.copyWith(isSaving: true));

      try {
        final success = await _roleRepository.putNewRole(currentState.roleInProgress);

        if (success) {
          onSuccess?.call('Role created successfully');
          emit(const PolicyFormLoading());
        } else {
          emit(
            PolicyFormError(
              message: 'Failed to create role',
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      } catch (error) {
        emit(
          PolicyFormError(
            message: 'Failed to create role: $error',
            previousState: currentState.copyWith(isSaving: false),
          ),
        );
      }
    }
  }

  Future<void> deleteCurrentRole() async {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final roleId = currentState.currentRole.id;

      emit(currentState.copyWith(isSaving: true));

      try {
        final success = await _roleRepository.deleteRole(roleId);

        if (success) {
          onDeleted?.call();
          emit(const PolicyFormLoading());
        } else {
          emit(
            PolicyFormError(
              message: 'Failed to delete role',
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      } catch (error) {
        emit(
          PolicyFormError(
            message: 'Failed to delete role: $error',
            previousState: currentState.copyWith(isSaving: false),
          ),
        );
      }
    }
  }

  void recoverFromError() {
    if (state is PolicyFormError) {
      final errorState = state as PolicyFormError;
      emit(errorState.previousState ?? const PolicyFormError(message: 'Could not load previous state error'));
    }
  }

  // Field update methods
  void updateRoleName(String name) {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final updatedRole = FetchedRole(
        id: currentState.currentRole.id,
        name: name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      emit(currentState.copyWith(currentRole: updatedRole));
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      final updatedRole = RoleInProgress(
        tempId: currentState.roleInProgress.tempId,
        name: name,
        description: currentState.roleInProgress.description,
        daemonAtSigns: currentState.roleInProgress.daemonAtSigns,
        devices: currentState.roleInProgress.devices,
        deviceGroups: currentState.roleInProgress.deviceGroups,
        userAtSigns: currentState.roleInProgress.userAtSigns,
      );
      emit(currentState.copyWith(roleInProgress: updatedRole));
    }
  }

  void updateRoleDescription(String description) {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final updatedRole = FetchedRole(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      emit(currentState.copyWith(currentRole: updatedRole));
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      final updatedRole = RoleInProgress(
        tempId: currentState.roleInProgress.tempId,
        name: currentState.roleInProgress.name,
        description: description,
        daemonAtSigns: currentState.roleInProgress.daemonAtSigns,
        devices: currentState.roleInProgress.devices,
        deviceGroups: currentState.roleInProgress.deviceGroups,
        userAtSigns: currentState.roleInProgress.userAtSigns,
      );
      emit(currentState.copyWith(roleInProgress: updatedRole));
    }
  }

  void updateDaemonAtSigns(List<String> daemonAtSigns) {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final updatedRole = FetchedRole(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      emit(currentState.copyWith(currentRole: updatedRole));
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      final updatedRole = RoleInProgress(
        tempId: currentState.roleInProgress.tempId,
        name: currentState.roleInProgress.name,
        description: currentState.roleInProgress.description,
        daemonAtSigns: daemonAtSigns,
        devices: currentState.roleInProgress.devices,
        deviceGroups: currentState.roleInProgress.deviceGroups,
        userAtSigns: currentState.roleInProgress.userAtSigns,
      );
      emit(currentState.copyWith(roleInProgress: updatedRole));
    }
  }

  void updateDevices(List<Device> devices) {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final updatedRole = FetchedRole(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      emit(currentState.copyWith(currentRole: updatedRole));
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      final updatedRole = RoleInProgress(
        tempId: currentState.roleInProgress.tempId,
        name: currentState.roleInProgress.name,
        description: currentState.roleInProgress.description,
        daemonAtSigns: currentState.roleInProgress.daemonAtSigns,
        devices: devices,
        deviceGroups: currentState.roleInProgress.deviceGroups,
        userAtSigns: currentState.roleInProgress.userAtSigns,
      );
      emit(currentState.copyWith(roleInProgress: updatedRole));
    }
  }

  void updateDeviceGroups(List<DeviceGroup> deviceGroups) {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final updatedRole = FetchedRole(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: deviceGroups,
        userAtSigns: currentState.currentRole.userAtSigns,
      );
      emit(currentState.copyWith(currentRole: updatedRole));
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      final updatedRole = RoleInProgress(
        tempId: currentState.roleInProgress.tempId,
        name: currentState.roleInProgress.name,
        description: currentState.roleInProgress.description,
        daemonAtSigns: currentState.roleInProgress.daemonAtSigns,
        devices: currentState.roleInProgress.devices,
        deviceGroups: deviceGroups,
        userAtSigns: currentState.roleInProgress.userAtSigns,
      );
      emit(currentState.copyWith(roleInProgress: updatedRole));
    }
  }

  void updateUserAtSigns(List<String> userAtSigns) {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      final updatedRole = FetchedRole(
        id: currentState.currentRole.id,
        name: currentState.currentRole.name,
        description: currentState.currentRole.description,
        daemonAtSigns: currentState.currentRole.daemonAtSigns,
        devices: currentState.currentRole.devices,
        deviceGroups: currentState.currentRole.deviceGroups,
        userAtSigns: userAtSigns,
      );
      emit(currentState.copyWith(currentRole: updatedRole));
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      final updatedRole = RoleInProgress(
        tempId: currentState.roleInProgress.tempId,
        name: currentState.roleInProgress.name,
        description: currentState.roleInProgress.description,
        daemonAtSigns: currentState.roleInProgress.daemonAtSigns,
        devices: currentState.roleInProgress.devices,
        deviceGroups: currentState.roleInProgress.deviceGroups,
        userAtSigns: userAtSigns,
      );
      emit(currentState.copyWith(roleInProgress: updatedRole));
    }
  }
}
