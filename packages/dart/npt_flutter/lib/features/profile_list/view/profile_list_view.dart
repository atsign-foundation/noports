import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile_group/profile_group.dart';
import 'package:npt_flutter/features/profile_list/cubit/sync_cubit.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_failed_load_content.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

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

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    SizeConfig().init();

    return BlocListener<SyncCubit, bool>(
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
                    return gap0;
                  }

                  final profiles = state.profiles.toList();
                  final isFullProfile = profiles.isNotEmpty;
                  log('profile: isFullProfile: $isFullProfile');

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sizes.p20,
                      vertical: Sizes.p10,
                    ),
                    child: Column(
                      children: [
                        isFullProfile
                            ? const Row(
                                children: [
                                  ProfileGroupSortToggle(),
                                  Spacer(),
                                  ProfileListAddButton(),
                                  gapW10,
                                  ProfileGroupCreateButton(),
                                  gapW10,
                                  ProfileListImportButton(),
                                  gapW10,
                                  ProfileGroupMoveButton(),
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
                        gapH8,
                        if (isFullProfile) const ProfileHeaderView(),
                        if (isFullProfile)
                          Expanded(
                            child: ProfileGroupedListView(profiles: profiles),
                          ),
                        if (!isFullProfile)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/empty_state_profile_bg.svg',
                                    height: Sizes.p200,
                                  ),
                                  gapH16,
                                  const DemoProfileInfoWidget(),
                                  gapH16,
                                  Text(
                                    strings.emptyProfileMessage,
                                    style: bodyMedium?.copyWith(
                                      fontSize: Sizes.p16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          };
        },
      ),
    );
  }
}
