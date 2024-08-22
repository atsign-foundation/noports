import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/tray_manager/tray_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// This is the stateful widget that listens to the tray and window state
/// It wraps the whole [MaterialApp] so that it can be used from anywhere
class TrayManager extends StatefulWidget {
  final Widget child;
  const TrayManager({required this.child, super.key});

  @override
  State<TrayManager> createState() => _TrayManagerState();
}

class _TrayManagerState extends State<TrayManager>
    with TrayListener, WindowListener {
  @override
  Widget build(BuildContext context) {
    var trayCubit = context.read<TrayCubit>();
    if (trayCubit.state is TrayInitial) {
      trayCubit.initialize();
    }

    void reloadTray(context, _) {
      context.read<TrayCubit>().reloadFavorites();
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
          BlocListener<FavoriteBloc, FavoritesState>(
            listener: reloadTray,
          ),
          BlocListener<ProfileListBloc, ProfileListState>(
            listener: reloadTray,
          ),
          BlocListener<ProfilesRunningCubit, ProfilesRunningState>(
            listener: reloadTray,
          ),

          /// Yeah I really hate this... but it's the only way to decouple the
          /// profiles from having to know about the tray tray should know about
          /// profiles, profiles should not know about tray
          ...profiles.map((uuid) => BlocProvider<ProfileBloc>(
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
    await windowManager.hide();
  }
}
