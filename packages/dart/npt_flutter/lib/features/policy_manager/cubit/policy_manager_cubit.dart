import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/policy.dart';
import '../shared/utils/policy_utils.dart';
import 'policy_manager_state.dart';

class PolicyManagerCubit extends Cubit<PolicyManagerState> {
  PolicyManagerCubit() : super(PolicyManagerInitial()) {
    _initialize();
  }

  void _initialize() {
    emit(const PolicyManagerLoaded(roles: []));
  }

  void addRole(String name) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final newRole = PolicyUtils.createNewRole(name);
      final updatedRoles = [...currentState.roles, newRole];
      emit(currentState.copyWith(
        roles: updatedRoles,
        selectedRole: newRole,
      ));
    }
  }

  void deleteRole(Role role) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final updatedRoles = PolicyUtils.removeRoleFromList(currentState.roles, role);
      final clearSelected = currentState.selectedRole == role;
      emit(currentState.copyWith(
        roles: updatedRoles,
        clearSelectedRole: clearSelected,
      ));
    }
  }

  void selectRole(Role role) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(selectedRole: role));
    } else if (state is PolicyManagerLoading) {
      final currentState = state as PolicyManagerLoading;
      emit(PolicyManagerLoading(
        roles: currentState.roles,
        selectedRole: role,
      ));
    }
  }

  void clearSelection() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(clearSelectedRole: true));
    } else if (state is PolicyManagerLoading) {
      final currentState = state as PolicyManagerLoading;
      emit(PolicyManagerLoading(
        roles: currentState.roles,
        selectedRole: null,
      ));
    }
  }

  void updateSelectedRole(Role updatedRole) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final updatedRoles = PolicyUtils.updateRoleInList(currentState.roles, updatedRole);
      emit(currentState.copyWith(
        roles: updatedRoles,
        selectedRole: updatedRole,
      ));
    }
  }

  void updateRoleName(String name) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.selectedRole;
      if (selectedRole != null) {
        final updatedRole = PolicyUtils.copyRoleWithName(selectedRole, name);
        updateSelectedRole(updatedRole);
      }
    }
  }

  void updateRoleDescription(String description) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.selectedRole;
      if (selectedRole != null) {
        final updatedRole = PolicyUtils.copyRoleWithDescription(selectedRole, description);
        updateSelectedRole(updatedRole);
      }
    }
  }

  void updateDeviceAtSigns(List<String> deviceAtSigns) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.selectedRole;
      if (selectedRole != null) {
        final updatedRole = PolicyUtils.copyRoleWithDeviceAtSigns(selectedRole, deviceAtSigns);
        updateSelectedRole(updatedRole);
      }
    }
  }

  void updateDeviceNames(List<String> deviceNames) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.selectedRole;
      if (selectedRole != null) {
        final updatedRole = PolicyUtils.copyRoleWithDeviceNames(selectedRole, deviceNames);
        updateSelectedRole(updatedRole);
      }
    }
  }

  void updateDeviceGroups(List<String> deviceGroups) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.selectedRole;
      if (selectedRole != null) {
        final updatedRole = PolicyUtils.copyRoleWithDeviceGroups(selectedRole, deviceGroups);
        updateSelectedRole(updatedRole);
      }
    }
  }

  void updateUserAtSigns(List<String> userAtSigns) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.selectedRole;
      if (selectedRole != null) {
        final updatedRole = PolicyUtils.copyRoleWithUserAtSigns(selectedRole, userAtSigns);
        updateSelectedRole(updatedRole);
      }
    }
  }

  void loadRoles(List<Role> roles) {
    emit(PolicyManagerLoaded(roles: roles));
  }

  void refreshRoles() {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(PolicyManagerLoading(
        roles: currentState.roles,
        selectedRole: currentState.selectedRole,
      ));
      
      // Simulate loading delay
      Future.delayed(const Duration(milliseconds: 300), () {
        emit(PolicyManagerLoaded(
          roles: currentState.roles,
          selectedRole: currentState.selectedRole,
        ));
      });
    }
  }

  void saveRole() {
    // TODO: Implement actual save logic to database/API
    // For now, we'll just emit a success message
    if (state is PolicyManagerLoaded) {
      // This would typically involve calling a repository to save the role
      // emit(PolicyManagerSaved());
    }
  }

  // Convenience getters
  List<Role> get roles {
    if (state is PolicyManagerLoaded) {
      return (state as PolicyManagerLoaded).roles;
    } else if (state is PolicyManagerLoading) {
      return (state as PolicyManagerLoading).roles;
    }
    return [];
  }

  Role? get selectedRole {
    if (state is PolicyManagerLoaded) {
      return (state as PolicyManagerLoaded).selectedRole;
    } else if (state is PolicyManagerLoading) {
      return (state as PolicyManagerLoading).selectedRole;
    }
    return null;
  }
}