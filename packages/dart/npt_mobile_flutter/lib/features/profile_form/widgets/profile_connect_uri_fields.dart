import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';

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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.p50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Text(
                strings.autoStartApplication,
                // style: Theme.of(context).textTheme.titleMedium,
              ),

              gapH4,
              Text(
                strings.connectUriProtocolDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              gapH20,
              _ProtocolDropdown(
                key: ValueKey('connectUriProtocol_${state.profile.uuid}'),
                protocol: state.profile.connectUriProtocol ?? '',
                onChanged: (value) {
                  var bloc = context.read<ProfileBloc>();
                  bloc.add(
                    ProfileEditEvent(
                      profile: state.profile.copyWith(
                        connectUriProtocol: value,
                        connectUri: null,
                      ),
                    ),
                  );
                },
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
                    decoration: const InputDecoration(hintText: 'username'),
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
          ),
        );
      },
    );
  }
}

class _ProtocolDropdown extends StatefulWidget {
  final String protocol;
  final ValueChanged<String?> onChanged;

  const _ProtocolDropdown({
    super.key,
    required this.protocol,
    required this.onChanged,
  });

  @override
  State<_ProtocolDropdown> createState() => _ProtocolDropdownState();
}

class _ProtocolDropdownState extends State<_ProtocolDropdown> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: DropdownMenu<String>(
        initialSelection: widget.protocol,
        expandedInsets: EdgeInsets.zero,
        hintText: strings.connectUriProtocolNone,
        dropdownMenuEntries: ProfileConnectUriFields.protocols.map((protocol) {
          return DropdownMenuEntry<String>(
            value: protocol,
            label: protocol.isEmpty ? strings.connectUriProtocolNone : protocol,
          );
        }).toList(),
        onSelected: (value) {
          if (value != null) {
            widget.onChanged(value);
          }
        },
      ),
    );
  }
}
