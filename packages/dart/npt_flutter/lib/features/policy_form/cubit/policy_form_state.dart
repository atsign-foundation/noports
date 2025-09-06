part of 'policy_form_cubit.dart';

/// Summary of the states for the PolicyFormCubit
/// - PolicyFormState (base state class)
///   - PolicyFormLoading: Loading state when the form is being initialized
///   - PolicyFormEditing (abstract class for editing states)
///     - PolicyFormEditingNew (creating a new role)
///     - PolicyFormEditingExisting (state when editing an existing role)

sealed class PolicyFormState extends Loggable {
  const PolicyFormState();

  @override
  List<Object?> get props => [];
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

final class PolicyFormEditingNewRole extends PolicyFormState {
  final RoleInProgress roleInProgress;
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

  bool get canSave => !isSaving;
  bool get canCancel => !isSaving;
}

final class PolicyFormEditingExistingRole extends PolicyFormState {
  final FetchedRole currentRole;
  final FetchedRole? _originalRole;
  FetchedRole get originalRole => _originalRole ?? currentRole;
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
  bool get canDelete => !isSaving;
  bool get canCancel => !isSaving;
}

final class PolicyFormError extends PolicyFormState {
  final String message;
  final PolicyFormState? previousState;

  const PolicyFormError({
    required this.message,
    this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];

  @override
  String toString() => 'PolicyFormError(message: $message)';
}