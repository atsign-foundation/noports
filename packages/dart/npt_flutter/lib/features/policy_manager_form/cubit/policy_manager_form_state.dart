import 'package:equatable/equatable.dart';
import '../../policy_manager/models/policy.dart';

abstract class PolicyManagerFormState extends Equatable {
  const PolicyManagerFormState();

  @override
  List<Object?> get props => [];
}

class PolicyManagerFormInitial extends PolicyManagerFormState {}

class PolicyManagerFormLoaded extends PolicyManagerFormState {
  final Role role;
  final bool isEditing;
  final bool hasUnsavedChanges;

  const PolicyManagerFormLoaded({
    required this.role,
    this.isEditing = false,
    this.hasUnsavedChanges = false,
  });

  @override
  List<Object?> get props => [role, isEditing, hasUnsavedChanges];

  PolicyManagerFormLoaded copyWith({
    Role? role,
    bool? isEditing,
    bool? hasUnsavedChanges,
  }) {
    return PolicyManagerFormLoaded(
      role: role ?? this.role,
      isEditing: isEditing ?? this.isEditing,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}

class PolicyManagerFormSaving extends PolicyManagerFormState {
  final Role role;

  const PolicyManagerFormSaving(this.role);

  @override
  List<Object?> get props => [role];
}

class PolicyManagerFormSaved extends PolicyManagerFormState {
  final Role role;

  const PolicyManagerFormSaved(this.role);

  @override
  List<Object?> get props => [role];
}

class PolicyManagerFormError extends PolicyManagerFormState {
  final String message;
  final Role? role;

  const PolicyManagerFormError(this.message, {this.role});

  @override
  List<Object?> get props => [message, role];
}