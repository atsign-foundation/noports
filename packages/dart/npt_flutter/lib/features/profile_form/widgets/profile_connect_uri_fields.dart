import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileConnectUriFields extends StatelessWidget {
  const ProfileConnectUriFields({super.key});

  static const List<String> protocols = [
    '', // None
    'http',
    'https',
    'rdp',
    'ssh',
    'vnc',
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (BuildContext context, ProfileState state) {
        if (state is! ProfileLoadedState) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Text(
              strings.autoStartApplication,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            gapH20,
            // Protocol dropdown
            Text(strings.connectUriProtocol),
            gapH4,
            Text(
              strings.connectUriProtocolDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            gapH14,
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                key: ValueKey('connectUriProtocol_${state.profile.uuid}'),
                value: state.profile.connectUriProtocol ?? '',
                decoration: InputDecoration(
                  hintText: strings.connectUriProtocolNone,
                ),
                items: protocols.map((protocol) {
                  return DropdownMenuItem<String>(
                    value: protocol,
                    child: Text(protocol.isEmpty ? strings.connectUriProtocolNone : protocol),
                  );
                }).toList(),
                onChanged: (value) {
                  var bloc = context.read<ProfileBloc>();
                  bloc.add(
                    ProfileEditEvent(
                      profile: state.profile.copyWith(
                        // Set to empty string for "None", which marks it as explicitly set
                        connectUriProtocol: value,
                        // Clear old connectUri when setting protocol
                        connectUri: null,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Username field (only show if protocol is selected)
            if (state.profile.connectUriProtocol != null && 
                state.profile.connectUriProtocol!.isNotEmpty) ...[
              gapH20,
              Text(strings.connectUriUsername),
              gapH4,
              Text(
                strings.connectUriUsernameDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              gapH14,
              SizedBox(
                width: double.infinity,
                child: TextFormField(
                  key: ValueKey('connectUriUsername_${state.profile.uuid}'),
                  initialValue: state.profile.connectUriUsername ?? '',
                  decoration: const InputDecoration(
                    hintText: 'username',
                  ),
                  onChanged: (value) {
                    var bloc = context.read<ProfileBloc>();
                    bloc.add(
                      ProfileEditEvent(
                        profile: state.profile.copyWith(
                          connectUriUsername: value.isEmpty ? null : value,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
