part of 'policy_manager_cubit.dart';

abstract class PolicyManagerState extends Equatable {
  const PolicyManagerState();

  @override
  List<Object?> get props => [];
}

class PolicyManagerInitial extends PolicyManagerState {}

class PolicyManagerLoading extends PolicyManagerState {
  final Role? selectedRole;
  final List<Role>? roles;

  const PolicyManagerLoading({
    this.selectedRole,
    this.roles,
  });

  @override
  List<Object?> get props => [selectedRole, roles];
}

class PolicyManagerRoleLoaded extends PolicyManagerState {
  final List<Role> roles;
  final Role? selectedRole;
  final bool isEditing;

  const PolicyManagerRoleLoaded({
    required this.roles,
    this.selectedRole,
    this.isEditing = false,
  });

  @override
  List<Object?> get props => [roles, selectedRole, isEditing];

  PolicyManagerRoleLoaded copyWith({
    List<Role>? roles,
    Role? selectedRole,
    bool? isEditing,
    bool clearSelectedRole = false,
  }) {
    return PolicyManagerRoleLoaded(
      roles: roles ?? this.roles,
      selectedRole: clearSelectedRole ? null : selectedRole ?? this.selectedRole,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

class PolicyManagerViewLogsPageLoaded extends PolicyManagerState {
  final List<Role> roles;
  final Role? selectedRole;

  const PolicyManagerViewLogsPageLoaded({
    required this.roles,
    this.selectedRole,
  });

  @override
  List<Object?> get props => [roles, selectedRole];

  PolicyManagerViewLogsPageLoaded copyWith({
    List<Role>? roles,
    Role? selectedRole,
    bool clearSelectedRole = false,
  }) {
    return PolicyManagerViewLogsPageLoaded(
      roles: roles ?? this.roles,
      selectedRole: clearSelectedRole ? null : selectedRole ?? this.selectedRole,
    );
  }
}

class PolicyManagerError extends PolicyManagerState {
  final String message;

  const PolicyManagerError(this.message);

  @override
  List<Object?> get props => [message];
}