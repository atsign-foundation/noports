part of 'policy_cubit.dart';

// This class extends Loggable to integrate with LoggingCubit for automatic logging of state changes.
sealed class PolicyState extends Loggable {
  const PolicyState();

  @override
  List<Object?> get props => [];
}

/// Overview of states
/// - PolicyState (base class)
///   - PolicyInitial (initial state)
///   - PolicyLoading (we're loading something)
///   - PolicyLoaded (roles are done loading)
///     - RolesBrowsingState (we're just browsing roles, nothing is selected)
///     - RoleViewingState (a role is selected for viewing)
///     - RoleEditingState (a role is selected for editing)
///     - RoleCreatingState (a new role is being created)
///     - LogsViewingState (we're viewing logs)
///   - PolicyError (we hit an error)

final class PolicyInitial extends PolicyState {
  const PolicyInitial();

  @override
  String toString() => 'PolicyInitial';
}

final class PolicyLoading extends PolicyState {
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

sealed class PolicyLoaded extends PolicyState {
  final List<FetchedRole> roles;

  const PolicyLoaded({required this.roles});

  @override
  List<Object?> get props => [roles];

  String get viewModeDisplayName;
}

final class PolicyBrowsingRoles extends PolicyLoaded {
  const PolicyBrowsingRoles({required super.roles});

  @override
  String get viewModeDisplayName => 'Browsing Roles';

  @override
  String toString() => 'PolicyBrowsingRoles(roles: ${roles.length})';
}

final class PolicyViewingExistingRole extends PolicyLoaded {
  final FetchedRole selectedRole;

  const PolicyViewingExistingRole({
    required super.roles,
    required this.selectedRole,
  });

  @override
  List<Object?> get props => [roles, selectedRole];

  @override
  String get viewModeDisplayName => 'Viewing Role';

  @override
  String toString() => 'PolicyViewingExistingRole(roles: ${roles.length}, role: ${selectedRole.name})';
}

final class PolicyEditingExistingRole extends PolicyLoaded {
  final FetchedRole selectedRole;

  const PolicyEditingExistingRole({
    required super.roles,
    required this.selectedRole,
  });

  @override
  List<Object?> get props => [roles, selectedRole];

  @override
  String get viewModeDisplayName => 'Editing Role';

  @override
  String toString() => 'PolicyEditingExistingRoleState(roles: ${roles.length}, role: ${selectedRole.name})';
}

final class PolicyEditingNewRole extends PolicyLoaded {
  final RoleInProgress roleInProgress;

  const PolicyEditingNewRole({
    required super.roles,
    required this.roleInProgress,
  });

  @override
  List<Object?> get props => [roles, roleInProgress];

  @override
  String get viewModeDisplayName => 'Creating Role';

  @override
  String toString() => 'RoleCreatingState(roles: ${roles.length}, role: ${roleInProgress.name})';
}

final class PolicyViewingLogs extends PolicyLoaded {
  const PolicyViewingLogs({required super.roles});

  @override
  String get viewModeDisplayName => 'Policy Logs';

  @override
  String toString() => 'PolicyViewingLogs(roles: ${roles.length})';
}

final class PolicyError extends PolicyState {
  final String message;
  final PolicyLoaded? previousState;
  final String? operation;

  const PolicyError(
    this.message, {
    this.previousState,
    this.operation,
  });

  @override
  List<Object?> get props => [message, previousState, operation];

  PolicyLoaded? get recoverableState => previousState;

  @override
  String toString() {
    final operationInfo = operation != null ? ' (operation: $operation)' : '';
    return 'PolicyError(message: $message$operationInfo)';
  }
}