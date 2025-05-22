import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/bloc/profile_bloc.dart';
import 'package:npt_flutter/features/profile/cubit/profile_cache_cubit.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ConnectedProfilesDialog extends StatelessWidget {
  const ConnectedProfilesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    // Get running profile UUIDs
    final connectedUuids = context.watch<ProfilesRunningCubit>().state.socketConnectors.keys.toSet();
    // Get all loaded profiles (UUIDs)
    final profileListState = context.watch<ProfileListBloc>().state;
    List<String> connectedProfileNames = [];
    if (profileListState is ProfileListLoaded) {
      connectedProfileNames = profileListState.profiles.where((uuid) => connectedUuids.contains(uuid)).map((uuid) {
        final profileBloc = context.read<ProfileCacheCubit>().getProfileBloc(uuid);
        final profileState = profileBloc.state;
        if (profileState is ProfileLoadedState) {
          return profileState.profile.displayName;
        } else {
          return uuid; // fallback if not loaded
        }
      }).toList();
    }
    return AlertDialog(
      scrollable: true,
      title: Row(
        spacing: Sizes.p8,
        children: [
          PhosphorIcon(
            PhosphorIcons.x(PhosphorIconsStyle.bold),
            color: Colors.red,
          ),
          Text(strings.switchAtSign, style: Theme.of(context).textTheme.titleMedium)
        ],
      ),
      content: connectedProfileNames.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: Sizes.p8,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.plugsConnected(),
                    ),
                    Text(strings.activeConnections)
                  ],
                ),
                gapH8,
                Text(strings.profileRunningCloseMsgStart),
                gapH8,
                SizedBox(
                  width: Sizes.p210,
                  height: Sizes.p150,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: connectedProfileNames.length,
                    itemBuilder: (context, count) => Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.dot(),
                        ),
                        Text(connectedProfileNames[count]),
                      ],
                    ),
                  ),
                ),
                Text(strings.profileRunningCloseMsgEnd),
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
