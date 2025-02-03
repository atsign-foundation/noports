import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../../widgets/custom_card.dart';
import '../cubit/sync_cubit.dart';

class ProfileListView extends StatelessWidget {
  const ProfileListView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final deviceSize = MediaQuery.of(context).size;
    final labelSmall = Theme.of(context).textTheme.labelSmall;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    SizeConfig().init();
    return BlocBuilder<ProfileListBloc, ProfileListState>(builder: (context, state) {
      return switch (state) {
        ProfileListInitial() || ProfileListLoading() => const Center(child: Spinner()),
        ProfileListFailedLoad() => CustomCard.dashboardContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(strings.profilesFailedLoaded),
                ElevatedButton(
                  child: Text(strings.reload),
                  onPressed: () {
                    context.read<ProfileListBloc>().add(const ProfileListLoadEvent());
                  },
                ),
              ],
            ),
          ),
        ProfileListLoaded() =>
          BlocBuilder<ProfileListBloc, ProfileListState>(builder: (BuildContext context, ProfileListState state) {
            if (state is! ProfileListLoaded) {
              // These states should be handled by the ancestor
              return gap0;
            }

            final profiles = state.profiles.toList();
            final isFullProfile = profiles.isNotEmpty;
            log('profile: isFullProfile: $isFullProfile');

            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomCard.dashboardContent(
                        height: deviceSize.height * Sizes.dashboardCardHeightFactor,
                        width: SizeConfig.setDashboardWidth(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            isFullProfile
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ProfileListAddButton(),
                                      gapW10,
                                      ProfileListImportButton(),
                                      gapW10,
                                      ProfileSelectedExportButton(),
                                      gapW10,
                                      ProfileSelectedDeleteButton(),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ProfileListAddButton(),
                                      gapW10,
                                      ProfileListImportButton(),
                                    ],
                                  ),
                            gapH25,
                            isFullProfile ? const ProfileHeaderView() : gap0,
                            isFullProfile
                                ? Expanded(
                                    child: ListView.builder(
                                      itemCount: state.profiles.length,
                                      itemBuilder: (context, index) {
                                        return BlocProvider<ProfileBloc>(
                                          key: Key("ProfileListView-BlocProvider-${profiles[index]}"),
                                          create: (context) =>
                                              context.read<ProfileCacheCubit>().getProfileBloc(profiles[index]),
                                          child: const CustomCard.profile(child: ProfileView()),
                                        );
                                      },
                                    ),
                                  )
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Align(
                                        alignment: Alignment.center,
                                        child: SvgPicture.asset('assets/empty_state_profile_bg.svg'),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Text(
                                          strings.emptyProfileMessage,
                                          style: bodyMedium?.copyWith(fontSize: Sizes.p16),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    ],
                                  ),
                            BlocBuilder<SyncCubit, bool>(builder: (context, state) {
                              if (state == false) {
                                return Column(
                                  children: [
                                    isFullProfile ? gapH25 : gap0,
                                    Text(
                                      strings.syncInProgress,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              }
                              return gap0;
                            }),
                            gapH25,
                          ],
                        ),
                      ),
                      Text(
                        strings.allRightsReserved,
                        style: labelSmall?.copyWith(fontSize: labelSmall.fontSize?.toFont),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
      };
    });
  }
}
