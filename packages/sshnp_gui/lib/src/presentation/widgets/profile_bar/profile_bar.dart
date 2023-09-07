import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/sshnp_params_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/actions/profile_actions.dart';

class ProfileBar extends ConsumerStatefulWidget {
  final String profileName;
  const ProfileBar(this.profileName, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends ConsumerState<ProfileBar> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(sshnpParamsFamilyController(widget.profileName));
    return controller.when(
      error: (error, stackTrace) => Container(),
      loading: () => const LinearProgressIndicator(),
      data: (params) => Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(params.profileName ?? ''),
            ProfileActions(params),
          ],
        ),
      ),
    );
  }
}
