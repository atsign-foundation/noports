import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/policy.dart';
import '../repositories/role_repository.dart';
import 'policy_manager_state.dart';
import 'policy_manager_event.dart';

class PolicyManagerBloc extends Bloc<PolicyManagerEvent, PolicyManagerState> {
  final RoleRepository _roleRepository;
  
  PolicyManagerBloc(this._roleRepository) : super(PolicyManagerInitial()) {
    on<PolicyManagerInitialEvent>(_onInitial);
    on<PolicyManagerLoadingRoles>(_onLoadingRoles);
    on<PolicyManagerViewingNoRole>(_onViewingNoRole);
    on<PolicyManagerViewingLoadedRole>(_onViewingLoadedRole);
    on<PolicyManagerEditingLoadedRole>(_onEditingLoadedRole);
  }

  void _onLoadingRoles(PolicyManagerLoadingRoles event, Emitter<PolicyManagerState> emit) async {
    emit(const PolicyManagerLoading(roles: []));
    
    try {
      final roles = await _roleRepository.getAllRoles();
      emit(PolicyManagerLoaded(roles: roles));
    } catch (error) {
      emit(PolicyManagerError('Failed to load roles: $error'));
    }
  }

  void _onViewingLoadedRole(PolicyManagerViewingLoadedRole event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == event.roleId,
        orElse: () => currentState.roles.first,
      );
      
      emit(currentState.copyWith(selectedRole: selectedRole));
    }
  }

  void _onEditingLoadedRole(PolicyManagerEditingLoadedRole event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      final selectedRole = currentState.roles.firstWhere(
        (role) => role.id == event.roleId,
        orElse: () => currentState.roles.first,
      );
      
      // For now, just set the selected role - editing functionality to be implemented later
      emit(currentState.copyWith(selectedRole: selectedRole));
    }
  }

  void _onInitial(PolicyManagerInitialEvent event, Emitter<PolicyManagerState> emit) {
    emit(PolicyManagerInitial());
  }

  void _onViewingNoRole(PolicyManagerViewingNoRole event, Emitter<PolicyManagerState> emit) {
    if (state is PolicyManagerLoaded) {
      final currentState = state as PolicyManagerLoaded;
      emit(currentState.copyWith(clearSelectedRole: true));
    }
  }

}