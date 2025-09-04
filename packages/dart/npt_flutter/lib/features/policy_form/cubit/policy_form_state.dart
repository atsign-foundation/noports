part of 'policy_form_cubit.dart';

abstract class PolicyFormState extends Loggable {
  const PolicyFormState();

  @override
  List<Object?> get props => [];
}

class PolicyFormInitial extends PolicyFormState {
  const PolicyFormInitial();

  @override
  String toString() => 'PolicyFormInitial';
}

class PolicyFormEditing extends PolicyFormState {
  final Role currentRole;
  final Role originalRole;
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

  bool get hasChanges => currentRole != originalRole;
  bool get canSave => !isSaving;
  bool get canDelete => !isNewRole && !isSaving;
  bool get canCancel => !isSaving;

  @override
  String toString() {
    final status = isSaving ? ' (saving)' : '';
    final type = isNewRole ? 'new' : 'existing';
    return 'PolicyFormEditing($type role: ${currentRole.name}$status)';
  }
}

class PolicyFormSuccess extends PolicyFormState {
  final Role savedRole;
  final bool wasNewRole;

  const PolicyFormSuccess({
    required this.savedRole,
    required this.wasNewRole,
  });

  @override
  List<Object?> get props => [savedRole, wasNewRole];

  @override
  String toString() {
    final action = wasNewRole ? 'created' : 'updated';
    return 'PolicyFormSuccess($action role: ${savedRole.name})';
  }
}

class PolicyFormDeleted extends PolicyFormState {
  final Role deletedRole;

  const PolicyFormDeleted({required this.deletedRole});

  @override
  List<Object?> get props => [deletedRole];

  @override
  String toString() => 'PolicyFormDeleted(role: ${deletedRole.name})';
}

class PolicyFormError extends PolicyFormState {
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