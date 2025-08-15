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

class PolicyManagerInitialEvent extends PolicyManagerEvent {
  const PolicyManagerInitialEvent();
}

class PolicyManagerRoleSelected extends PolicyManagerEvent {
  final String roleId;

  const PolicyManagerRoleSelected(this.roleId);

  @override
  List<Object?> get props => [roleId];
}

class PolicyManagerRoleDeselected extends PolicyManagerEvent {
  const PolicyManagerRoleDeselected();
}

class PolicyManagerStartEditing extends PolicyManagerEvent {
  final String roleId;

  const PolicyManagerStartEditing(this.roleId);

  @override
  List<Object?> get props => [roleId];
}

class PolicyManagerStopEditing extends PolicyManagerEvent {
  const PolicyManagerStopEditing();
}

class PolicyManagerSaveRole extends PolicyManagerEvent {
  final Role role;

  const PolicyManagerSaveRole(this.role);

  @override
  List<Object?> get props => [role];
}

class PolicyManagerCreateRole extends PolicyManagerEvent {
  final Role role;

  const PolicyManagerCreateRole(this.role);

  @override
  List<Object?> get props => [role];
}

class PolicyManagerDeleteRole extends PolicyManagerEvent {
  final String roleId;

  const PolicyManagerDeleteRole(this.roleId);

  @override
  List<Object?> get props => [roleId];
}

class PolicyManagerUpdateRole extends PolicyManagerEvent {
  final Role role;

  const PolicyManagerUpdateRole(this.role);

  @override
  List<Object?> get props => [role];
}

class PolicyManagerCancelEdit extends PolicyManagerEvent {
  const PolicyManagerCancelEdit();
}

class PolicyManagerStartNewRole extends PolicyManagerEvent {
  const PolicyManagerStartNewRole();
}

class PolicyManagerShowLogs extends PolicyManagerEvent {
  const PolicyManagerShowLogs();
}

class PolicyManagerShowRoles extends PolicyManagerEvent {
  const PolicyManagerShowRoles();
}