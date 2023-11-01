import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_action_button.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';

class ProfileTerminalAction extends ConsumerStatefulWidget {
  final SshnpParams params;
  const ProfileTerminalAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileTerminalAction> createState() =>
      _ProfileTerminalActionState();
}

class _ProfileTerminalActionState extends ConsumerState<ProfileTerminalAction> {
  Future<void> onPressed() async {
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
            const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      SshnpParams params = SshnpParams.merge(
        widget.params,
        SshnpPartialParams(
          legacyDaemon: false,
          sshClient: SupportedSshClient.dart,
        ),
      );

      // TODO ensure that this keyPair gets uploaded to the app first
      AtClient atClient = AtClientManager.getInstance().atClient;
      DartSSHKeyUtil keyUtil = DartSSHKeyUtil();
      AtSshKeyPair keyPair = await keyUtil.getKeyPair(
        identifier: params.identityFile ??
            'id_${atClient.getCurrentAtSign()!.replaceAll('@', '')}',
      );

      final sshnp = Sshnp.forwardPureDart(
        params: params,
        atClient: atClient,
        identityKeyPair: keyPair,
      );

      await sshnp.initialize();
      final result = await sshnp.run();
      if (result is SshnpError) {
        throw result;
      }

      /// Issue a new session id
      final sessionId =
          ref.watch(terminalSessionController.notifier).createSession();

      /// Create the session controller for the new session id
      final sessionController =
          ref.watch(terminalSessionFamilyController(sessionId).notifier);

      if (result is SshnpCommand) {
        /// Set the command for the new session
        sessionController.setProcess(
            command: result.command, args: result.args);
        sessionController.issueDisplayName(widget.params.profileName!);
        ref.read(navigationRailController.notifier).setRoute(AppRoute.terminal);
        if (mounted) {
          context.pushReplacementNamed(AppRoute.terminal.name);
        }
      }
    } catch (e) {
      if (mounted) {
        context.pop();
        CustomSnackBar.error(content: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileActionButton(
      onPressed: () async {
        await onPressed();
      },
      icon: const Icon(Icons.terminal),
    );
  }
}
