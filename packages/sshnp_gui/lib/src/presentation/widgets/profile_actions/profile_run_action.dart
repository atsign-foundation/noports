import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<void> onStart() async {
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      sshnp = await SSHNP.fromParams(
        widget.params,
        atClient: AtClientManager.getInstance().atClient,
        sshrvGenerator: SSHRV.pureDart,
      );

      // TODO set --single-session, --timeout

      await sshnp!.init();
      final sshnpResult = await sshnp!.run();
      // TODO throw away bad results
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(content: e.toString());
      }
    } finally {
      if (mounted) {
        context.pop();
      }
    }
  }

  Future<void> onStop() async {
    // need to implement SSHNP.stop
  }

  static const Map<BackgroundSessionStatus, Widget> _iconMap = {
    BackgroundSessionStatus.stopped: Icon(Icons.play_arrow),
    BackgroundSessionStatus.loading: CircularProgressIndicator(),
    BackgroundSessionStatus.running: Icon(Icons.stop),
  };

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(backgroundSessionFamilyController(widget.params.profileName!)).status;
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
      icon: _iconMap[status]!,
    );
  }
}
