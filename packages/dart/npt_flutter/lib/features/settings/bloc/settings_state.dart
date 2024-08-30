part of 'settings_bloc.dart';

sealed class SettingsState extends Loggable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

final class SettingsInitial extends SettingsState {
  const SettingsInitial();

  @override
  String toString() {
    return 'SettingsInitial';
  }
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading();

  @override
  String toString() {
    return 'SettingsLoading';
  }
}

sealed class SettingsLoadedState extends SettingsState {
  final Settings settings;
  const SettingsLoadedState({required this.settings});

  @override
  List<Object?> get props => [settings];
}

final class SettingsLoaded extends SettingsLoadedState {
  const SettingsLoaded({required super.settings});

  @override
  String toString() {
    return 'SettingsLoaded(settings: $settings)';
  }
}

final class SettingsFailedLoad extends SettingsLoadedState {
  const SettingsFailedLoad({required super.settings});

  @override
  String toString() {
    return 'SettingsFailedLoad(settings: $settings)';
  }
}

final class SettingsFailedSave extends SettingsLoadedState {
  const SettingsFailedSave({required super.settings});

  @override
  String toString() {
    return 'SettingsFailedSave(settings: $settings)';
  }
}
