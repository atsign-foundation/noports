import 'package:flutter/material.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/presentation/widgets/dialog/delete_alert_dialog.dart';

class ProfileDeleteAction extends StatelessWidget {
  final SSHNPParams params;
  const ProfileDeleteAction(this.params, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DeleteAlertDialog(sshnpParams: params),
        );
      },
      icon: const Icon(Icons.delete_forever),
    );
  }
}
