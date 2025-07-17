import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/policy.dart';
import 'policy_manager_state.dart';
import 'policy_manager_event.dart';

class PolicyManagerBloc extends Bloc<PolicyManagerEvent, PolicyManagerState> {
  PolicyManagerBloc() : super(PolicyManagerInitial()) {
    on<PolicyManagerLoadingRoles>(_onLoadingRoles);
    on<PolicyManagerViewingLoadedRole>(_onViewingLoadedRole);
    on<PolicyManagerEditingLoadedRole>(_onEditingLoadedRole);
    on<PolicyManagerInitialEvent>(_onInitial);
    on<PolicyManagerViewingNoRole>(_onViewingNoRole);
  }

  void _onLoadingRoles(PolicyManagerLoadingRoles event, Emitter<PolicyManagerState> emit) {
    emit(const PolicyManagerLoading(roles: []));
    
    // Simulate loading with placeholder data
    final placeholderRoles = _createPlaceholderRoles();
    emit(PolicyManagerLoaded(roles: placeholderRoles));
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

  List<Role> _createPlaceholderRoles() {
    return [
      Role(
        id: '1',
        name: 'Admin',
        description: 'Full access to all systems and configurations',
        daemonAtSigns: ['@admin_daemon'],
        devices: [
          Device(name: 'server-01', permitOpens: ['22', '80', '443']),
          Device(name: 'server-02', permitOpens: ['22', '3306']),
        ],
        deviceGroups: [
          DeviceGroup(name: 'production', permitOpens: ['22', '80', '443']),
        ],
        userAtSigns: ['@alice', '@bob'],
      ),
      Role(
        id: '2',
        name: 'Developer',
        description: 'Access to development environments and tools',
        daemonAtSigns: ['@dev_daemon'],
        devices: [
          Device(name: 'dev-server-01', permitOpens: ['22', '3000', '8080']),
          Device(name: 'dev-server-02', permitOpens: ['22', '5432']),
        ],
        deviceGroups: [
          DeviceGroup(name: 'development', permitOpens: ['22', '3000', '8080']),
        ],
        userAtSigns: ['@charlie', '@diana', '@eve'],
      ),
      Role(
        id: '3',
        name: 'QA Tester',
        description: 'Access to testing environments and staging systems',
        daemonAtSigns: ['@qa_daemon'],
        devices: [
          Device(name: 'test-server-01', permitOpens: ['22', '80']),
        ],
        deviceGroups: [
          DeviceGroup(name: 'testing', permitOpens: ['22', '80']),
        ],
        userAtSigns: ['@frank', '@grace'],
      ),
      Role(
        id: '4',
        name: 'Read Only',
        description: 'Limited read-only access to monitoring systems',
        daemonAtSigns: ['@readonly_daemon'],
        devices: [
          Device(name: 'monitor-01', permitOpens: ['22']),
        ],
        deviceGroups: [
          DeviceGroup(name: 'monitoring', permitOpens: ['22']),
        ],
        userAtSigns: ['@henry'],
      ),
    ];
  }
}