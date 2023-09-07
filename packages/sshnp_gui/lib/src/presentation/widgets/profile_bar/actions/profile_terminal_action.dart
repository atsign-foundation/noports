import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshrv/sshrv.dart';
import 'package:sshnp_gui/src/controllers/nav_rail_controller.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/dialog/sshnp_result_alert_dialog.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

class ProfileTerminalAction extends ConsumerStatefulWidget {
  final SSHNPParams params;
  const ProfileTerminalAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileTerminalAction> createState() => _ProfileTerminalActionState();
}

class _ProfileTerminalActionState extends ConsumerState<ProfileTerminalAction> {
  Future<void> onPressed() async {
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final sshnp = await SSHNP.fromParams(
        widget.params,
        atClient: AtClientManager.getInstance().atClient,
        sshrvGenerator: SSHRV.pureDart,
      );

      await sshnp.init();
      final result = await sshnp.run();
      if (result is SSHNPFailed) {
        throw result;
      }

      /// Issue a new session id
      final sessionId = ref.watch(terminalSessionController.notifier).createSession();

      /// Create the session controller for the new session id
      final sessionController = ref.watch(terminalSessionFamilyController(sessionId).notifier);

      if (result is SSHNPCommandResult) {
        /// Set the command for the new session
        sessionController.setProcess(command: result.command, args: result.args);
        ref.read(navRailController.notifier).setRoute(AppRoute.terminal);
        if (mounted) {
          context.pushReplacementNamed(AppRoute.terminal.name);
        }
      }
    } catch (e) {
      if (mounted) {
        context.pop();
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => SSHNPResultAlertDialog(
            result: e.toString(),
            title: 'SSHNP Failed',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        await onPressed();
      },
      icon: const Icon(Icons.terminal),
    );
  }
}
