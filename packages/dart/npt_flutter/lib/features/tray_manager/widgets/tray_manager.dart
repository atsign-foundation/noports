import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/tray_manager/tray_manager.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// This is the stateful widget that listens to the tray and window state
/// It wraps the whole [MaterialApp] so that it can be used from anywhere
class TrayManager extends StatefulWidget {
  final Widget child;
  final Locale locale;
  const TrayManager({required this.child, required this.locale, super.key});

  @override
  State<TrayManager> createState() => _TrayManagerState();
}

class _TrayManagerState extends State<TrayManager>
    with TrayListener, WindowListener {
  /// Must strongly type [context] here or Dart will infer the wrong type for
  /// the [.read()] extension which causes an error
  void reloadTray(BuildContext context, Loggable state) async {
    var cubit = context.read<TrayCubit>();
    switch (state) {
      case FavoritesState _:
        cubit.reload(favoriteState: state);
      case ProfileListState _:
        cubit.reload(profileListState: state);
      case ProfilesRunningState _:
        cubit.reload(profilesRunningState: state);
      case SettingsLoadedState _:
        var localizations = await AppLocalizations.delegate
            .load(state.settings.language.locale);
        cubit.reload(localizations: localizations);
      case ProfileState _:
        cubit.reload(profileState: state);
      default:
        cubit.reload(localizations: AppLocalizations.of(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    var trayCubit = context.read<TrayCubit>();
    if (trayCubit.state is TrayInitial) {
      trayCubit.initialize(localizations: AppLocalizations.of(context));
    }

    var profileCacheCubit = context.read<ProfileCacheCubit>();

    /// This selector reduces the number of times we reload profiles-map
    return BlocSelector<ProfileListBloc, ProfileListState, Iterable<String>>(
      selector: (state) {
        if (state is ProfileListLoaded) return state.profiles;
        return List.empty();
      },
      builder: (context, profiles) => MultiBlocListener(
        listeners: [
          /// Reload the tray whenever one of the following states changes
          /// Note: this doesn't always result in a change to the tray, but we
          /// still have to check
          BlocListener<FavoriteBloc, FavoritesState>(
            listener: reloadTray,
          ),
          BlocListener<ProfileListBloc, ProfileListState>(
            listener: reloadTray,
          ),
          BlocListener<ProfilesRunningCubit, ProfilesRunningState>(
            listener: reloadTray,
          ),
          BlocListener<SettingsBloc, SettingsState>(
              listener: reloadTray,
              // Only call listener when the language changes in settings
              listenWhen: (prev, next) {
                if (prev is SettingsLoadedState &&
                    next is SettingsLoadedState) {
                  return prev.settings.language != next.settings.language;
                }
                // This may cause some extra reloading (very occasionally, settings shouldn't change often)
                // but it should catch all of the edge cases
                return prev is SettingsLoadedState ||
                    next is SettingsLoadedState;
              }),

          /// Yeah I really hate this... an indefinite list of listeners
          /// but it's the only way to decouple the profiles from having to know
          /// about the tray
          ///
          /// The tray should know about profiles, profiles should not know
          /// about tray. Even if it is slightly more costly in performance, the
          /// calls where we take the performance hit are:
          /// 1. In an asynchronous background task (who cares)
          /// 2. Worth it, compared to the potential maintenance costs
          ...profiles.map((uuid) => BlocProvider<ProfileBloc>(
                key: Key("TrayManager-$uuid"),
                create: (context) => profileCacheCubit.getProfileBloc(uuid),
                child: BlocListener<ProfileBloc, ProfileState>(
                  listener: reloadTray,
                ),
              )),
        ],
        child: widget.child,
      ),
    );
  }

  @override
  void initState() {
    windowManager.addListener(this);
    trayManager.addListener(this);
    super.initState();
    windowManager.setPreventClose(true);
    windowManager.setVisibleOnAllWorkspaces(true);
    var dispatcher = SchedulerBinding.instance.platformDispatcher;

    // This callback is called every time the brightness changes.
    dispatcher.onPlatformBrightnessChanged = () {
      App.navState.currentContext?.read<TrayCubit>().reloadIcon();
    };
  }

  @override
  void dispose() {
    windowManager.addListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onWindowFocus() {
    // Make sure to call once.
    setState(() {});
    // do something
  }

  @override
  void onWindowClose() async {
    var onboardingCubit = App.navState.currentContext?.read<OnboardingCubit>();
    if (onboardingCubit?.state.status == OnboardingStatus.onboarded) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
      exit(0);
    }
  }
}
