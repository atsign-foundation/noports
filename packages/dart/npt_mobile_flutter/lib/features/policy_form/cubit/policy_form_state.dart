part of 'policy_form_cubit.dart';

/// Summary of the states for the PolicyFormCubit
/// - PolicyFormState (base state class)
///   - PolicyFormLoading: Loading state when the form is being initialized
///   - PolicyFormViewingRole: Read-only viewing of an existing role
///   - PolicyFormEditingNewRole: Creating a new role
///   - PolicyFormEditingExistingRole: Editing an existing role

sealed class PolicyFormState extends Loggable {
  const PolicyFormState();

  @override
  List<Object?> get props => [];

  // Convenience getters that work across all states
  RoleInProgress? get currentRole => switch (this) {
    PolicyFormEditingExistingRole(:final currentRole) => currentRole,
    PolicyFormEditingNewRole(:final roleInProgress) => roleInProgress,
    _ => null,
  };

  bool get isSaving => switch (this) {
    PolicyFormEditingExistingRole(:final isSaving) => isSaving,
    PolicyFormEditingNewRole(:final isSaving) => isSaving,
    _ => false,
  };

  bool get canDelete => switch (this) {
    PolicyFormEditingExistingRole(:final canDelete) => canDelete,
    _ => false,
  };

  bool get isEditingState =>
      this is PolicyFormEditingExistingRole || this is PolicyFormEditingNewRole;
}

final class PolicyFormLoading extends PolicyFormState {
  final String? operation;

  const PolicyFormLoading({this.operation});

  @override
  String toString() {
    return operation != null
        ? 'PolicyFormLoading(operation: $operation)'
        : 'PolicyFormLoading';
  }
}

final class PolicyFormViewingRole extends PolicyFormState {
  @override
  final FetchedRole currentRole;

  const PolicyFormViewingRole({required this.currentRole});

  @override
  List<Object?> get props => [currentRole];

  @override
  String toString() => 'PolicyFormViewingRole(role: ${currentRole.name})';
}

final class PolicyFormEditingNewRole extends PolicyFormState {
  final RoleInProgress roleInProgress;
  @override
  final bool isSaving;

  const PolicyFormEditingNewRole({
    required this.roleInProgress,
    this.isSaving = false,
  });

  @override
  List<Object?> get props => [roleInProgress, isSaving];

  PolicyFormEditingNewRole copyWith({
    RoleInProgress? roleInProgress,
    bool? isSaving,
  }) {
    return PolicyFormEditingNewRole(
      roleInProgress: roleInProgress ?? this.roleInProgress,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  RoleInProgress get currentRole => roleInProgress;

  bool get canSave => !isSaving;
  bool get canCancel => !isSaving;

  @override
  String toString() =>
      'PolicyFormEditingNewRole(roleInProgress: ${roleInProgress.name}, isSaving: $isSaving)';
}

final class PolicyFormEditingExistingRole extends PolicyFormState {
  @override
  final FetchedRole currentRole;
  final FetchedRole? _originalRole;
  FetchedRole get originalRole => _originalRole ?? currentRole;
  @override
  final bool isSaving;

  const PolicyFormEditingExistingRole({
    required this.currentRole,
    FetchedRole? originalRole,
    this.isSaving = false,
  }) : _originalRole = originalRole;

  @override
  List<Object?> get props => [currentRole, isSaving];

  PolicyFormEditingExistingRole copyWith({
    FetchedRole? currentRole,
    FetchedRole? originalRole,
    bool? isSaving,
  }) {
    return PolicyFormEditingExistingRole(
      currentRole: currentRole ?? this.currentRole,
      originalRole: originalRole ?? _originalRole,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  bool get canSave => !isSaving;
  @override
  bool get canDelete => !isSaving;
  bool get canCancel => !isSaving;

  @override
  String toString() =>
      'PolicyFormEditingExistingRole(currentRole: ${currentRole.name}, isSaving: $isSaving)';
}

final class PolicyFormError extends PolicyFormState {
  final String message;
  final PolicyFormState? previousState;

  const PolicyFormError({required this.message, this.previousState});

  @override
  List<Object?> get props => [message, previousState];

  @override
  String toString() => 'PolicyFormError(message: $message)';
}
