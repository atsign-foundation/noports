import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_actions.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/profile_bar_stats.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

import 'profile_bar_actions.dart';

class ProfileBar extends ConsumerStatefulWidget {
  final String profileName;
  const ProfileBar(this.profileName, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends ConsumerState<ProfileBar> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final controller = ref.watch(configFamilyController(widget.profileName));
    return controller.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.profileName),
            gapW8,
            Expanded(child: Container()),
            Text(strings.corruptedProfile),
            ProfileDeleteAction(widget.profileName),
          ],
        );
      },
      data: (profile) => Card(
        color: kProfileBarColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            gapW16,
            Text(widget.profileName),
            gapW8,
            Expanded(child: Container()),
            const ProfileBarStats(),
            ProfileBarActions(profile),
          ],
        ),
      ),
    );
  }
}
