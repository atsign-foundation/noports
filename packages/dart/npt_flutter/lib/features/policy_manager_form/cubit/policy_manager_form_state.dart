import 'package:equatable/equatable.dart';
import '../../policy_manager/models/policy.dart';

abstract class PolicyManagerFormState extends Equatable {
  const PolicyManagerFormState();

  @override
  List<Object?> get props => [];
}

class PolicyManagerFormInitial extends PolicyManagerFormState {}

class PolicyManagerFormLoading extends PolicyManagerFormState {}

class PolicyManagerFormLoaded extends PolicyManagerFormState {
  final Role role;
  final bool isEditing;

  const PolicyManagerFormLoaded({
    required this.role,
    this.isEditing = false,
  });

  @override
  List<Object?> get props => [role, isEditing];

  PolicyManagerFormLoaded copyWith({
    Role? role,
    bool? isEditing,
  }) {
    return PolicyManagerFormLoaded(
      role: role ?? this.role,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

class PolicyManagerFormError extends PolicyManagerFormState {
  final String message;

  const PolicyManagerFormError(this.message);

  @override
  List<Object?> get props => [message];
}