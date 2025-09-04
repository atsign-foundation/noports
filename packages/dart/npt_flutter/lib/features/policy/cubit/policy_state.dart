part of 'policy_cubit.dart';

enum PolicyViewMode {
  rolesBrowsing,
  roleViewing,
  roleEditing,
  roleCreating,
  logsViewing,
}

abstract class PolicyState extends Loggable {
  const PolicyState();

  @override
  List<Object?> get props => [];
}

class PolicyLoading extends PolicyState {
  final String? operation;
  
  const PolicyLoading({this.operation});

  @override
  List<Object?> get props => [operation];

  @override
  String toString() {
    return operation != null 
        ? 'PolicyLoading(operation: $operation)'
        : 'PolicyLoading';
  }
}

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

  bool get isRolesBrowsing => viewMode == PolicyViewMode.rolesBrowsing;
  bool get isRoleViewing => viewMode == PolicyViewMode.roleViewing;
  bool get isRoleEditing => viewMode == PolicyViewMode.roleEditing;
  bool get isRoleCreating => viewMode == PolicyViewMode.roleCreating;
  bool get isLogsViewing => viewMode == PolicyViewMode.logsViewing;
  bool get isInRoleMode => isRolesBrowsing || isRoleViewing || isRoleEditing || isRoleCreating;
  bool get isInEditMode => isRoleEditing || isRoleCreating;
  bool get hasSelectedRole => selectedRole != null;
  bool get canEdit => isRoleViewing && !isInEditMode;
  bool get canSelectRole => (isRolesBrowsing || isRoleViewing || isLogsViewing) && !isInEditMode;
  bool get isValidRoleViewingState => isRoleViewing && hasSelectedRole;
  bool get isValidRoleEditingState => (isRoleEditing || isRoleCreating) && hasSelectedRole;
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

  @override
  String toString() {
    final roleInfo = selectedRole != null ? ' (${selectedRole!.name})' : '';
    return 'PolicyLoaded(viewMode: ${viewMode.name}, roles: ${roles.length}$roleInfo)';
  }
}

class PolicyError extends PolicyState {
  final String message;
  final PolicyViewMode? previousViewMode;
  final List<Role>? previousRoles;
  final Role? previousSelectedRole;
  final String? operation;
  
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

  @override
  String toString() {
    final operationInfo = operation != null ? ' (operation: $operation)' : '';
    return 'PolicyError(message: $message$operationInfo)';
  }
}