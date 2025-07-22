import 'package:equatable/equatable.dart';
import '../models/policy.dart';

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

class PolicyManagerLoaded extends PolicyManagerState {
  final List<Role> roles;
  final Role? selectedRole;

  const PolicyManagerLoaded({
    required this.roles,
    this.selectedRole,
  });

  @override
  List<Object?> get props => [roles, selectedRole];

  PolicyManagerLoaded copyWith({
    List<Role>? roles,
    Role? selectedRole,
    bool clearSelectedRole = false,
  }) {
    return PolicyManagerLoaded(
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