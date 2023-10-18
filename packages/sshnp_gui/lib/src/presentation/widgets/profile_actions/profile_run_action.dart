import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnp_gui/src/controllers/background_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_action_button.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';

class ProfileRunAction extends ConsumerStatefulWidget {
  final SSHNPParams params;
  const ProfileRunAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileRunAction> createState() => _ProfileRunActionState();
}

class _ProfileRunActionState extends ConsumerState<ProfileRunAction> {
  SSHNP? sshnp;
  SSHNPResult? sshnpResult;

  @override
  void initState() {
    super.initState();
  }

  Future<void> onStart() async {
    ref
        .read(backgroundSessionFamilyController(widget.params.profileName!)
            .notifier)
        .start();
    try {
      SSHNPParams params = SSHNPParams.merge(
        widget.params,
        SSHNPPartialParams(
          idleTimeout: 120, // 120 / 60 = 2 minutes
          addForwardsToTunnel: true,
          legacyDaemon: false,
          sshClient: SupportedSshClient.dart,
        ),
      );

      // TODO ensure that this keyPair gets uploaded to the app first
      AtClient atClient = AtClientManager.getInstance().atClient;
      DartSSHKeyUtil keyUtil = DartSSHKeyUtil();
      AtSSHKeyPair keyPair = await keyUtil.getKeyPair(
        identifier: params.identityFile ??
            'id_${atClient.getCurrentAtSign()!.replaceAll('@', '')}',
      );

      sshnp = SSHNP.forwardPureDart(
        params: params,
        atClient: atClient,
        identityKeyPair: keyPair,
      );

      await sshnp!.init();
      sshnpResult = await sshnp!.run();

      if (sshnpResult is SSHNPError) {
        throw sshnpResult!;
      }
      ref
          .read(backgroundSessionFamilyController(widget.params.profileName!)
              .notifier)
          .endStartUp();
    } catch (e) {
      Future stop = onStop();
      if (mounted) {
        CustomSnackBar.error(content: e.toString());
      }
      await stop;
    }
  }

  Future<void> onStop() async {
    if (sshnpResult is SSHNPCommand) {
      await (sshnpResult as SSHNPCommand).killConnectionBean();
    }
    ref
        .read(backgroundSessionFamilyController(widget.params.profileName!)
            .notifier)
        .stop();
  }

  static Widget getIconFromStatus(
      BackgroundSessionStatus status, BuildContext context) {
    switch (status) {
      case BackgroundSessionStatus.stopped:
        return const Icon(
          Icons.play_arrow_outlined,
          color: Colors.green,
        );
      case BackgroundSessionStatus.running:
        return const Icon(Icons.stop);
      case BackgroundSessionStatus.loading:
        return SizedBox(
          width: IconTheme.of(context).size,
          height: IconTheme.of(context).size,
          child: const CircularProgressIndicator(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref
        .watch(backgroundSessionFamilyController(widget.params.profileName!));
    return ProfileActionButton(
      onPressed: () async {
        switch (status) {
          case BackgroundSessionStatus.stopped:
            await onStart();
            break;
          case BackgroundSessionStatus.loading:
            break;
          case BackgroundSessionStatus.running:
            await onStop();
            break;
        }
      },
      icon: getIconFromStatus(status, context),
    );
  }
}
