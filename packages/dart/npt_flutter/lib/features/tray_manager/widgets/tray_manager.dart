import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    var cubit = context.read<TrayCubit>();
    if (cubit.state is TrayInitial) {
      cubit.initialize();
    }
    return widget.child;
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
