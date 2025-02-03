import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/widgets/profile_header_column.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
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

    return BlocBuilder<ProfileListBloc, ProfileListState>(builder: (context, state) {
      if (state is ProfileListInitial) {
        context.read<ProfileListBloc>().add(const ProfileListLoadEvent());
      }
      switch (state) {
        case ProfileListInitial _:
        case ProfileListLoading _:
          return const Row(
            children: [
              LoaderBar(),
              ProfileListRefreshButton(),
            ],
          );

        case ProfileListFailedLoad _:
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(strings.errorProfileLoadFailed),
              const ProfileListRefreshButton(),
            ],
          );

        case ProfileListLoaded _:
          return BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>(
            selector: (SettingsState state) {
              if (state is SettingsLoadedState) {
                return state.settings.viewLayout;
              }
              return null;
            },
            builder: (BuildContext context, PreferredViewLayout? viewLayout) {
              return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                final width = SizeConfig.setProfileFieldWidth();
                return switch (viewLayout) {
                  null => const Center(child: Spinner()),
                  PreferredViewLayout.minimal => CustomCard.profileHeader(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Sizes.p10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const ProfileSelectAllBox(),
                            gapW10,
                            ProfileHeaderColumn(
                                title: strings.profileName, width: SizeConfig.setProfileFieldWidthMinimalView()),
                            gapW10,
                            ProfileHeaderColumn(
                                title: strings.status, width: SizeConfig.setProfileFieldWidthMinimalView()),
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
                            ProfileHeaderColumn(
                              title: strings.profileName,
                              width: width,
                            ),
                            gapW10,
                            ProfileHeaderColumn(title: strings.deviceName, width: width),
                            gapW10,
                            ProfileHeaderColumn(title: strings.serviceMapping, width: width),
                            gapW10,
                            ProfileHeaderColumn(
                                title: strings.status, width: SizeConfig.setProfileFieldWidth(statusField: true)),
                          ],
                        ),
                      ),
                    ),
                };
              });
            },
          );
      }
    });
  }
}
