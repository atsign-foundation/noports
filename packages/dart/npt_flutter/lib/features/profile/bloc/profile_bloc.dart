import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_core/npt.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/uri_handler_service.dart';
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
    final strings = AppLocalizations.of(App.navState.currentContext!)!;

    Atsign? atsign = atClient.getCurrentAtSign()?.toAtsign();
    if (atsign == null) {
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
          reason: strings.settingsCouldNotFetch,
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
          clientAtsign: atsign,
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
            reason: strings.nptStartupTimedout,
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
            reason: strings.socketconnectorClosedPrematurely,
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

      // Launch the connection URI if provided
      final uri = profile.constructedConnectUri;
      if (uri != null && uri.isNotEmpty) {
        UriHandlerService.handleUri(uri);
      }
    } catch (err) {
      cancel?.call();
      emit(
        ProfileFailedStart(
          uuid,
          profile: profile,
          reason: strings.errorDuringStartupWithDetails(err.toString()),
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
          await _retryConnection(emit, profile, atClient, atsign, settings);
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
    Atsign atsign,
    Settings settings,
  ) async {
    // Wait 5 seconds before retrying, similar to npt binary
    await Future.delayed(const Duration(seconds: 5));

    // Check if the profile was stopped during the delay
    if (state is! ProfileStarted) {
      emit(ProfileLoaded(uuid, profile: profile));
      return;
    }
    final strings = AppLocalizations.of(App.navState.currentContext!)!;

    // Emit starting state for retry
    emit(
      ProfileStarting(
        uuid,
        profile: profile,
        status: strings.connectionRetrying,
      ),
    );

    void Function()? cancel;
    SocketConnector? sc;
    Npt? npt;

    try {
      npt = Npt.create(
        atClient: atClient,
        params: profile.toNptParams(
          clientAtsign: atsign,
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
        emit(
          ProfileStarting(
            uuid,
            profile: profile,
            status: strings.connectionTimedOut,
          ),
        );
      } else if (sc.closed) {
        cancel();
        emit(
          ProfileStarting(
            uuid,
            profile: profile,
            status: strings.connectionClosed,
          ),
        );
      } else {
        // Success - cache the connector and emit started state
        App.navState.currentContext?.read<ProfilesRunningCubit>().cache(
          uuid,
          sc,
        );
        emit(ProfileStarted(uuid, profile: profile));

        // Launch the connection URI if provided
        final uri = profile.constructedConnectUri;
        if (uri != null && uri.isNotEmpty) {
          UriHandlerService.handleUri(uri);
        }
      }
    } catch (err) {
      cancel?.call();
      emit(
        ProfileStarting(
          uuid,
          profile: profile,
          status: strings.retryFailedWithDetails(err.toString()),
        ),
      );
    } finally {
      if (npt != null) {
        await npt.done;
        cancel?.call();
        App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(
          uuid,
        );

        // Continue retrying if keep-alive is still enabled and profile is still "started"
        if (profile.keepAlive && state is ProfileStarted) {
          await _retryConnection(emit, profile, atClient, atsign, settings);
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
