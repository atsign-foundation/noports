import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
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

/// Creates the [Npt] for one connection attempt. Injectable so that tests can
/// drive the start/retry loop without a live daemon.
typedef NptFactory =
    Npt Function({required AtClient atClient, required NptParams params});

class ProfileBloc extends LoggingBloc<ProfileEvent, ProfileState> {
  /// Matches the retry cadence of the npt binary - see `sshnoports/bin/npt.dart`
  static const defaultRetryDelay = Duration(seconds: 5);

  /// How long to wait between keep-alive attempts. Injectable so that tests
  /// don't have to spend it.
  final Duration retryDelay;

  final String uuid;
  final ProfileRepository _repo;
  final NptFactory _createNpt;
  final AtClient Function() _getAtClient;

  /// The [Npt] of the session being started or running, if any. [_onStop] is a
  /// separate handler and cannot reach [_onStart]'s locals, so it needs this to
  /// tear a session down.
  Npt? _activeNpt;

  /// Set by [_onStop] to break [_onStart]'s keep-alive loop.
  bool _stopRequested = false;

  static AtClient _currentAtClient() => AtClientManager.getInstance().atClient;

  ProfileBloc(
    this._repo,
    this.uuid, {
    NptFactory createNpt = Npt.create,
    AtClient Function() getAtClient = _currentAtClient,
    this.retryDelay = defaultRetryDelay,
  }) : _createNpt = createNpt,
       _getAtClient = getAtClient,
       super(ProfileInitial(uuid)) {
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
    _stopRequested = false;
    emit(ProfileStarting(uuid, profile: profile));
    App.navState.currentContext?.read<ProfilesRunningCubit>().prepare(uuid);

    AtClient atClient = _getAtClient();
    final strings = AppLocalizations.of(App.navState.currentContext!)!;

    Atsign? atsign = atClient.getCurrentAtSign()?.toAtsign();
    if (atsign == null) {
      _failStart(emit, profile);
      return;
    }

    SettingsState? currentSettingsState = App.navState.currentContext
        ?.read<SettingsBloc>()
        .state;
    if (currentSettingsState is! SettingsLoadedState) {
      _failStart(emit, profile, reason: strings.settingsCouldNotFetch);
      return;
    }
    var settings = currentSettingsState.settings;

    /// The whole keep-alive loop lives inside this one handler invocation so
    /// that [emit] stays valid for the lifetime of the session. [emit.isDone]
    /// covers the bloc being closed underneath us, e.g. the app quitting
    /// part way through a retry.
    while (!emit.isDone) {
      var failure = await _runSession(emit, profile, atClient, atsign, settings);

      if (_stopRequested || emit.isDone) break;

      if (!profile.keepAlive) {
        if (failure != null) {
          _failStart(emit, profile, reason: failure);
          return;
        }
        break;
      }

      emit(
        ProfileStarting(
          uuid,
          profile: profile,
          status: failure ?? strings.connectionClosed,
        ),
      );
      await Future.delayed(retryDelay);
      if (_stopRequested || emit.isDone) break;
      emit(
        ProfileStarting(
          uuid,
          profile: profile,
          status: strings.connectionRetrying,
        ),
      );
    }

    if (!emit.isDone) emit(ProfileLoaded(uuid, profile: profile));
  }

  /// Runs a single connection attempt through to the end of its session.
  ///
  /// Returns null if the session was established and later ended, otherwise a
  /// display reason for why it could not be established. Always closes the
  /// [Npt] on the way out - that is what releases [Npt.done], and skipping it
  /// on the failure path is what used to wedge this bloc forever.
  Future<String?> _runSession(
    Emitter<ProfileState> emit,
    Profile profile,
    AtClient atClient,
    Atsign atsign,
    Settings settings,
  ) async {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    final running = App.navState.currentContext?.read<ProfilesRunningCubit>();

    Npt? npt;
    StreamSubscription<String>? progressSub;
    StreamSubscription<String>? errorSub;
    try {
      npt = _createNpt(
        atClient: atClient,
        params: profile.toNptParams(
          clientAtsign: atsign,
          rootDomain: atClient.getPreferences()!.rootDomain,
          fallbackRelayAtsign: settings.relayAtsign,
          overrideRelayWithFallback: settings.overrideRelay,
        ),
      );
      _activeNpt = npt;

      void reportProgress(String msg) {
        // Don't drag the UI back to "connecting" once a stop is under way
        if (_stopRequested || emit.isDone) return;
        emit(ProfileStarting(uuid, profile: profile, status: msg));
      }

      progressSub = npt.progressStream?.listen(reportProgress);
      errorSub = npt.logStream?.listen(reportProgress);

      SocketConnector sc = await npt.runInline();

      if (_stopRequested) {
        // Stopped while connecting - this connector was never cached, so
        // nothing else is going to close it
        sc.close();
        return null;
      }

      if (sc.closed) return strings.socketconnectorClosedPrematurely;

      // Save the socket connector to state so it can be used to stop npt later
      running?.cache(uuid, sc);
      emit(ProfileStarted(uuid, profile: profile));

      // Launch the connection URI if provided
      final uri = profile.constructedConnectUri;
      if (uri != null && uri.isNotEmpty) {
        UriHandlerService.handleUri(uri);
      }

      /// Parks here for the lifetime of the session
      await npt.done;
      return null;
    } catch (err) {
      return strings.errorDuringStartupWithDetails(err.toString());
    } finally {
      await npt?.close();
      // Per attempt, not per loop: otherwise this attempt's progress messages
      // would emit into the next attempt's state
      await progressSub?.cancel();
      await errorSub?.cancel();
      _activeNpt = null;
      running?.invalidate(uuid);
    }
  }

  void _failStart(
    Emitter<ProfileState> emit,
    Profile profile, {
    String? reason,
  }) {
    emit(ProfileFailedStart(uuid, profile: profile, reason: reason));
    App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(uuid);
  }

  Future<void> _onStop(
    ProfileStopEvent event,
    Emitter<ProfileState> emit,
  ) async {
    // ProfileStarting is stoppable too, so that a connection attempt which is
    // failing to establish can always be abandoned
    if (state is! ProfileStarted && state is! ProfileStarting) return;
    var profile = (state as ProfileLoadedState).profile;
    _stopRequested = true;
    emit(ProfileStopping(uuid, profile: profile));

    // Releases [_runSession]'s `await npt.done` for a running session. Mid
    // startup it cannot abort the in-flight call, so the loop instead exits
    // once that call settles.
    await _activeNpt?.close();
    App.navState.currentContext?.read<ProfilesRunningCubit>().invalidate(uuid);
  }
}
