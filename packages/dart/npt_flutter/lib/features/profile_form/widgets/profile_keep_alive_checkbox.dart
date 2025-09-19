import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileKeepAliveCheckbox extends StatelessWidget {
  const ProfileKeepAliveCheckbox({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, bool?>(
      selector: (ProfileState state) {
        if (state is ProfileLoadedState) return state.profile.keepAlive;
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
                      profile: (bloc.state as ProfileLoadedState).profile.copyWith(keepAlive: value),
                    ));
                  },
                ),
                gapW10,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🕺 Keep Alive',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      gapH4,
                      Text(
                        'Stay alive. If a session ends, create a new session and '
                        're-bind to the local port. Sessions can end due to being unused after '
                        'a timeout or network issues.',
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