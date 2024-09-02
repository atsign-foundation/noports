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
                if (cubit.state is! Onboarded) return;
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
    var showSettings = context.read<OnboardingCubit>().state is Onboarded;

    await trayManager.setIcon(
      Platform.isWindows ? Constants.icoIcon : Constants.pngIcon,
    );

    await trayManager.setContextMenu(Menu(
      items: [
        TrayAction.showDashboard.menuItem,
        if (showSettings) TrayAction.showSettings.menuItem,
        TrayAction.quitApp.menuItem,
      ],
    ));
    emit(const TrayLoaded());
  }

  Future<void> reloadFavorites() async {
    var context = App.navState.currentContext;
    if (context == null) return;
    var showSettings = context.read<OnboardingCubit>().state is Onboarded;
    var favoriteBloc = context.read<FavoriteBloc>();
    var profilesList = context.read<ProfileListBloc>();
    if (state is TrayInitial) {
      await initialize();
    }
    if (favoriteBloc.state is! FavoritesLoaded) return;
    var favorites = (favoriteBloc.state as FavoritesLoaded).favorites;
    if (profilesList.state is! ProfileListLoaded) return;
    var profiles = (profilesList.state as ProfileListLoaded).profiles;
    var favMenuItems = await Future.wait(
      favorites.where((e) => e.isLoadedInProfiles(profiles)).map((e) async {
        /// Make sure to call [e.displayName] and [e.isRunning] only once to
        /// ensure good performance - these getters call a bunch of nested
        /// information from elsewhere in the app state
        var displayName = await e.displayName;
        var status = e.status;
        var label = '$displayName $status';
        return MenuItem(
          label: label,
          toolTip: status,
          onClick: (_) => e.toggle(),
        );
      }),
    );
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
