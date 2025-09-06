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

  void initializeFormNew() {
    emit(const PolicyFormLoading(operation: 'Initializing new role form'));
    final roleInProgress = RoleInProgress.empty();
    emit(PolicyFormEditingNewRole(roleInProgress: roleInProgress));
  }

  Future<void> initializeFormExisting(String roleId) async {
    final backupState = state;
    emit(const PolicyFormLoading(operation: 'Loading existing role'));
    try {
      final roles = await _roleRepository.fetchRoles();
      if (isClosed) return;

      final FetchedRole existingRole = roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => throw Exception('Role not found'),
      );

      if (isClosed) return;
      emit(PolicyFormEditingExistingRole(currentRole: existingRole));
    } catch (error) {
      if (isClosed) return;
      emit(
        PolicyFormError(
          message: 'Failed to load role: $error',
          previousState: backupState,
        ),
      );
    }
  }

  void initializeWithRole(RoleInProgress role, {bool isEditingMode = false}) {
    if (role is FetchedRole) {
      if (isEditingMode) { // we want to edit an existing role
        emit(PolicyFormEditingExistingRole(
          currentRole: role,
          originalRole: role,
        ));
      } else {
        // Viewing mode - emit a read-only state
        emit(PolicyFormViewingRole(currentRole: role));
      }
    } else {
      // For new roles, always in editing mode
      emit(PolicyFormEditingNewRole(roleInProgress: role));
    }
  }

  void startEditingExistingRole(String roleId) {
    initializeFormExisting(roleId);
  }

  /// Elegant method to update the entire role - similar to ProfileBloc's _onEdit
  void updateRole(RoleInProgress role) {
    if (state is PolicyFormEditingExistingRole && role is FetchedRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      emit(currentState.copyWith(currentRole: role));
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      emit(currentState.copyWith(roleInProgress: role));
    }
  }

  /// Helper to get the current role being edited
  RoleInProgress? _getCurrentRole() {
    if (state is PolicyFormEditingExistingRole) {
      return (state as PolicyFormEditingExistingRole).currentRole;
    } else if (state is PolicyFormEditingNewRole) {
      return (state as PolicyFormEditingNewRole).roleInProgress;
    }
    return null;
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
        
        if (isClosed) return;

        if (success) {
          onSuccess?.call('Role saved successfully');
          if (!isClosed) {
            emit(const PolicyFormLoading());
          }
        } else {
          if (!isClosed) {
            emit(
              PolicyFormError(
                message: 'Failed to save role',
                previousState: currentState.copyWith(isSaving: false),
              ),
            );
          }
        }
      } catch (error) {
        if (!isClosed) {
          emit(
            PolicyFormError(
              message: 'Failed to save role: $error',
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      }
    } else if( state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      emit(currentState.copyWith(isSaving: true));

      try {
        final success = await _roleRepository.putNewRole(currentState.roleInProgress);
        
        if (isClosed) return;

        if (success) {
          onSuccess?.call('Role created successfully');
          if (!isClosed) {
            emit(const PolicyFormLoading());
          }
        } else {
          if (!isClosed) {
            emit(
              PolicyFormError(
                message: 'Failed to create role',
                previousState: currentState.copyWith(isSaving: false),
              ),
            );
          }
        }
      } catch (error) {
        if (!isClosed) {
          emit(
            PolicyFormError(
              message: 'Failed to create role: $error',
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
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
        
        // Check if cubit is still active after async operation
        if (isClosed) return;

        if (success) {
          onDeleted?.call();
          if (!isClosed) {
            emit(const PolicyFormLoading());
          }
        } else {
          if (!isClosed) {
            emit(
              PolicyFormError(
                message: 'Failed to delete role',
                previousState: currentState.copyWith(isSaving: false),
              ),
            );
          }
        }
      } catch (error) {
        if (!isClosed) {
          emit(
            PolicyFormError(
              message: 'Failed to delete role: $error',
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      }
    }
  }

  void recoverFromError() {
    if (state is PolicyFormError) {
      final errorState = state as PolicyFormError;
      emit(errorState.previousState ?? const PolicyFormError(message: 'Could not load previous state error'));
    }
  }

  /// Update Fields ---------------------------
  void updateName(String name) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(name: name));
    }
  }

  void updateDescription(String description) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(description: description));
    }
  }

  void updateDaemonAtSigns(List<String> daemonAtSigns) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(daemonAtSigns: daemonAtSigns));
    }
  }

  void updateDevices(List<Device> devices) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(devices: devices));
    }
  }

  void updateDeviceGroups(List<DeviceGroup> deviceGroups) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(deviceGroups: deviceGroups));
    }
  }

  void updateUserAtSigns(List<String> userAtSigns) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(userAtSigns: userAtSigns));
    }
  }

}
