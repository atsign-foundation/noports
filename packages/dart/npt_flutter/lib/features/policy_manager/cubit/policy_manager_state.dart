part of 'policy_manager_cubit.dart';

/// Comprehensive enum representing different view modes in the Policy Manager
enum PolicyManagerViewMode {
  /// Browsing the list of roles with no selection
  rolesBrowsing,
  
  /// Viewing details of an existing role (read-only)
  roleViewing,
  
  /// Editing an existing role
  roleEditing,
  
  /// Creating a new role
  roleCreating,
  
  /// Viewing policy logs (completely separate from roles)
  logsViewing,
}

abstract class PolicyManagerState extends Equatable {
  const PolicyManagerState();

  @override
  List<Object?> get props => [];
}

/// Loading state for any async operations
class PolicyManagerLoading extends PolicyManagerState {
  final String? operation; // Optional description of what's loading
  
  const PolicyManagerLoading({this.operation});

  @override
  List<Object?> get props => [operation];
}

/// Main loaded state with comprehensive view mode handling
class PolicyManagerLoaded extends PolicyManagerState {
  final List<Role> roles;
  final Role? selectedRole;
  final PolicyManagerViewMode viewMode;

  const PolicyManagerLoaded({
    required this.roles,
    this.selectedRole,
    this.viewMode = PolicyManagerViewMode.rolesBrowsing,
  });

  @override
  List<Object?> get props => [roles, selectedRole, viewMode];

  PolicyManagerLoaded copyWith({
    List<Role>? roles,
    Role? selectedRole,
    PolicyManagerViewMode? viewMode,
    bool clearSelectedRole = false,
  }) {
    return PolicyManagerLoaded(
      roles: roles ?? this.roles,
      selectedRole: clearSelectedRole ? null : selectedRole ?? this.selectedRole,
      viewMode: viewMode ?? this.viewMode,
    );
  }

  /// Helper getters for cleaner code
  bool get isRolesBrowsing => viewMode == PolicyManagerViewMode.rolesBrowsing;
  bool get isRoleViewing => viewMode == PolicyManagerViewMode.roleViewing;
  bool get isRoleEditing => viewMode == PolicyManagerViewMode.roleEditing;
  bool get isRoleCreating => viewMode == PolicyManagerViewMode.roleCreating;
  bool get isLogsViewing => viewMode == PolicyManagerViewMode.logsViewing;
  
  /// Combined getters for UI logic
  bool get isInRoleMode => isRolesBrowsing || isRoleViewing || isRoleEditing || isRoleCreating;
  bool get isInEditMode => isRoleEditing || isRoleCreating;
  bool get hasSelectedRole => selectedRole != null;
  bool get canEdit => isRoleViewing && !isInEditMode;
  bool get canSelectRole => isRolesBrowsing && !isInEditMode;
  
  /// Validation getters
  bool get isValidRoleViewingState => isRoleViewing && hasSelectedRole;
  bool get isValidRoleEditingState => (isRoleEditing || isRoleCreating) && hasSelectedRole;
  
  /// Display getters
  String get viewModeDisplayName {
    switch (viewMode) {
      case PolicyManagerViewMode.rolesBrowsing:
        return 'Browsing Roles';
      case PolicyManagerViewMode.roleViewing:
        return 'Viewing Role';
      case PolicyManagerViewMode.roleEditing:
        return 'Editing Role';
      case PolicyManagerViewMode.roleCreating:
        return 'Creating Role';
      case PolicyManagerViewMode.logsViewing:
        return 'Policy Logs';
    }
  }
}

/// Error state with contextual information and recovery data
class PolicyManagerError extends PolicyManagerState {
  final String message;
  final PolicyManagerViewMode? previousViewMode;
  final List<Role>? previousRoles;
  final Role? previousSelectedRole;
  final String? operation; // What operation failed
  
  const PolicyManagerError(
    this.message, {
    this.previousViewMode,
    this.previousRoles,
    this.previousSelectedRole,
    this.operation,
  });

  @override
  List<Object?> get props => [
    message, 
    previousViewMode, 
    previousRoles, 
    previousSelectedRole, 
    operation
  ];
  
  /// Helper to recover to a valid previous state
  PolicyManagerLoaded? get recoverableState {
    if (previousRoles != null) {
      return PolicyManagerLoaded(
        roles: previousRoles!,
        selectedRole: previousSelectedRole,
        viewMode: previousViewMode ?? PolicyManagerViewMode.rolesBrowsing,
      );
    }
    return null;
  }
}