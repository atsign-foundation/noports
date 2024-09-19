import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_select_all_box.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_card.dart';
import 'package:npt_flutter/widgets/loader_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileHeaderView extends StatelessWidget {
  const ProfileHeaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileBloc, ProfileState>(builder: (context, state) {
      if (state is ProfileInitial) {
        context.read<ProfileBloc>().add(const ProfileLoadEvent());
      }
      switch (state) {
        case ProfileInitial _:
        case ProfileLoading _:
          return const Row(
            children: [
              LoaderBar(),
              ProfileRefreshButton(),
            ],
          );

        case ProfileFailedLoad _:
          return const Row(
            children: [
              Text("Failed to load this profile, please refresh manually:"),
              ProfileRefreshButton(),
            ],
          );

        case ProfileLoadedState _:
          return BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>(
            selector: (SettingsState state) {
              if (state is SettingsLoadedState) {
                return state.settings.viewLayout;
              }
              return null;
            },
            builder: (BuildContext context, PreferredViewLayout? viewLayout) {
              return switch (viewLayout) {
                null => const Spinner(),
                PreferredViewLayout.minimal => CustomCard.profileHeader(
                    child: Padding(
                      padding: const EdgeInsets.all(Sizes.p10),
                      child: Row(
                        children: [
                          const ProfileSelectAllBox(),
                          gapW10,
                          SizedBox(width: Sizes.p150, child: Text(strings.profileName)),
                          gapW10,
                          Text(strings.status),
                          // gapW10,
                          // //Run button
                          // gapW40,
                          // gapW10,
                          // favorite button
                        ],
                      ),
                    ),
                  ),
                PreferredViewLayout.sshStyle => CustomCard.profileHeader(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sizes.p10),
                      child: Row(
                        children: [
                          const ProfileSelectAllBox(),
                          gapW10,
                          SizedBox(width: Sizes.p150, child: Text(strings.profileName)),
                          gapW10,
                          SizedBox(width: Sizes.p150, child: Text(strings.deviceName)),
                          gapW10,
                          SizedBox(width: Sizes.p150, child: Text(strings.serviceMapping)),
                          gapW10,
                          Text(strings.status),
                          // gapW10,
                          // //Run button
                          // gapW40,
                          // gapW10,
                          // favorite button
                        ],
                      ),
                    ),
                  ),
              };
            },
          );
      }
    });
  }
}
