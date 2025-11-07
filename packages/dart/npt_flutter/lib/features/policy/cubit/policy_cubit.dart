import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../models/policy.dart';
import '../repositories/role_repository.dart';

part 'policy_state.dart';

class PolicyCubit extends LoggingCubit<PolicyState> {
  final RoleRepository _roleRepository;

  PolicyCubit(this._roleRepository) : super(const PolicyInitial());

  Future<void> loadRoles(AppLocalizations strings) async {
    emit(const PolicyLoading(operation: 'loading roles'));
    try {
      final List<FetchedRole> roles = await _roleRepository.fetchRoles();
      emit(PolicyBrowsingRoles(roles: roles));
    } catch (e) {
      emit(
        PolicyError(
          strings.rolesLoadingFailedWithDetails(e.toString()),
          operation: 'loadRoles',
        ),
      );
    }
  }

  Future<void> reloadAndSelectRole(String roleId, AppLocalizations strings) async {
    emit(const PolicyLoading(operation: 'reloading roles'));
    try {
      final List<FetchedRole> roles = await _roleRepository.fetchRoles();
      final selectedRole = roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => roles.isNotEmpty ? roles.first : throw Exception('No roles found'),
      );
      emit(PolicyViewingRole(roles: roles, selectedRole: selectedRole));
    } catch (e) {
      emit(
        PolicyError(
          strings.rolesLoadingFailedWithDetails(e.toString()),
          operation: 'reloadAndSelectRole',
        ),
      );
    }
  }

  Future<void> updateExistingRole(
    FetchedRole role,
    AppLocalizations strings,
  ) async {
    if (state is PolicyEditingRole) {
      final currentState = state as PolicyEditingRole;
      emit(const PolicyLoading(operation: 'Updating role'));
      try {
        final success = await _roleRepository.updateExistingRole(role);
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          final updatedRole = updatedRoles.firstWhere(
            (r) => r.id == role.id,
            orElse: () => role,
          );

          emit(
            PolicyViewingRole(roles: updatedRoles, selectedRole: updatedRole),
          );
        } else {
          emit(
            PolicyError(
              strings.roleUpdatingFailed,
              operation: 'updateRole',
              previousState: currentState,
            ),
          );
        }
      } catch (error) {
        emit(
          PolicyError(
            strings.roleUpdatingFailedWithDetails(error.toString()),
            operation: 'updateRole',
            previousState: currentState,
          ),
        );
      }
    }
  }

  Future<void> deleteRole(String roleId, AppLocalizations strings) async {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;

      emit(const PolicyLoading(operation: 'Deleting role'));

      try {
        final success = await _roleRepository.deleteRole(roleId);
        if (success) {
          final updatedRoles = await _roleRepository.fetchRoles();
          emit(PolicyBrowsingRoles(roles: updatedRoles));
        } else {
          emit(
            PolicyError(
              strings.roleDeletingFailed,
              operation: 'deleteRole',
              previousState: currentState,
            ),
          );
        }
      } catch (error) {
        emit(
          PolicyError(
            strings.roleDeletingFailedWithDetails(error.toString()),
            operation: 'deleteRole',
            previousState: currentState,
          ),
        );
      }
    }
  }

  void selectRoleForViewing(String roleId) {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      if (state is PolicyEditingRole || state is PolicyCreatingRole) {
        return;
      }
      if (state is PolicyViewingRole &&
          (state as PolicyViewingRole).selectedRole.id == roleId) {
        return;
      }
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(
        PolicyViewingRole(
          roles: currentState.roles,
          selectedRole: selectedRole,
        ),
      );
    }
  }

  void startEditingRole(String roleId) {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      final roleToEdit = currentState.roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => currentState.roles.first,
      );
      emit(
        PolicyEditingRole(roles: currentState.roles, selectedRole: roleToEdit),
      );
    }
  }

  void startCreatingRole() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      emit(PolicyCreatingRole(roles: currentState.roles));
    }
  }

  void cancelEditing() {
    if (state is PolicyCreatingRole) {
      final currentState = state as PolicyCreatingRole;
      emit(PolicyBrowsingRoles(roles: currentState.roles));
    } else if (state is PolicyEditingRole) {
      final currentState = state as PolicyEditingRole;
      emit(
        PolicyViewingRole(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
        ),
      );
    }
  }

  void exitViewing() {
    if (state is PolicyViewingRole) {
      final currentState = state as PolicyViewingRole;
      emit(PolicyBrowsingRoles(roles: currentState.roles));
    }
  }

  void showLogs() {
    if (state is PolicyLoaded) {
      final currentState = state as PolicyLoaded;
      emit(PolicyViewingLogs(roles: currentState.roles));
    }
  }

  void showRoles() {
    if (state is PolicyViewingLogs) {
      final currentState = state as PolicyViewingLogs;
      emit(PolicyBrowsingRoles(roles: currentState.roles));
    }
  }

  void recoverFromError(AppLocalizations strings) {
    if (state is PolicyError) {
      final errorState = state as PolicyError;
      final recoverableState = errorState.recoverableState;

      if (recoverableState != null) {
        emit(recoverableState);
      } else {
        loadRoles(strings);
      }
    }
  }
}
