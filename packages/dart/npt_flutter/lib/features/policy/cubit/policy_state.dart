part of 'policy_cubit.dart';

/// Comprehensive enum representing different view modes in the Policy Manager
enum PolicyViewMode {
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

abstract class PolicyState extends Equatable {
  const PolicyState();

  @override
  List<Object?> get props => [];
}

/// Loading state for any async operations
class PolicyLoading extends PolicyState {
  final String? operation; // Optional description of what's loading
  
  const PolicyLoading({this.operation});

  @override
  List<Object?> get props => [operation];
}

/// Main loaded state with comprehensive view mode handling
class PolicyLoaded extends PolicyState {
  final List<Role> roles;
  final Role? selectedRole;
  final PolicyViewMode viewMode;

  const PolicyLoaded({
    required this.roles,
    this.selectedRole,
    this.viewMode = PolicyViewMode.rolesBrowsing,
  });

  @override
  List<Object?> get props => [roles, selectedRole, viewMode];

  PolicyLoaded copyWith({
    List<Role>? roles,
    Role? selectedRole,
    PolicyViewMode? viewMode,
    bool clearSelectedRole = false,
  }) {
    return PolicyLoaded(
      roles: roles ?? this.roles,
      selectedRole: clearSelectedRole ? null : selectedRole ?? this.selectedRole,
      viewMode: viewMode ?? this.viewMode,
    );
  }

  /// Helper getters for cleaner code
  bool get isRolesBrowsing => viewMode == PolicyViewMode.rolesBrowsing;
  bool get isRoleViewing => viewMode == PolicyViewMode.roleViewing;
  bool get isRoleEditing => viewMode == PolicyViewMode.roleEditing;
  bool get isRoleCreating => viewMode == PolicyViewMode.roleCreating;
  bool get isLogsViewing => viewMode == PolicyViewMode.logsViewing;
  
  /// Combined getters for UI logic
  bool get isInRoleMode => isRolesBrowsing || isRoleViewing || isRoleEditing || isRoleCreating;
  bool get isInEditMode => isRoleEditing || isRoleCreating;
  bool get hasSelectedRole => selectedRole != null;
  bool get canEdit => isRoleViewing && !isInEditMode;
  bool get canSelectRole => (isRolesBrowsing || isRoleViewing) && !isInEditMode;
  
  /// Validation getters
  bool get isValidRoleViewingState => isRoleViewing && hasSelectedRole;
  bool get isValidRoleEditingState => (isRoleEditing || isRoleCreating) && hasSelectedRole;
  
  /// Display getters
  String get viewModeDisplayName {
    switch (viewMode) {
      case PolicyViewMode.rolesBrowsing:
        return 'Browsing Roles';
      case PolicyViewMode.roleViewing:
        return 'Viewing Role';
      case PolicyViewMode.roleEditing:
        return 'Editing Role';
      case PolicyViewMode.roleCreating:
        return 'Creating Role';
      case PolicyViewMode.logsViewing:
        return 'Policy Logs';
    }
  }
}

/// Error state with contextual information and recovery data
class PolicyError extends PolicyState {
  final String message;
  final PolicyViewMode? previousViewMode;
  final List<Role>? previousRoles;
  final Role? previousSelectedRole;
  final String? operation; // What operation failed
  
  const PolicyError(
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
  PolicyLoaded? get recoverableState {
    if (previousRoles != null) {
      return PolicyLoaded(
        roles: previousRoles!,
        selectedRole: previousSelectedRole,
        viewMode: previousViewMode ?? PolicyViewMode.rolesBrowsing,
      );
    }
    return null;
  }
}