import 'dart:io';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshrv/sshrv.dart';
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
    ref.read(backgroundSessionFamilyController(widget.params.profileName!).notifier).start();
    try {
      SSHNPParams params = SSHNPParams.merge(
        widget.params,
        SSHNPPartialParams(
          idleTimeout: 60,
          addForwardsToTunnel: true,
        ),
      );

      sshnp = await SSHNP.fromParams(
        params,
        atClient: AtClientManager.getInstance().atClient,
        sshrvGenerator: SSHRV.pureDart,
      );

      await sshnp!.init();
      sshnpResult = await sshnp!.run();

      if (sshnpResult is SSHNPFailed) {
        throw sshnpResult!;
      }
      ref.read(backgroundSessionFamilyController(widget.params.profileName!).notifier).endStartUp();
    } catch (e) {
      Future stop = onStop();
      if (mounted) {
        CustomSnackBar.error(content: e.toString());
      }
      await stop;
    }
  }

  Future<void> onStop() async {
    if (sshnpResult is SSHCommand) {
      (sshnpResult as SSHCommand).sshProcess?.kill(); // DirectSSHViaExec
      (sshnpResult as SSHCommand).sshClient?.close(); // DirectSSHViaClient
      var sshrvResult = await (sshnpResult as SSHCommand).sshrvResult;
      if (sshrvResult is Process) sshrvResult.kill(); // SSHRV via local binary
      if (sshrvResult is SocketConnector) sshrvResult.close(); // SSHRV via pure dart
    }
    ref.read(backgroundSessionFamilyController(widget.params.profileName!).notifier).stop();
  }

  static Widget getIconFromStatus(BackgroundSessionStatus status, BuildContext context) {
    switch (status) {
      case BackgroundSessionStatus.stopped:
        return const Icon(Icons.play_arrow);
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
    final status = ref.watch(backgroundSessionFamilyController(widget.params.profileName!));
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
