import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/profile_status.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

part 'tray_cubit.g.dart';
part 'tray_state.dart';

@JsonEnum(alwaysCreate: true)
enum TrayAction {
  showDashboard,
  showSettings,
  quitApp;

  static bool isTrayAction(String key) {
    return _$TrayActionEnumMap.values.contains(key);
  }
}

class TrayCubit extends LoggingCubit<TrayState> {
  TrayCubit() : super(const TrayInitial());

  Future<void> initialize({AppLocalizations? localizations}) async {
    if (state is! TrayInitial || localizations == null) return;
    var context = App.navState.currentContext;
    if (context == null) return;
    var showSettings = context.read<OnboardingCubit>().getStatus() == OnboardingStatus.onboarded;

    await reloadIcon();

    await trayManager.setContextMenu(Menu(
      items: [
        _getMenuItem(TrayAction.showDashboard, localizations),
        if (showSettings) _getMenuItem(TrayAction.showSettings, localizations),
        _getMenuItem(TrayAction.quitApp, localizations),
      ],
    ));
    emit(const TrayLoaded());
  }

  Future<void> reloadIcon() async {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    await trayManager.setIcon(switch (brightness) {
      Brightness.light => Platform.isWindows ? Constants.icoIconLight : Constants.pngIconLight,
      Brightness.dark => Platform.isWindows ? Constants.icoIconDark : Constants.pngIconDark,
    });
  }

  MenuItem _getMenuItem(TrayAction action, AppLocalizations localizations) {
    final (label, callback) = _getAction(action, localizations);
    return MenuItem(
      key: _$TrayActionEnumMap[action],
      label: label,
      onClick: callback,
    );
  }

  (String, void Function(MenuItem)) _getAction(TrayAction action, AppLocalizations localizations) {
    return switch (action) {
      TrayAction.showDashboard => (localizations.showWindow, (_) => windowManager.show(inactive: true)),
      TrayAction.showSettings => (
          localizations.settings,
          (_) => windowManager.show(inactive: true).then((_) {
                var context = App.navState.currentContext;
                if (context == null) return;
                if (context.mounted) {
                  var cubit = context.read<OnboardingCubit>();
                  if (cubit.getStatus() != OnboardingStatus.onboarded) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    Routes.settings,
                    (route) => route.isFirst,
                  );
                }
              })
        ),
      TrayAction.quitApp => (
          localizations.quit,
          (_) async {
            await windowManager.destroy();
            exit(0);
          }
        ),
    };
  }

  Future<void> reload({
    AppLocalizations? localizations,
    FavoritesState? favoriteState,
    ProfileListState? profileListState,
    ProfilesRunningState? profilesRunningState,
    OnboardingState? onboardingState,
    ProfileState? profileState,
  }) async {
    var context = App.navState.currentContext;
    if (context == null) return;

    localizations ??= AppLocalizations.of(context);
    if (localizations == null) return;
    var init = initialize(localizations: localizations);

    /// Access the context before any awaited function calls
    favoriteState ??= context.read<FavoriteBloc>().state;
    profileListState ??= context.read<ProfileListBloc>().state;
    onboardingState ??= context.read<OnboardingCubit>().state;
    var showSettings = onboardingState.status == OnboardingStatus.onboarded;

    await init;

    // Guard against empty values
    if (favoriteState is! FavoritesLoaded) return;
    if (profileListState is! ProfileListLoaded) return;

    /// Generate the new menu based on current state
    var favMenuItems = await Future.wait(
      favoriteState.favorites
          .where((fav) => fav.isLoadedInProfiles((profileListState as ProfileListLoaded).profiles))
          .map((fav) async {
        /// Make sure to call [e.displayName] and [e.isRunning] only once to
        /// ensure good performance - these getters call a bunch of nested
        /// information from elsewhere in the app state

        var displayName = (profileState != null && profileState is ProfileLoadedState && profileState.uuid == fav.uuid)
            ? profileState.profile.displayName
            : await fav.displayName;

        final status = fav.status;

        final String statusIcon;
        if (status == ProfileStatus.off.message) {
          statusIcon = ProfileStatus.off.emoji;
        } else if (status == ProfileStatus.starting.message) {
          statusIcon = ProfileStatus.starting.emoji;
        } else if (status?.contains(ProfileStatus.on.message) ?? false) {
          statusIcon = ProfileStatus.on.emoji;
        } else if (status == ProfileStatus.stopping.message) {
          statusIcon = ProfileStatus.stopping.emoji;
        } else if (status == ProfileStatus.loading.message) {
          statusIcon = ProfileStatus.loading.emoji;
        } else if (status == ProfileStatus.failedToStart.message) {
          statusIcon = ProfileStatus.failedToStart.emoji;
        } else if (status == ProfileStatus.failedToLoad.message) {
          statusIcon = ProfileStatus.failedToLoad.emoji;
        } else {
          statusIcon = '';
        }
        var label = '$statusIcon $displayName';
        return MenuItem(
          label: label,
          toolTip: status,
          onClick: (_) => fav.toggle(),
        );
      }),
    );

    /// PERF: We should conditionally call setContextMenu if there was a state
    /// change which resulted in an actual change to the favorites list.
    /// Currently we just force call updates which is really inefficient

    /// Set the new menu
    await trayManager.setContextMenu(Menu(
      items: [
        ...favMenuItems,
        MenuItem.separator(),
        _getMenuItem(TrayAction.showDashboard, localizations),
        if (showSettings) _getMenuItem(TrayAction.showSettings, localizations),
        _getMenuItem(TrayAction.quitApp, localizations),
      ],
    ));
    emit(const TrayLoaded());
  }
}
