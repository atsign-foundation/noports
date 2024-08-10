import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_core/npt.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/profile/profile.dart';
import 'package:npt_flutter/settings/settings.dart';
import 'package:socket_connector/socket_connector.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final String uuid;
  final ProfileRepository _repo;
  ProfileBloc(this._repo, this.uuid) : super(ProfileInitial(uuid)) {
    on<ProfileLoadEvent>(_onLoad);
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
      emit(ProfileLoaded(
        uuid,
        profile: event.profile.copyWith(socketConnector: null),
      ));
    } else {
      emit(ProfileFailedSave(
        uuid,
        profile: event.profile.copyWith(socketConnector: null),
      ));
    }
  }

  Future<void> _onStart(
      ProfileStartEvent event, Emitter<ProfileState> emit) async {
    if (state is! ProfileLoaded && state is! ProfileFailedSave) return;
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
    String fallbackRelayAtsign = settings.relayAtsign;
    String? overrideRelayAtsign =
        settings.overrideRelay ? fallbackRelayAtsign : null;

    void Function()? cancelSubs;
    SocketConnector? sc;
    Npt? npt;
    try {
      npt = Npt.create(
        atClient: atClient,
        params: profile.toNptParams(
          clientAtsign: atSign,
          fallbackRelayAtsign: fallbackRelayAtsign,
          overrideRelayAtsign: overrideRelayAtsign,
        ),
      );

      profile = profile.copyWith(
        logs: profile.logs ?? ProfileLogs(),
      );

      // TODO
      // need to do one master logger which tracks all profile info
      var progressSub = npt.progressStream?.listen((msg) {
        profile.logs?.logProgress(msg);
        // print(msg);
        // These logs aren't being reported correctly
        emit(ProfileStarting(uuid, profile: profile));
      });

      var errorSub = npt.logStream?.listen((err) {
        profile.logs?.logError(err);
        emit(ProfileStarting(uuid, profile: profile));
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
          .timeout(const Duration(seconds: 10), onTimeout: () {
        return TimedOutSocketConnector();
      });

      if (sc is TimedOutSocketConnector) {
        emit(ProfileFailedStart(
          uuid,
          profile: profile,
          reason: 'Npt startup timedout',
        ));
        return;
      }

      if (sc.closed) {
        emit(ProfileFailedStart(
          uuid,
          profile: profile,
          reason: 'Socketconnector closed prematurely',
        ));
        return;
      }

      // Save the socket connector to state so it can be used to stop npt later
      profile = profile.copyWith(socketConnector: sc);
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
      profile = profile.copyWith(socketConnector: null);
      emit(ProfileLoaded(uuid, profile: profile));
    }
  }

  Future<void> _onStop(
      ProfileStopEvent event, Emitter<ProfileState> emit) async {
    if (state is! ProfileStarted) return;
    var profile = (state as ProfileStarted).profile;
    emit(ProfileStopping(uuid, profile: profile));
    profile.socketConnector?.close();
  }
}

class TimedOutSocketConnector extends SocketConnector {}
