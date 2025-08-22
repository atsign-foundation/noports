part of 'policy_manager_cubit.dart';

enum PolicyManagerView {
  roles,
  logs,
}

abstract class PolicyManagerState extends Equatable {
  const PolicyManagerState();

  @override
  List<Object?> get props => [];
}

/// Single loading state for all operations
class PolicyManagerLoading extends PolicyManagerState {
  const PolicyManagerLoading();
}

/// Main state that handles both roles and logs views
class PolicyManagerLoaded extends PolicyManagerState {
  final List<Role> roles;
  final Role? selectedRole;
  final bool isEditing;
  final PolicyManagerView currentView;

  const PolicyManagerLoaded({
    required this.roles,
    this.selectedRole,
    this.isEditing = false,
    this.currentView = PolicyManagerView.roles,
  });

  @override
  List<Object?> get props => [roles, selectedRole, isEditing, currentView];

  PolicyManagerLoaded copyWith({
    List<Role>? roles,
    Role? selectedRole,
    bool? isEditing,
    PolicyManagerView? currentView,
    bool clearSelectedRole = false,
  }) {
    return PolicyManagerLoaded(
      roles: roles ?? this.roles,
      selectedRole: clearSelectedRole ? null : selectedRole ?? this.selectedRole,
      isEditing: isEditing ?? this.isEditing,
      currentView: currentView ?? this.currentView,
    );
  }

  /// Helper getters for cleaner code
  bool get isRolesView => currentView == PolicyManagerView.roles;
  bool get isLogsView => currentView == PolicyManagerView.logs;
  bool get canEdit => isRolesView && !isEditing;
}

/// Error state for when operations fail
class PolicyManagerError extends PolicyManagerState {
  final String message;
  final List<Role>? previousRoles; // Keep previous data for recovery
  final Role? previousSelectedRole;

  const PolicyManagerError(
    this.message, {
    this.previousRoles,
    this.previousSelectedRole,
  });

  @override
  List<Object?> get props => [message, previousRoles, previousSelectedRole];
}