import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/bloc/profile_bloc.dart';
import 'package:npt_flutter/features/profile/cubit/profile_cache_cubit.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ConnectedProfilesDialog extends StatelessWidget {
  const ConnectedProfilesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    // Get running profile UUIDs
    final connectedUuids = context
        .watch<ProfilesRunningCubit>()
        .state
        .socketConnectors
        .keys
        .toSet();
    // Get all loaded profiles (UUIDs)
    final profileListState = context.watch<ProfileListBloc>().state;
    List<Map<String, String>> connectedProfileNames = [];
    if (profileListState is ProfileListLoaded) {
      connectedProfileNames = profileListState.profiles
          .where((uuid) => connectedUuids.contains(uuid))
          .map((uuid) {
            final profileBloc = context
                .read<ProfileCacheCubit>()
                .getProfileBloc(uuid);
            final profileState = profileBloc.state;
            if (profileState is ProfileLoadedState) {
              return {
                'profileName': profileState.profile.displayName,
                'deviceName': profileState.profile.deviceName,
              };
            } else {
              return {
                'profileName': uuid,
                'deviceName': '',
              }; // fallback if not loaded
            }
          })
          .toList();
    }
    return AlertDialog(
      scrollable: true,
      title: Row(
        spacing: Sizes.p8,
        children: [
          PhosphorIcon(
            PhosphorIcons.userCircle(),
            // color: Colors.red,
          ),
          Text(strings.switchAtSign),
        ],
      ),
      content: connectedProfileNames.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.switchAtSignDescription,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(strings.profileRunningCloseMsgStart),
                gapH8,
                Container(
                  color: AppColor.greyColor,
                  width: 470,
                  height: Sizes.p192,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 0,
                          top: Sizes.p10,
                          left: Sizes.p10,
                          right: Sizes.p10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(strings.profileName),
                            Text(strings.deviceName),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(Sizes.p8),
                          shrinkWrap: true,
                          itemCount: connectedProfileNames.length,
                          itemBuilder: (context, count) => Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Sizes.p4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(Sizes.p10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    connectedProfileNames[count]['profileName'] ??
                                        '',
                                  ),
                                  Text(
                                    connectedProfileNames[count]['deviceName'] ??
                                        '',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                gapH16,
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: strings.switchAtSignNote.split(' ').first,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: AppColor.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' ${strings.switchAtSignNote.split(' ').skip(1).join(' ')}',
                      ),
                    ],
                  ),
                ),
              ],
            )
          : gap0,
      actions: [
        TextButton(
          // Return true because profiles are running
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.cancel),
        ),
        if (connectedProfileNames.isNotEmpty)
          TextButton(
            onPressed: () {
              // Stop all running profiles
              for (final uuid in connectedUuids) {
                context.read<ProfilesRunningCubit>().invalidate(uuid);
              }
              // Return false because their is no running profile
              Navigator.of(context).pop(false);
            },
            child: Text(strings.confirm),
          ),
      ],
    );
  }
}
