import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_gui/src/controllers/profile_private_key_manager_controller.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

import '../../../../controllers/private_key_manager_controller.dart';

class ProfileTerminalAction extends ConsumerStatefulWidget {
  final SshnpParams params;
  const ProfileTerminalAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileTerminalAction> createState() => _ProfileTerminalActionState();
}

class _ProfileTerminalActionState extends ConsumerState<ProfileTerminalAction> {
  Future<void> onPressed(String privateKeyNickname) async {
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

    try {
      // TODO ensure that this keyPair gets uploaded to the app first
      final privateKeyManager = ref.watch(privateKeyManagerFamilyController(privateKeyNickname));
      log(privateKeyNickname);
      final params = privateKeyManager.when(data: (value) {
        log('content: ${value.content}, passPhrase: ${value.passPhrase}');

        return SshnpParams.merge(
          widget.params,
          SshnpPartialParams(identityFile: value.content, identityPassphrase: value.passPhrase),
        );
      }, error: (error, stackTrace) {
        log(error.toString());
      }, loading: () {
        log('loading');
      });
      
      
      AtClient atClient = AtClientManager.getInstance().atClient;
      // TODO: Delete the below line
      // DartSshKeyUtil keyUtil = DartSshKeyUtil();
      // widget.params was originally used
      // AtSshKeyPair keyPair = await keyUtil.getKeyPair(
      //   identifier: widget.params.identityFile ?? 'id_${atClient.getCurrentAtSign()!.replaceAll('@', '')}',
      // );
      // TODO: Get values from biometric strogage (PrivateKeyManagerController)
      AtSshKeyPair keyPair = AtSshKeyPair.fromPem(pemText, identifier: identifier, passphrase: );

      final sshnp = Sshnp.dartPure(
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
    final profilePrivateKeys = ref.watch(profilePrivateKeyManagerListController);
    return profilePrivateKeys.when(
        data: (data) {
          return PopupMenuButton(
            icon: const Icon(Icons.terminal),
            tooltip: 'select a private key to ssh with',
            itemBuilder: (itemBuilderContext) => data
                .map((e) => PopupMenuItem(
                      onTap: (() => onPressed(e.split('-').last)),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key),
                          gapW12,
                          Text(e),
                        ],
                      ),
                    ))
                .toList(),
          );
        },
        error: (error, stack) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()));
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
