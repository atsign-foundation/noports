import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class Profile443Checkbox extends StatelessWidget {
  const Profile443Checkbox({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, bool?>(
      selector: (ProfileState state) {
        if (state is ProfileLoadedState) return state.profile.only443;
        return null;
      },
      builder: (BuildContext context, bool? state) {
        if (state == null) return gap0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: state,
                  onChanged: (value) {
                    if (value == null) return;
                    var bloc = context.read<ProfileBloc>();
                    bloc.add(ProfileEditEvent(
                      profile: (bloc.state as ProfileLoadedState).profile.copyWith(only443: value),
                    ));
                  },
                ),
                gapW10,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Use port 443',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      gapH4,
                      Text(
                        'Forces the relay to use port 443 instead of an ephemeral port. '
                        'Automatically enables ESCR relay authentication mode for security.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}