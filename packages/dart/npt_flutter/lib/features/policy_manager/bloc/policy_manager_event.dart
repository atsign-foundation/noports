import 'package:equatable/equatable.dart';

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