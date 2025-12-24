import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileConnectUriTextField extends StatelessWidget {
  const ProfileConnectUriTextField({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.connectUri),
        gapH4,
        Text(
          strings.connectUriDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        gapH14,
        BlocBuilder<ProfileBloc, ProfileState>(
          builder: (BuildContext context, ProfileState state) {
            if (state is! ProfileLoadedState) return const SizedBox.shrink();
            return SizedBox(
              width: double.infinity,
              child: TextFormField(
                key: ValueKey('connectUri_${state.profile.uuid}'),
                initialValue: state.profile.connectUri ?? '',
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  errorMaxLines: 3,
                  hintText:
                      'e.g., http://localhost:8080 or rdp://localhost:3389',
                ),
                onChanged: (value) {
                  var bloc = context.read<ProfileBloc>();
                  bloc.add(
                    ProfileEditEvent(
                      profile: state.profile.copyWith(
                        connectUri: value.isEmpty ? null : value,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
