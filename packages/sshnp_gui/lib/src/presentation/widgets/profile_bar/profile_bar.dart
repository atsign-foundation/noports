import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/profile_bar_actions.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/profile_bar_stats.dart';

class ProfileBar extends ConsumerStatefulWidget {
  final String profileName;
  const ProfileBar(this.profileName, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends ConsumerState<ProfileBar> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(configFamilyController(widget.profileName));
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
            const ProfileBarStats(),
            ProfileBarActions(params),
          ],
        ),
      ),
    );
  }
}
