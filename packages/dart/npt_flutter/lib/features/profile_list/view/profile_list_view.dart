import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile_list/cubit/sync_cubit.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_failed_load_content.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../../widgets/custom_card.dart';

class ProfileListView extends StatefulWidget {
  const ProfileListView({super.key});

  @override
  State<ProfileListView> createState() => _ProfileListViewState();
}

class _ProfileListViewState extends State<ProfileListView> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await BackupKeyUtils().backupKeyStatusCheck();
    });
    super.initState();
  }

  // @override
  // void didChangeDependencies() {
  //   WidgetsBinding.instance.addPostFrameCallback((_) async {
  //     context.read<SyncCubit>().state == false
  //         ? CustomSnackBar.notification(
  //             content: AppLocalizations.of(context)!.syncInProgress,
  //           )
  //         : null;
  //   });
  //   super.didChangeDependencies();
  // }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final deviceSize = MediaQuery.of(context).size;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    SizeConfig().init();

    return Column(
      children: [
        BlocListener<SyncCubit, bool>(
          listenWhen: (previous, current) => previous != current,
          listener: (context, isInSync) {
            if (isInSync == false) {
              CustomSnackBar.notification(content: strings.syncInProgress);
            } else {
              CustomSnackBar.notification(content: strings.syncCompleted);
            }
          },

          child: BlocBuilder<ProfileListBloc, ProfileListState>(
            builder: (context, state) {
              return switch (state) {
                ProfileListInitial() ||
                ProfileListLoading() => const Center(child: Spinner()),
                ProfileListFailedLoad() => const ProfileListFailedLoadContent(),
                ProfileListLoaded() =>
                  BlocBuilder<ProfileListBloc, ProfileListState>(
                    builder: (BuildContext context, ProfileListState state) {
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
                                  height:
                                      deviceSize.height *
                                      Sizes.dashboardCardHeightFactor,
                                  width: SizeConfig.setDashboardWidth(),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      isFullProfile
                                          ? const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                ProfileListAddButton(),
                                                gapW10,
                                                ProfileListImportButton(),
                                              ],
                                            ),
                                      gapH25,
                                      isFullProfile
                                          ? const ProfileHeaderView()
                                          : gap0,
                                      isFullProfile
                                          ? Expanded(
                                              child: ListView.builder(
                                                addAutomaticKeepAlives: false,
                                                addRepaintBoundaries: false,
                                                itemCount:
                                                    state.profiles.length,
                                                itemBuilder: (context, index) {
                                                  return BlocProvider.value(
                                                    key: Key(
                                                      "ProfileListView-BlocProvider-${profiles[index]}",
                                                    ),
                                                    value: context
                                                        .read<
                                                          ProfileCacheCubit
                                                        >()
                                                        .getProfileBloc(
                                                          profiles[index],
                                                        ),
                                                    child:
                                                        const CustomCard.profile(
                                                          child: ProfileView(),
                                                        ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Align(
                                                  alignment: Alignment.center,
                                                  child: SvgPicture.asset(
                                                    'assets/empty_state_profile_bg.svg',
                                                  ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Text(
                                                    strings.emptyProfileMessage,
                                                    style: bodyMedium?.copyWith(
                                                      fontSize: Sizes.p16,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                const Positioned(
                                                  top: 1,
                                                  child:
                                                      DemoProfileInfoWidget(),
                                                ),
                                              ],
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              };
            },
          ),
        ),
      ],
    );
  }
}
