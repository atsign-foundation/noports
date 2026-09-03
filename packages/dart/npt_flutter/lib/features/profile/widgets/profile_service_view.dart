import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

import '../../../styles/sizes.dart';

class ProfileServiceView extends StatelessWidget {
  const ProfileServiceView({this.width, super.key});
  final double? width;
  @override
  Widget build(BuildContext context) {
    final Widget content =
        BlocSelector<ProfileBloc, ProfileState, (int, String, int)?>(
      selector: (state) {
        if (state is! ProfileLoadedState) return null;
        return (
          state.profile.localPort,
          state.profile.remoteHost,
          state.profile.remotePort,
        );
      },
      builder: (BuildContext context, (int, String, int)? triple) {
        if (triple == null) return gap0;
        var (localPort, remoteHost, remotePort) = triple;
        return Tooltip(
          verticalOffset: Sizes.p10n,
          message: '$localPort:$remoteHost:$remotePort',
          child: Text(
            '$localPort:$remoteHost:$remotePort',
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return content;
  }
}
