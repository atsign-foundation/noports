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
  const PolicyFormLoading();

  @override
  String toString() => 'PolicyFormLoading';
}

sealed class PolicyFormEditing extends PolicyFormState {
  final Role currentRole;
  final bool isSaving;

  const PolicyFormEditing({
    required this.currentRole,
    required this.isSaving,
  });

  @override
  List<Object?> get props => [currentRole, isSaving];

  bool get canSave => !isSaving;
  bool get canCancel => !isSaving;
}

final class PolicyFormEditingNew extends PolicyFormEditing {
  const PolicyFormEditingNew({
    required super.currentRole,
    required super.isSaving,
  });

  PolicyFormEditingNew copyWith({
    Role? currentRole,
    bool? isSaving,
  }) {
    return PolicyFormEditingNew(
      currentRole: currentRole ?? this.currentRole,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  bool get hasChanges => currentRole.name.isNotEmpty || currentRole.description.isNotEmpty;
  bool get canDelete => false;

  @override
  String toString() {
    final status = isSaving ? ' (saving)' : '';
    return 'PolicyFormEditingNew(role: ${currentRole.name}$status)';
  }
}

final class PolicyFormEditingExisting extends PolicyFormEditing {
  final Role originalRole;

  const PolicyFormEditingExisting({
    required super.currentRole,
    required this.originalRole,
    required super.isSaving,
  });

  @override
  List<Object?> get props => [currentRole, originalRole, isSaving];

  PolicyFormEditingExisting copyWith({
    Role? currentRole,
    Role? originalRole,
    bool? isSaving,
  }) {
    return PolicyFormEditingExisting(
      currentRole: currentRole ?? this.currentRole,
      originalRole: originalRole ?? this.originalRole,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  bool get hasChanges => currentRole != originalRole;
  bool get canDelete => !isSaving;

  @override
  String toString() {
    final status = isSaving ? ' (saving)' : '';
    return 'PolicyFormEditingExisting(role: ${currentRole.name}$status)';
  }
}

final class PolicyFormError extends PolicyFormState {
  final String message;
  final PolicyFormEditing previousState;

  const PolicyFormError({
    required this.message,
    required this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];

  @override
  String toString() => 'PolicyFormError(message: $message)';
}