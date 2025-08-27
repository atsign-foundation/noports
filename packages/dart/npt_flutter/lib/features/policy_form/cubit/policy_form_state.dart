part of 'policy_form_cubit.dart';

abstract class PolicyFormState extends Equatable {
  const PolicyFormState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any form interaction
class PolicyFormInitial extends PolicyFormState {
  const PolicyFormInitial();
}

/// State when editing a role (both new and existing)
class PolicyFormEditing extends PolicyFormState {
  final Role currentRole;
  final Role originalRole; // For cancel functionality
  final bool isNewRole;
  final bool isSaving;

  const PolicyFormEditing({
    required this.currentRole,
    required this.originalRole,
    required this.isNewRole,
    required this.isSaving,
  });

  @override
  List<Object?> get props => [currentRole, originalRole, isNewRole, isSaving];

  PolicyFormEditing copyWith({
    Role? currentRole,
    Role? originalRole,
    bool? isNewRole,
    bool? isSaving,
  }) {
    return PolicyFormEditing(
      currentRole: currentRole ?? this.currentRole,
      originalRole: originalRole ?? this.originalRole,
      isNewRole: isNewRole ?? this.isNewRole,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  /// Helper getters
  bool get hasChanges => currentRole != originalRole;
  bool get canSave => !isSaving;
  bool get canDelete => !isNewRole && !isSaving;
  bool get canCancel => !isSaving;
}

/// State when role was successfully saved
class PolicyFormSuccess extends PolicyFormState {
  final Role savedRole;
  final bool wasNewRole;

  const PolicyFormSuccess({
    required this.savedRole,
    required this.wasNewRole,
  });

  @override
  List<Object?> get props => [savedRole, wasNewRole];
}

/// State when role was successfully deleted
class PolicyFormDeleted extends PolicyFormState {
  final Role deletedRole;

  const PolicyFormDeleted({required this.deletedRole});

  @override
  List<Object?> get props => [deletedRole];
}

/// Error state with recovery information
class PolicyFormError extends PolicyFormState {
  final String message;
  final PolicyFormEditing previousState;

  const PolicyFormError({
    required this.message,
    required this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];
}