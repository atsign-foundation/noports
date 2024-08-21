import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/settings/settings.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends LoggingBloc<SettingsEvent, SettingsState> {
  final SettingsRepository _repo;
  SettingsBloc(this._repo) : super(const SettingsInitial()) {
    on<SettingsLoadEvent>(_onLoad);
    on<SettingsEditEvent>(_onEdit);
  }

  Future<void> _onLoad(
      SettingsLoadEvent event, Emitter<SettingsState> emit) async {
    emit(const SettingsLoading());
    Settings? settings;
    try {
      settings = await _repo.getSettings();
    } catch (_) {
      settings = null;
    }
    if (settings == null) {
      // If we failed to load the settings, use the default one
      // but still set error to true in case we want to distinguish later
      // For, example if the number of settings grows and it becomes
      // important to recover/retry loading the settings
      emit(SettingsFailedLoad(settings: _repo.defaultSettings));
      return;
    }

    emit(SettingsLoaded(settings: settings));
    // We want Logging off by default, but it starts as on and only gets
    // disabled once the settings have loaded, otherwise there is no way to
    // debug the startup phase of the app
    //App.navState.currentContext?.read<EnableLoggingCubit>().disable();
  }

  Future<void> _onEdit(
      SettingsEditEvent event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoading) return;

    bool res = true; // true so we emit loaded state if not saving
    if (event.save) {
      try {
        res = await _repo.putSettings(event.settings);
      } catch (_) {
        res = false;
      }
    }

    if (res) {
      emit(SettingsLoaded(settings: event.settings));
    } else {
      emit(SettingsFailedSave(settings: event.settings));
    }
  }
}
