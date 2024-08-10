part of 'settings_bloc.dart';

sealed class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

final class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

sealed class SettingsLoadedState extends SettingsState {
  final Settings settings;
  const SettingsLoadedState({required this.settings});

  @override
  List<Object?> get props => [settings];
}

final class SettingsLoaded extends SettingsLoadedState {
  const SettingsLoaded({required super.settings});
}

final class SettingsFailedLoad extends SettingsLoadedState {
  const SettingsFailedLoad({required super.settings});
}

final class SettingsFailedSave extends SettingsLoadedState {
  const SettingsFailedSave({required super.settings});
}
