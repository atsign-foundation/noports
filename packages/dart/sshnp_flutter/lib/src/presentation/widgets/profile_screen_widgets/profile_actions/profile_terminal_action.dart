import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_flutter/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_action_button.dart';
import 'package:sshnp_flutter/src/repository/private_key_manager_repository.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import '../../../../repository/profile_private_key_manager_repository.dart';
import '../../utility/custom_snack_bar.dart';

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
    if (mounted) {
      showProgress('Starting Shell Session...');
    }

    /// Issue a new session id
    final sessionId = ref.watch(terminalSessionController.notifier).createSession();

    /// Create the session controller for the new session id
    final sessionController = ref.watch(terminalSessionFamilyController(sessionId).notifier);

    try {
      AtClient atClient = AtClientManager.getInstance().atClient;

      final profilePrivateKey =
          await ProfilePrivateKeyManagerRepository.readProfilePrivateKeyManager(widget.params.profileName ?? '');
      final privateKeyManager =
          await PrivateKeyManagerRepository.readPrivateKeyManager(profilePrivateKey.privateKeyNickname);

      final keyPair = privateKeyManager.toAtSshKeyPair();

      final sshnp = Sshnp.dartPure(
        params: SshnpParams.merge(
          widget.params,
          SshnpPartialParams(
            verbose: kDebugMode,
            idleTimeout: 30,
          ),
        ),
        atClient: atClient,
        identityKeyPair: keyPair,
      );

      final result = await sshnp.run();
      if (result is SshnpError) {
        throw result;
      }

      if (result is SshnpCommand) {
        if (sshnp.canRunShell) {
          if (mounted) {
            context.pop();
            showProgress('running shell session...');
          }
          log('running shell session...');

          SshnpRemoteProcess shell = await sshnp.runShell();
          if (mounted) {
            context.pop();
            showProgress('starting terminal session...');
          }
          log('starting terminal session');
          sessionController.startSession(
            shell,
            terminalTitle: '${widget.params.sshnpdAtSign}-${widget.params.device}',
          );
        }

        sessionController.issueDisplayName(widget.params.profileName!);

        ref.read(navigationRailController.notifier).setRoute(AppRoute.terminal);
        if (mounted) {
          context.pushReplacementNamed(AppRoute.terminal.name);
        }
      }
    } catch (e) {
      sessionController.dispose();
      if (mounted) {
        log('error: ${e.toString()}');
        context.pop();
        CustomSnackBar.error(content: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileActionButton(onPressed: onPressed, icon: const Icon(Icons.terminal));
  }
}
