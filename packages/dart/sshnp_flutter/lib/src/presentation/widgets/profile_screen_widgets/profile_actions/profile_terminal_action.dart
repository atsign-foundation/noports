import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_action_button.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class ProfileTerminalAction extends ConsumerStatefulWidget {
  final SshnpParams params;
  const ProfileTerminalAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileTerminalAction> createState() => _ProfileTerminalActionState();
}

class _ProfileTerminalActionState extends ConsumerState<ProfileTerminalAction> {
  Future<void> showProgress(String status) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          gapH16,
          Text(status),
        ],
      )),
    );
  }

  Future<void> onPressed() async {
    ref.read(navigationRailController.notifier).setRoute(AppRoute.terminal);
    if (mounted) {
      context.pushReplacementNamed(AppRoute.terminal.name, extra: {'params': widget.params, 'runShell': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileActionButton(onPressed: onPressed, icon: const Icon(Icons.terminal));
  }
}
