import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../../policy_manager/shared/utils/policy_utils.dart';
import 'policy_manager_form_state.dart';

class PolicyManagerFormCubit extends Cubit<PolicyManagerFormState> {
  PolicyManagerFormCubit() : super(PolicyManagerFormInitial());

  void loadRole(Role role) {
    emit(PolicyManagerFormLoaded(role: role));
  }

  void updateRoleName(String name) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = PolicyUtils.copyRoleWithName(currentState.role, name);
      emit(currentState.copyWith(
        role: updatedRole,
        hasUnsavedChanges: true,
      ));
    }
  }

  void updateRoleDescription(String description) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = PolicyUtils.copyRoleWithDescription(currentState.role, description);
      emit(currentState.copyWith(
        role: updatedRole,
        hasUnsavedChanges: true,
      ));
    }
  }

  void updateDeviceAtSigns(List<String> deviceAtSigns) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = PolicyUtils.copyRoleWithDeviceAtSigns(currentState.role, deviceAtSigns);
      emit(currentState.copyWith(
        role: updatedRole,
        hasUnsavedChanges: true,
      ));
    }
  }

  void updateDeviceNames(List<String> deviceNames) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = PolicyUtils.copyRoleWithDeviceNames(currentState.role, deviceNames);
      emit(currentState.copyWith(
        role: updatedRole,
        hasUnsavedChanges: true,
      ));
    }
  }

  void updateDeviceGroups(List<String> deviceGroups) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = PolicyUtils.copyRoleWithDeviceGroups(currentState.role, deviceGroups);
      emit(currentState.copyWith(
        role: updatedRole,
        hasUnsavedChanges: true,
      ));
    }
  }

  void updateUserAtSigns(List<String> userAtSigns) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = PolicyUtils.copyRoleWithUserAtSigns(currentState.role, userAtSigns);
      emit(currentState.copyWith(
        role: updatedRole,
        hasUnsavedChanges: true,
      ));
    }
  }

  Future<void> saveRole() async {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      
      emit(PolicyManagerFormSaving(currentState.role));
      
      try {
        // Simulate API call
        await Future.delayed(const Duration(milliseconds: 500));
        
        emit(PolicyManagerFormSaved(currentState.role));
        
        // Return to loaded state without unsaved changes
        emit(currentState.copyWith(hasUnsavedChanges: false));
      } catch (e) {
        emit(PolicyManagerFormError('Failed to save role: ${e.toString()}', role: currentState.role));
      }
    }
  }

  void resetForm() {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      emit(currentState.copyWith(hasUnsavedChanges: false));
    }
  }

  Role? get currentRole {
    if (state is PolicyManagerFormLoaded) {
      return (state as PolicyManagerFormLoaded).role;
    }
    return null;
  }
}