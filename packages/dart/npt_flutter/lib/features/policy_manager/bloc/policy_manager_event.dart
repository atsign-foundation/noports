import 'package:equatable/equatable.dart';
import '../models/policy.dart';

abstract class PolicyManagerEvent extends Equatable {
  const PolicyManagerEvent();

  @override
  List<Object?> get props => [];
}

class PolicyManagerLoadingRoles extends PolicyManagerEvent {
  const PolicyManagerLoadingRoles();
}

class PolicyManagerViewingLoadedRole extends PolicyManagerEvent {
  final String roleId;

  const PolicyManagerViewingLoadedRole(this.roleId);

  @override
  List<Object?> get props => [roleId];
}

class PolicyManagerEditingLoadedRole extends PolicyManagerEvent {
  final String roleId;

  const PolicyManagerEditingLoadedRole(this.roleId);

  @override
  List<Object?> get props => [roleId];
}

class PolicyManagerInitialEvent extends PolicyManagerEvent {
  const PolicyManagerInitialEvent();
}

class PolicyManagerViewingNoRole extends PolicyManagerEvent {
  const PolicyManagerViewingNoRole();
}

class PolicyManagerEdit extends PolicyManagerEvent {
  final String roleId;

  const PolicyManagerEdit(this.roleId);

  @override
  List<Object?> get props => [roleId];
}

class PolicyManagerSave extends PolicyManagerEvent {
  final Role role;

  const PolicyManagerSave(this.role);

  @override
  List<Object?> get props => [role];
}