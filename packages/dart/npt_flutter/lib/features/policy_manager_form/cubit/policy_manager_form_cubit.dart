import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import 'policy_manager_form_state.dart';

class PolicyManagerFormCubit extends Cubit<PolicyManagerFormState> {
  PolicyManagerFormCubit() : super(PolicyManagerFormInitial());

  void loadRole(Role role) {
    emit(PolicyManagerFormLoading());
    emit(PolicyManagerFormLoaded(role: role));
  }

  void startEditing() {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      emit(currentState.copyWith(isEditing: true));
    }
  }

  void stopEditing() {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      emit(currentState.copyWith(isEditing: false));
    }
  }

  void updateRoleName(String name) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = Role(
        id: currentState.role.id,
        name: name,
        description: currentState.role.description,
        daemonAtSigns: currentState.role.daemonAtSigns,
        devices: currentState.role.devices,
        deviceGroups: currentState.role.deviceGroups,
        userAtSigns: currentState.role.userAtSigns,
      );
      emit(currentState.copyWith(role: updatedRole));
    }
  }

  void updateRoleDescription(String description) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = Role(
        id: currentState.role.id,
        name: currentState.role.name,
        description: description,
        daemonAtSigns: currentState.role.daemonAtSigns,
        devices: currentState.role.devices,
        deviceGroups: currentState.role.deviceGroups,
        userAtSigns: currentState.role.userAtSigns,
      );
      emit(currentState.copyWith(role: updatedRole));
    }
  }

  void updateDaemonAtSigns(List<String> daemonAtSigns) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = Role(
        id: currentState.role.id,
        name: currentState.role.name,
        description: currentState.role.description,
        daemonAtSigns: daemonAtSigns,
        devices: currentState.role.devices,
        deviceGroups: currentState.role.deviceGroups,
        userAtSigns: currentState.role.userAtSigns,
      );
      emit(currentState.copyWith(role: updatedRole));
    }
  }

  void updateUserAtSigns(List<String> userAtSigns) {
    if (state is PolicyManagerFormLoaded) {
      final currentState = state as PolicyManagerFormLoaded;
      final updatedRole = Role(
        id: currentState.role.id,
        name: currentState.role.name,
        description: currentState.role.description,
        daemonAtSigns: currentState.role.daemonAtSigns,
        devices: currentState.role.devices,
        deviceGroups: currentState.role.deviceGroups,
        userAtSigns: userAtSigns,
      );
      emit(currentState.copyWith(role: updatedRole));
    }
  }

  void clear() {
    emit(PolicyManagerFormInitial());
  }
}