import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../logging/models/loggable.dart';
import '../../logging/models/logging_bloc.dart';
import '../../policy/models/policy.dart';
import '../../policy/repositories/role_repository.dart';

part 'policy_form_state.dart';

class PolicyFormCubit extends LoggingCubit<PolicyFormState> {
  final RoleRepository _roleRepository;
  final void Function(String message, String roleId)? onSuccess;
  final void Function()? onDeleted;

  PolicyFormCubit(this._roleRepository, {this.onSuccess, this.onDeleted})
    : super(const PolicyFormLoading());

  /// Used when "Add New Role" is pressed
  void initializeFormNew() {
    emit(const PolicyFormLoading(operation: 'Initializing new role form'));
    final roleInProgress = RoleInProgress.empty();
    emit(PolicyFormEditingNewRole(roleInProgress: roleInProgress));
  }

  /// Used when editing an existing role
  Future<void> initializeFormExisting(
    String roleId,
    AppLocalizations strings,
  ) async {
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
          message: strings.roleLoadingFailedWithDetails(error.toString()),
          previousState: backupState,
        ),
      );
    }
  }

  /// General initializer that decides between new or existing role
  void initializeWithRole(RoleInProgress role, {bool isEditing = false}) {
    if (role is FetchedRole) {
      if (isEditing) {
        emit(
          PolicyFormEditingExistingRole(currentRole: role, originalRole: role),
        );
      } else {
        emit(PolicyFormViewingRole(currentRole: role));
      }
    } else {
      emit(PolicyFormEditingNewRole(roleInProgress: role));
    }
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
      emit(currentState.copyWith(currentRole: currentState.originalRole));
    } else if (state is PolicyFormEditingNewRole) {
      final RoleInProgress emptyRole = RoleInProgress.empty();
      emit(PolicyFormEditingNewRole(roleInProgress: emptyRole));
    }
  }

  Future<void> saveRole(AppLocalizations strings) async {
    if (state is PolicyFormEditingExistingRole) {
      final currentState = state as PolicyFormEditingExistingRole;
      emit(currentState.copyWith(isSaving: true));

      try {
        final success = await _roleRepository.updateExistingRole(
          currentState.currentRole,
        );

        if (isClosed) return;

        if (success) {
          onSuccess?.call(
            'Role saved successfully',
            currentState.currentRole.id,
          );
          if (!isClosed) {
            emit(const PolicyFormLoading());
          }
        } else {
          if (!isClosed) {
            emit(
              PolicyFormError(
                message: strings.roleSaveFailed,
                previousState: currentState.copyWith(isSaving: false),
              ),
            );
          }
        }
      } catch (error) {
        if (!isClosed) {
          emit(
            PolicyFormError(
              message: strings.roleSaveFailedWithDetails(error.toString()),
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      }
    } else if (state is PolicyFormEditingNewRole) {
      final currentState = state as PolicyFormEditingNewRole;
      emit(currentState.copyWith(isSaving: true));

      try {
        final newRoleId = await _roleRepository.putNewRole(
          currentState.roleInProgress,
        );

        if (isClosed) return;

        if (newRoleId != null) {
          onSuccess?.call('Role created successfully', newRoleId);
          if (!isClosed) {
            emit(const PolicyFormLoading());
          }
        } else {
          if (!isClosed) {
            emit(
              PolicyFormError(
                message: strings.roleCreatingFailed,
                previousState: currentState.copyWith(isSaving: false),
              ),
            );
          }
        }
      } catch (error) {
        if (!isClosed) {
          emit(
            PolicyFormError(
              message: strings.roleCreatingFailedWithDetails(error.toString()),
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      }
    }
  }

  Future<void> deleteCurrentRole(AppLocalizations strings) async {
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
                message: strings.roleDeletingFailed,
                previousState: currentState.copyWith(isSaving: false),
              ),
            );
          }
        }
      } catch (error) {
        if (!isClosed) {
          emit(
            PolicyFormError(
              message: strings.roleDeletingFailedWithDetails(error.toString()),
              previousState: currentState.copyWith(isSaving: false),
            ),
          );
        }
      }
    }
  }

  void recoverFromError(AppLocalizations strings) {
    if (state is PolicyFormError) {
      final errorState = state as PolicyFormError;
      emit(
        errorState.previousState ??
            PolicyFormError(message: strings.couldNotLoadPreviousState),
      );
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

  void updateDaemonAtsigns(List<Atsign> daemonAtsigns) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(daemonAtsigns: daemonAtsigns));
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

  void updateUserAtsigns(List<Atsign> userAtsigns) {
    final currentRole = _getCurrentRole();
    if (currentRole != null) {
      updateRole(currentRole.copyWith(userAtsigns: userAtsigns));
    }
  }
}
