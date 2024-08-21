import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_core/npt.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
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
    on<ProfileStartEvent>(_onStart);
    on<ProfileStopEvent>(_onStop);
  }
  Future<void> _onLoad(
      ProfileLoadEvent event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading(uuid));

    Profile? profile;
    try {
      profile = await _repo.getProfile(uuid);
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
      ProfileLoadOrCreateEvent event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading(uuid));

    Profile? profile;
    try {
      profile = await _repo.getProfile(uuid);
    } catch (_) {
      profile = null;
    }

    if (profile == null) {
      emit(ProfileLoaded(
        uuid,
        profile: Profile(
          uuid,
          displayName: '',
          sshnpdAtsign: '',
          relayAtsign: '',
          deviceName: '',
          remotePort: 0,
          localPort: 0,
        ),
      ));
      return;
    }

    emit(ProfileLoaded(uuid, profile: profile));
  }

  Future<void> _onEdit(
      ProfileEditEvent event, Emitter<ProfileState> emit) async {
    if (state is! ProfileLoaded && state is! ProfileFailedSave) {
      return;
    }

    bool res = true; // true so we emit loaded state if not saving
    if (event.save) {
      emit(ProfileLoading(uuid));
      try {
        res = await _repo.putProfile(event.profile);
      } catch (_) {
        res = false;
      }
    }

    // Make sure to wipe profile.npt and profile.socketConnector since we changed the config so they are invalid
    if (res) {
      App.navState.currentContext
          ?.read<ProfilesRunningCubit>()
          .invalidate(uuid);

      if (event.addToProfilesList) {
        var listBloc = App.navState.currentContext?.read<ProfileListBloc>();
        if (listBloc != null && listBloc.state is ProfileListLoaded) {
          var profiles = (listBloc.state as ProfileListLoaded).profiles;
          if (!profiles.contains(uuid)) {
            listBloc.add(ProfileListUpdateEvent([...profiles, uuid]));
          }
        }
        if (event.popNavAfterAddToProfilesList) {
          var context = App.navState.currentContext;
          if (context != null && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      }
      emit(ProfileLoaded(uuid, profile: event.profile));
    } else {
      App.navState.currentContext
          ?.read<ProfilesRunningCubit>()
          .invalidate(uuid);
      emit(ProfileFailedSave(uuid, profile: event.profile));
    }
  }

  Future<void> _onStart(
      ProfileStartEvent event, Emitter<ProfileState> emit) async {
    if (state is! ProfileLoadedState ||
        state is ProfileStarting ||
        state is ProfileStopping ||
        state is ProfileStarted) return;
    // ProfileLoaded and ProfileFailedSave are both ProfileLoadedState
    var profile = (state as ProfileLoadedState).profile;
    emit(ProfileStarting(uuid, profile: profile));

    AtClient atClient = AtClientManager.getInstance().atClient;

    String? atSign = atClient.getCurrentAtSign();
    if (atSign == null) {
      emit(ProfileFailedStart(uuid, profile: profile));
      return;
    }

    SettingsState? currentSettingsState =
        App.navState.currentContext?.read<SettingsBloc>().state;
    if (currentSettingsState is! SettingsLoadedState) {
      emit(ProfileFailedStart(
        uuid,
        profile: profile,
        reason: "Couldn't fetch settings",
      ));
      return;
    }
    var settings = currentSettingsState.settings;

    void Function()? cancelSubs;
    SocketConnector? sc;
    Npt? npt;
    try {
      npt = Npt.create(
        atClient: atClient,
        params: profile.toNptParams(
          clientAtsign: atSign,
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

      cancelSubs = () {
        progressSub?.cancel();
        progressSub = null;

        errorSub?.cancel();
        errorSub = null;
      };

      sc = await npt
          .runInline()
          // Todo - make this timeout configurable from settings
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return TimedOutSocketConnector();
        },
      );

      if (sc is TimedOutSocketConnector) {
        cancelSubs();
        emit(ProfileFailedStart(
          uuid,
          profile: profile,
          reason: 'Npt startup timedout',
        ));
        return;
      }

      if (sc.closed) {
        cancelSubs();
        emit(ProfileFailedStart(
          uuid,
          profile: profile,
          reason: 'Socketconnector closed prematurely',
        ));
        return;
      }

      // Save the socket connector to state so it can be used to stop npt later
      App.navState.currentContext?.read<ProfilesRunningCubit>().cache(uuid, sc);
      emit(ProfileStarted(uuid, profile: profile));
    } catch (err) {
      cancelSubs?.call();
      emit(ProfileFailedStart(
        uuid,
        profile: profile,
        reason: 'Error during startup: $err',
      ));
    } finally {
      await npt?.done;
      cancelSubs?.call();
      App.navState.currentContext
          ?.read<ProfilesRunningCubit>()
          .invalidate(uuid);
      emit(ProfileLoaded(uuid, profile: profile));
    }
  }

  Future<void> _onStop(
      ProfileStopEvent event, Emitter<ProfileState> emit) async {
    if (state is! ProfileStarted) return;
    var profile = (state as ProfileStarted).profile;
    emit(ProfileStopping(uuid, profile: profile));
    App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(uuid);
  }
}

class TimedOutSocketConnector extends SocketConnector {}
