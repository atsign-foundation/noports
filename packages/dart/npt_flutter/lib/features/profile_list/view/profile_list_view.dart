import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../../widgets/custom_card.dart';

class ProfileListView extends StatelessWidget {
  const ProfileListView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileListBloc, ProfileListState>(builder: (context, state) {
      return switch (state) {
        ProfileListInitial() || ProfileListLoading() => const Spinner(),
        ProfileListFailedLoad() => CustomCard.dashboardContent(
            child: Column(
              children: [
                const Text("Failed to load profiles"),
                ElevatedButton(
                  child: const Text("Reload"),
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
              return const SizedBox();
            }

            var profiles = state.profiles.toList();
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomCard.dashboardContent(
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                gap0,
                                Row(children: [
                                  ProfileListAddButton(),
                                  gapW10,
                                  ProfileListImportButton(),
                                  gapW10,
                                  ProfileListRefreshButton(),
                                  gapW10,
                                  ProfileSelectedExportButton(),
                                  gapW10,
                                  ProfileSelectedDeleteButton(),
                                ])
                              ],
                            ),
                            gapH25,
                            const ProfileHeaderView(),
                            Expanded(
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
                            ),
                          ],
                        ),
                      ),
                      gapH16,
                      Text(strings.allRightsReserved)
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
