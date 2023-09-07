import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshrv/sshrv.dart';
import 'package:sshnp_gui/src/presentation/widgets/dialog/sshnp_result_alert_dialog.dart';

class ProfileRunAction extends StatefulWidget {
  final SSHNPParams params;
  const ProfileRunAction(this.params, {Key? key}) : super(key: key);

  @override
  State<ProfileRunAction> createState() => _ProfileRunActionState();
}

class _ProfileRunActionState extends State<ProfileRunAction> {
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
      final sshnpResult = await sshnp.run();

      if (mounted) {
        // pop to remove circular progress indicator
        context.pop();
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => SSHNPResultAlertDialog(
            result: sshnpResult.toString(),
            title: 'Success',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.pop();
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => SSHNPResultAlertDialog(
            result: e.toString(),
            title: 'Failed',
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
      icon: const Icon(Icons.play_arrow),
    );
  }
}
