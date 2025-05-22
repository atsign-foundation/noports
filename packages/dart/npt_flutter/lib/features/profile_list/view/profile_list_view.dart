import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_failed_load_content.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../../widgets/custom_card.dart';
import '../cubit/sync_cubit.dart';

class ProfileListView extends StatefulWidget {
  const ProfileListView({super.key});

  @override
  State<ProfileListView> createState() => _ProfileListViewState();
}

class _ProfileListViewState extends State<ProfileListView> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await BackupKeyUtils().BackupKeyStatusCheck();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final deviceSize = MediaQuery.of(context).size;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    SizeConfig().init();
    return BlocBuilder<ProfileListBloc, ProfileListState>(builder: (context, state) {
      return switch (state) {
        ProfileListInitial() || ProfileListLoading() => const Center(child: Spinner()),
        ProfileListFailedLoad() => const ProfileListFailedLoadContent(),
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
                                      addAutomaticKeepAlives: false,
                                      addRepaintBoundaries: false,
                                      itemCount: state.profiles.length,
                                      itemBuilder: (context, index) {
                                        return BlocProvider.value(
                                          key: Key("ProfileListView-BlocProvider-${profiles[index]}"),
                                          value: context.read<ProfileCacheCubit>().getProfileBloc(profiles[index]),
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
                                      ),
                                      const Positioned(
                                        top: 1,
                                        child: DemoProfileInfoWidget(),
                                      ),
                                    ],
                                  ),
                            BlocBuilder<SyncCubit, bool>(buildWhen: (previous, current) {
                              log('previous: $previous, current: $current');
                              return previous != current;
                            }, builder: (context, state) {
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
                              log('gap 0 called');
                              return gap0;
                            }),
                            gapH25,
                          ],
                        ),
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
