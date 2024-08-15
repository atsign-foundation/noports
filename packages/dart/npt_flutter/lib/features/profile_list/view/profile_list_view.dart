import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileListView extends StatelessWidget {
  const ProfileListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileListBloc, ProfileListState>(
        builder: (context, state) {
      return switch (state) {
        ProfileListInitial() || ProfileListLoading() => const Spinner(),
        ProfileListFailedLoad() => Column(
            children: [
              const Text("Failed to load profiles"),
              ElevatedButton(
                child: const Text("Reload"),
                onPressed: () {
                  context
                      .read<ProfileListBloc>()
                      .add(const ProfileListLoadEvent());
                },
              ),
            ],
          ),
        ProfileListLoaded() => BlocBuilder<ProfileListBloc, ProfileListState>(
              builder: (BuildContext context, ProfileListState state) {
            if (state is! ProfileListLoaded) {
              // These states should be handled by the ancestor
              return const SizedBox();
            }

            var profiles = state.profiles.toList();
            return Column(
              children: [
                const Row(
                  children: [
                    ProfileSelectAllBox(),
                    ProfileListAddButton(),
                    ProfileListImportButton(),
                    ProfileListRefreshButton(),
                    ProfileSelectedExportButton(),
                    ProfileSelectedDeleteButton(),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.profiles.length,
                    itemBuilder: (context, index) {
                      return BlocProvider<ProfileBloc>(
                        key: Key(
                            "ProfileListView-BlocProvider-${profiles[index]}"),
                        create: (context) => ProfileBloc(
                            context.read<ProfileRepository>(), profiles[index]),
                        child: const ProfileView(),
                      );
                    },
                  ),
                ),
              ],
            );
          }),
      };
    });
  }
}
