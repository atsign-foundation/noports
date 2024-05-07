import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/controllers/config_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_actions.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_bar/profile_bar_stats.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import 'profile_bar_actions.dart';

class ProfileBar extends ConsumerStatefulWidget {
  final String profileName;
  const ProfileBar(this.profileName, {super.key});

  @override
  ConsumerState<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends ConsumerState<ProfileBar> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    SizeConfig().init(context);
    final controller = ref.watch(configFamilyController(widget.profileName));

    final bodyMedium = Theme.of(context).textTheme.bodyMedium!;

    return controller.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.profileName,
                  style: bodyMedium.copyWith(
                    fontSize: bodyMedium.fontSize!.toFont,
                  )),
              gapW8,
              Expanded(child: Container()),
              Text(strings.corruptedProfile,
                  style: bodyMedium.copyWith(
                    fontSize: bodyMedium.fontSize!.toFont,
                  )),
              ProfileDeleteAction(widget.profileName),
            ],
          );
        },
        data: (profile) {
          return Card(
            color: kProfileBarColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                gapW16,
                Text(widget.profileName,
                    style: bodyMedium.copyWith(
                      fontSize: bodyMedium.fontSize!.toFont,
                    )),
                gapW8,
                const Expanded(child: gap0),
                const ProfileBarStats(),
                ProfileBarActions(profile),
              ],
            ),
          );
        });
  }
}
