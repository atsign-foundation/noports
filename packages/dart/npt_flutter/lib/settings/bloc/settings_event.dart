part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

final class SettingsLoadEvent extends SettingsEvent {
  const SettingsLoadEvent();
}

final class SettingsEditEvent extends SettingsEvent {
  final Settings settings;
  final bool save; // save to the atServer
  const SettingsEditEvent({required this.settings, this.save = false});

  @override
  List<Object> get props => [settings, save];
}
