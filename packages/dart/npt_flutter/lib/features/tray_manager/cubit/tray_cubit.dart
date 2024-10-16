import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/routes.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

part 'tray_cubit.g.dart';
part 'tray_state.dart';

(String, void Function(MenuItem)) getAction(TrayAction action) => switch (action) {
      TrayAction.showDashboard => ('Show Window', (_) => windowManager.focus()),
      TrayAction.showSettings => (
          'Settings',
          (_) {
            windowManager.focus().then((_) {
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
            });
          }
        ),
      TrayAction.quitApp => (
          'Quit',
          (_) async {
            await windowManager.destroy();
            exit(0);
          }
        ),
    };

@JsonEnum(alwaysCreate: true)
enum TrayAction {
  showDashboard,
  showSettings,
  quitApp;

  static bool isTrayAction(String key) {
    return _$TrayActionEnumMap.values.contains(key);
  }

  MenuItem get menuItem {
    final (label, callback) = getAction(this);
    return MenuItem(
      key: _$TrayActionEnumMap[this],
      label: label,
      onClick: callback,
    );
  }
}

class TrayCubit extends LoggingCubit<TrayState> {
  TrayCubit() : super(const TrayInitial());

  Future<void> initialize() async {
    if (state is! TrayInitial) return;
    var context = App.navState.currentContext;
    if (context == null) return;
    var showSettings = context.read<OnboardingCubit>().getStatus() == OnboardingStatus.onboarded;

    await reloadIcon();

    await trayManager.setContextMenu(Menu(
      items: [
        TrayAction.showDashboard.menuItem,
        if (showSettings) TrayAction.showSettings.menuItem,
        TrayAction.quitApp.menuItem,
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

  Future<void> reload() async {
    var context = App.navState.currentContext;
    if (context == null) return;
    var init = initialize();

    /// Access the context before any awaited function calls
    var showSettings = context.read<OnboardingCubit>().getStatus() == OnboardingStatus.onboarded;
    var favoriteBloc = context.read<FavoriteBloc>();
    var profilesList = context.read<ProfileListBloc>();

    await init;

    /// Get favorites
    if (favoriteBloc.state is! FavoritesLoaded) return;
    var favorites = (favoriteBloc.state as FavoritesLoaded).favorites;

    /// Get profiles uuid list
    if (profilesList.state is! ProfileListLoaded) return;
    var profiles = (profilesList.state as ProfileListLoaded).profiles;

    /// Generate the new menu based on current state
    var favMenuItems = await Future.wait(
      favorites.where((fav) => fav.isLoadedInProfiles(profiles)).map((fav) async {
        /// Make sure to call [e.displayName] and [e.isRunning] only once to
        /// ensure good performance - these getters call a bunch of nested
        /// information from elsewhere in the app state
        var displayName = await fav.displayName;
        var status = fav.status;
        var label = '$displayName $status';
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
        TrayAction.showDashboard.menuItem,
        if (showSettings) TrayAction.showSettings.menuItem,
        TrayAction.quitApp.menuItem,
      ],
    ));
    emit(TrayLoaded(favorites: favorites));
  }
}
