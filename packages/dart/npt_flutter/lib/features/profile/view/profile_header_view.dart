import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/widgets/profile_header_column.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/loader_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileHeaderView extends StatelessWidget {
  const ProfileHeaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return BlocBuilder<ProfileListBloc, ProfileListState>(
      builder: (context, state) {
        if (state is ProfileListInitial) {
          context.read<ProfileListBloc>().add(const ProfileListLoadEvent());
        }
        switch (state) {
          case ProfileListInitial _:
          case ProfileListLoading _:
            return const Row(
              children: [LoaderBar(), ProfileListRefreshButton()],
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
            return BlocSelector<
              SettingsBloc,
              SettingsState,
              PreferredViewLayout?
            >(
              selector: (SettingsState state) {
                if (state is SettingsLoadedState) {
                  return state.settings.viewLayout;
                }
                return null;
              },
              builder: (BuildContext context, PreferredViewLayout? viewLayout) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: Sizes.p8,
                    horizontal: Sizes.p10,
                  ),
                  child: switch (viewLayout) {
                    null => const Center(child: Spinner()),
                    PreferredViewLayout.minimal => Row(
                      children: [
                        const ProfileSelectAllBox(),
                        gapW10,
                        Expanded(
                          flex: 3,
                          child: ProfileHeaderColumn(
                            title: strings.profileName,
                          ),
                        ),
                        gapW10,
                        Expanded(
                          flex: 3,
                          child: ProfileHeaderColumn(title: strings.status),
                        ),
                        const Spacer(),
                        const SizedBox(width: Sizes.p80),
                      ],
                    ),
                    PreferredViewLayout.sshStyle => Row(
                      children: [
                        const ProfileSelectAllBox(),
                        gapW10,
                        Expanded(
                          flex: 2,
                          child: ProfileHeaderColumn(
                            title: strings.profileName,
                          ),
                        ),
                        gapW10,
                        Expanded(
                          flex: 2,
                          child: ProfileHeaderColumn(
                            title: strings.deviceName,
                          ),
                        ),
                        gapW10,
                        Expanded(
                          flex: 2,
                          child: ProfileHeaderColumn(
                            title: strings.serviceMapping,
                          ),
                        ),
                        gapW10,
                        Expanded(
                          flex: 2,
                          child: ProfileHeaderColumn(title: strings.status),
                        ),
                        gapW10,
                        const SizedBox(width: Sizes.p80),
                      ],
                    ),
                  },
                );
              },
            );
        }
      },
    );
  }
}
