import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_core/npt.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:socket_connector/socket_connector.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends LoggingBloc<ProfileEvent, ProfileState> {
  final String uuid;
  final ProfileRepository _repo;
  ProfileBloc(this._repo, this.uuid) : super(ProfileInitial(uuid)) {
    on<ProfileLoadEvent>(_onLoad);
    on<ProfileLoadOrCreateEvent>(_onLoadOrCreate);
    on<ProfileEditEvent>(_onEdit);
    on<ProfileSaveEvent>(_onSave);
    on<ProfileStartEvent>(_onStart);
    on<ProfileStopEvent>(_onStop);
  }
  Future<void> _onLoad(
    ProfileLoadEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading(uuid));

    Profile? profile;
    try {
      profile = await _repo.getProfile(uuid, useCache: event.useCache);
    } catch (_) {
      profile = null;
    }

    if (profile == null) {
      emit(ProfileFailedLoad(uuid));
      return;
    }

    emit(ProfileLoaded(uuid, profile: profile));
  }

  Future<void> _onLoadOrCreate(
    ProfileLoadOrCreateEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading(uuid));

    Profile? profile;
    try {
      profile = await _repo.getProfile(uuid);
    } catch (_) {
      profile = null;
    }

    if (event.copyFrom != null) {
      var json = event.copyFrom!.toJson();
      json["uuid"] = uuid;
      profile = Profile.fromJson(json);
    }

    if (profile == null) {
      emit(
        ProfileLoaded(
          uuid,
          profile: Profile(
            uuid,
            displayName: '',
            sshnpdAtsign: '',
            relayAtsign: '',
            deviceName: '',
            remotePort: 3389,
            localPort: 0,
          ),
        ),
      );
      return;
    }

    emit(ProfileLoaded(uuid, profile: profile));
  }

  Future<void> _onEdit(
    ProfileEditEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is! ProfileLoaded && state is! ProfileFailedSave) {
      return;
    }
    emit(ProfileLoaded(uuid, profile: event.profile));
  }

  FutureOr<void> _onSave(
    ProfileSaveEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading(uuid));
    bool res;
    try {
      res = await _repo.putProfile(event.profile);
    } catch (_) {
      res = false;
    }

    if (res) {
      App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
        uuid,
      );

      var listBloc = App.navState.currentContext?.read<ProfileListBloc>();
      if (listBloc != null && listBloc.state is ProfileListLoaded) {
        var profiles = (listBloc.state as ProfileListLoaded).profiles;
        if (!profiles.contains(uuid)) {
          listBloc.add(ProfileListUpdateEvent([...profiles, uuid]));
        }
      }
      var context = wrapperNav.currentContext;
      if (context != null && context.mounted) {
        wrapperNav.currentState!.pop();
      }
      emit(ProfileLoaded(uuid, profile: event.profile));
    } else {
      App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
        uuid,
      );
      emit(ProfileFailedSave(uuid, profile: event.profile));
    }
  }

  Future<void> _onStart(
    ProfileStartEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is! ProfileLoadedState ||
        state is ProfileStarting ||
        state is ProfileStopping ||
        state is ProfileStarted) {
      return;
    }
    // ProfileLoaded and ProfileFailedSave are both ProfileLoadedState
    var profile = (state as ProfileLoadedState).profile;
    emit(ProfileStarting(uuid, profile: profile));
    App.navState.currentContext?.read<ProfilesRunningCubit>().prepare(uuid);

    AtClient atClient = AtClientManager.getInstance().atClient;

    String? atSign = atClient.getCurrentAtSign();
    if (atSign == null) {
      emit(ProfileFailedStart(uuid, profile: profile));
      App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
        uuid,
      );
      return;
    }

    SettingsState? currentSettingsState = App.navState.currentContext
        ?.read<SettingsBloc>()
        .state;
    if (currentSettingsState is! SettingsLoadedState) {
      emit(
        ProfileFailedStart(
          uuid,
          profile: profile,
          reason: "Couldn't fetch settings",
        ),
      );
      App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
        uuid,
      );
      return;
    }
    var settings = currentSettingsState.settings;

    void Function()? cancel;
    SocketConnector? sc;
    Npt? npt;
    try {
      npt = Npt.create(
        atClient: atClient,
        params: profile.toNptParams(
          clientAtsign: atSign,
          rootDomain: atClient.getPreferences()!.rootDomain,
          fallbackRelayAtsign: settings.relayAtsign,
          overrideRelayWithFallback: settings.overrideRelay,
        ),
      );

      var progressSub = npt.progressStream?.listen((msg) {
        emit(ProfileStarting(uuid, profile: profile, status: msg));
      });

      var errorSub = npt.logStream?.listen((err) {
        emit(ProfileStarting(uuid, profile: profile, status: err));
      });

      cancel = () {
        progressSub?.cancel();
        progressSub = null;

        errorSub?.cancel();
        errorSub = null;

        if (sc is SocketConnector) sc.close();
      };

      sc = await npt.runInline();

      if (sc is TimedOutSocketConnector) {
        cancel();
        emit(
          ProfileFailedStart(
            uuid,
            profile: profile,
            reason: 'Npt startup timedout',
          ),
        );
        App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
          uuid,
        );
        return;
      }

      if (sc.closed) {
        cancel();
        emit(
          ProfileFailedStart(
            uuid,
            profile: profile,
            reason: 'Socketconnector closed prematurely',
          ),
        );
        App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
          uuid,
        );
        return;
      }

      // Save the socket connector to state so it can be used to stop npt later
      App.navState.currentContext?.read<ProfilesRunningCubit>().cache(uuid, sc);
      emit(ProfileStarted(uuid, profile: profile));
    } catch (err) {
      cancel?.call();
      emit(
        ProfileFailedStart(
          uuid,
          profile: profile,
          reason: 'Error during startup: $err',
        ),
      );
      App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
        uuid,
      );
    } finally {
      if (npt != null) {
        await npt.done;
        cancel?.call();
        App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
          uuid,
        );
 
        // If keep-alive is enabled and the session ended (but the profile wasn't explicitly stopped),
        // retry the connection after a delay
        if (profile.keepAlive && state is ProfileStarted) {
          await _retryConnection(emit, profile, atClient, atSign, settings);
        } else {
          emit(ProfileLoaded(uuid, profile: profile));
        }
      }
    }
  }

  Future<void> _retryConnection(
    Emitter<ProfileState> emit,
    Profile profile,
    AtClient atClient,
    String atSign,
    Settings settings,
  ) async {
    // Wait 5 seconds before retrying, similar to npt binary
    await Future.delayed(const Duration(seconds: 5));

    // Check if the profile was stopped during the delay
    if (state is! ProfileStarted) {
      emit(ProfileLoaded(uuid, profile: profile));
      return;
    }

    // Emit starting state for retry
    emit(ProfileStarting(uuid, profile: profile, status: 'Retrying connection (keep-alive)...'));

    void Function()? cancel;
    SocketConnector? sc;
    Npt? npt;

    try {
      npt = Npt.create(
        atClient: atClient,
        params: profile.toNptParams(
          clientAtsign: atSign,
          rootDomain: atClient.getPreferences()!.rootDomain,
          fallbackRelayAtsign: settings.relayAtsign,
          overrideRelayWithFallback: settings.overrideRelay,
        ),
      );

      var progressSub = npt.progressStream?.listen((msg) {
        emit(ProfileStarting(uuid, profile: profile, status: msg));
      });

      var errorSub = npt.logStream?.listen((err) {
        emit(ProfileStarting(uuid, profile: profile, status: err));
      });

      cancel = () {
        progressSub?.cancel();
        progressSub = null;

        errorSub?.cancel();
        errorSub = null;

        if (sc is SocketConnector) sc.close();
      };

      sc = await npt.runInline();

      if (sc is TimedOutSocketConnector) {
        cancel();
        // For retry, just log the timeout and let it retry again
        emit(ProfileStarting(uuid, profile: profile, status: 'Connection timed out, will retry...'));
      } else if (sc.closed) {
        cancel();
        emit(ProfileStarting(uuid, profile: profile, status: 'Connection closed, will retry...'));
      } else {
        // Success - cache the connector and emit started state
        App.navState.currentContext?.read<ProfilesRunningCubit>().cache(uuid, sc);
        emit(ProfileStarted(uuid, profile: profile));
      }
    } catch (err) {
      cancel?.call();
      emit(ProfileStarting(uuid, profile: profile, status: 'Retry failed: $err, will retry...'));
    } finally {
      if (npt != null) {
        await npt.done;
        cancel?.call();
        App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
          uuid,
        );
        
        // Continue retrying if keep-alive is still enabled and profile is still "started"
        if (profile.keepAlive && state is ProfileStarted) {
          await _retryConnection(emit, profile, atClient, atSign, settings);
        } else {
          emit(ProfileLoaded(uuid, profile: profile));
        }
      }
    }
  }

  Future<void> _onStop(
    ProfileStopEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is! ProfileStarted) return;
    var profile = (state as ProfileStarted).profile;
    emit(ProfileStopping(uuid, profile: profile));
    App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(uuid);
  }
}

class TimedOutSocketConnector extends SocketConnector {}
