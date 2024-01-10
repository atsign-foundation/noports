import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_action_button.dart';
import 'package:sshnp_gui/src/repository/private_key_manager_repository.dart';

import '../../../../repository/profile_private_key_manager_repository.dart';
import '../../utility/custom_snack_bar.dart';

class ProfileTerminalAction extends ConsumerStatefulWidget {
  final SshnpParams params;
  const ProfileTerminalAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileTerminalAction> createState() => _ProfileTerminalActionState();
}

class _ProfileTerminalActionState extends ConsumerState<ProfileTerminalAction> {
  Future<void> onPressed() async {
    log(widget.params.profileName ?? 'no profile name');
    log(widget.params.identityPassphrase ?? 'no passphrase');
    log(widget.params.identityFile ?? 'no identity file');
    log(widget.params.clientAtSign ?? 'no client at sign');
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
      );
    }
    // TODO: add try
    try {
      // TODO ensure that this keyPair gets uploaded to the app first
      // final privateKeyManager = ref.watch(privateKeyManagerFamilyController(privateKeyNickname));

      // final params = privateKeyManager.when(data: (value) {
      //   log('content: ${value.content}, passPhrase: ${value.passPhrase}');

      //   return SshnpParams.merge(
      //     widget.params,
      //     SshnpPartialParams(identityFile: value.content, identityPassphrase: value.passPhrase),
      //   );
      // }, error: (error, stackTrace) {
      //   log(error.toString());
      // }, loading: () {
      //   log('loading');
      // });

      AtClient atClient = AtClientManager.getInstance().atClient;
      // TODO: Delete the below line
      // DartSshKeyUtil keyUtil = DartSshKeyUtil();
      // widget.params was originally used
      // AtSshKeyPair keyPair = await keyUtil.getKeyPair(
      //   identifier: widget.params.identityFile ?? 'id_${atClient.getCurrentAtSign()!.replaceAll('@', '')}',
      // );
      // TODO: Get values from biometric storage (PrivateKeyManagerController)

      final profilePrivateKey =
          await ProfilePrivateKeyManagerRepository.readProfilePrivateKeyManager(widget.params.profileName ?? '');
      final privateKeyManager =
          await PrivateKeyManagerRepository.readPrivateKeyManager(profilePrivateKey?.privateKeyNickname ?? '');
      // log('private key is: ${privateKeyManager!.privateKeyFileName}');
      // log('private key manager passphrase is: ${privateKeyManager.passPhrase}');
      // AtSshKeyPair keyPair = AtSshKeyPair.fromPem(
      //   privateKeyManager.content,
      //   identifier: privateKeyManager.privateKeyFileName,
      //   passphrase: privateKeyManager.passPhrase,
      //   // passphrase: privateKeyManager.passPhrase,
      // );
      final keyPair = privateKeyManager?.toAtSshKeyPair();

      final sshnp = Sshnp.dartPure(
        // params: sshnpParams,
        params: widget.params,
        atClient: atClient,
        identityKeyPair: keyPair,
      );

      final result = await sshnp.run();
      if (result is SshnpError) {
        throw result;
      }

      /// Issue a new session id
      final sessionId = ref.watch(terminalSessionController.notifier).createSession();

      /// Create the session controller for the new session id
      final sessionController = ref.watch(terminalSessionFamilyController(sessionId).notifier);

      if (result is SshnpCommand) {
        /// Set the command for the new session
        sessionController.setProcess(command: result.command, args: result.args);
        log('profile name is ${widget.params.profileName}');
        sessionController.issueDisplayName(widget.params.profileName!);
        ref.read(navigationRailController.notifier).setRoute(AppRoute.terminal);
        if (mounted) {
          context.pushReplacementNamed(AppRoute.terminal.name);
        }
      }
      //TODO: Add catch
    } catch (e) {
      if (mounted) {
        log('error: ${e.toString()}');
        context.pop();
        CustomSnackBar.error(content: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //TODO: Add a terminal icon that calls on pressed. Reuse old code
    return ProfileActionButton(onPressed: onPressed, icon: const Icon(Icons.terminal));
    // final profilePrivateKeys = ref.watch(profilePrivateKeyManagerListController);
    // return profilePrivateKeys.when(
    //     data: (data) {
    //       return PopupMenuButton(
    //         icon: const Icon(Icons.terminal),
    //         tooltip: 'select a private key to ssh with',
    //         itemBuilder: (itemBuilderContext) => data
    //             .map((e) => PopupMenuItem(
    //                   onTap: (() async => await ref.read(profilePrivateKeyManagerListController.notifier).remove(e)),
    //                   child: Row(
    //                     children: [
    //                       const Icon(Icons.vpn_key),
    //                       gapW12,
    //                       Text(e),
    //                     ],
    //                   ),
    //                 ))
    //             .toList(),
    //       );
    //     },
    //     error: (error, stack) => Center(child: Text(error.toString())),
    //     loading: () => const Center(child: CircularProgressIndicator()));
  }
}

const content = """-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBZuGcLVvPhnszgd5VLiij8BGhFpBpqKVjO+m8PdIFphwAAALBhI2cbYSNn
GwAAAAtzc2gtZWQyNTUxOQAAACBZuGcLVvPhnszgd5VLiij8BGhFpBpqKVjO+m8PdIFphw
AAAECrtllzlYcwI8k32n9VuHfFS1iPnxk+/1ItFW61YF4M+lm4ZwtW8+GezOB3lUuKKPwE
aEWkGmopWM76bw90gWmHAAAAKWN1cnRseWNyaXRjaGxvd0BDdXJ0bHlzLU1hY0Jvb2stUH
JvLmxvY2FsAQIDBA==
-----END OPENSSH PRIVATE KEY-----""";
