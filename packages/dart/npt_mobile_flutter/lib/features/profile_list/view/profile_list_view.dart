import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_mobile_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';
import 'package:npt_mobile_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_mobile_flutter/features/profile_list/cubit/sync_cubit.dart';
import 'package:npt_mobile_flutter/features/profile_list/profile_list.dart';
import 'package:npt_mobile_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_mobile_flutter/features/profile_list/widgets/profile_list_failed_load_content.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_mobile_flutter/widgets/spinner.dart';

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
            ProfileListLoaded() => BlocBuilder<ProfileListBloc, ProfileListState>(
              builder: (BuildContext context, ProfileListState state) {
                if (state is! ProfileListLoaded) {
                  return gap0;
                }

                final profiles = state.profiles.toList();
                final isFullProfile = profiles.isNotEmpty;
                log('profile: isFullProfile: $isFullProfile');

                return Column(
                  children: [
                    // Mobile action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: isFullProfile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: const ProfileListAddButton(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: const ProfileListImportButton(),
                                      ),
                                    ),
                                  ],
                                ),
                                // Selected actions on separate row for better mobile UX
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                          const ProfileSelectedExportButton(),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child:
                                          const ProfileSelectedDeleteButton(),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: const ProfileListAddButton(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: const ProfileListImportButton(),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    // Profile list
                    Expanded(
                      child: isFullProfile
                          ? Column(
                              children: [
                                // Header
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: ProfileHeaderView(),
                                ),
                                gapH16,
                                // List
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    addAutomaticKeepAlives: false,
                                    addRepaintBoundaries: false,
                                    itemCount: state.profiles.length,
                                    itemBuilder: (context, index) {
                                      return BlocProvider.value(
                                        key: Key(
                                          "ProfileListView-BlocProvider-${profiles[index]}",
                                        ),
                                        value: context
                                            .read<ProfileCacheCubit>()
                                            .getProfileBloc(profiles[index]),
                                        child: const Padding(
                                          padding: EdgeInsets.only(bottom: 8),
                                          child: CustomCard.profile(
                                            child: ProfileView(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const DemoProfileInfoWidget(),
                                    const SizedBox(height: 32),
                                    SvgPicture.asset(
                                      'assets/empty_state_profile_bg.svg',
                                      height: 160,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No profiles found',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      strings.emptyProfileMessage,
                                      style: bodyMedium?.copyWith(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          };
        },
      ),
    );
  }
}
