import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

import '../../../styles/sizes.dart';

class ProfileServiceView extends StatelessWidget {
  const ProfileServiceView({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: deviceWidth * Sizes.profileFieldsWidthFactor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: BlocSelector<ProfileBloc, ProfileState, (int, String, int)?>(selector: (state) {
          if (state is! ProfileLoadedState) return null;
          return (state.profile.localPort, state.profile.remoteHost, state.profile.remotePort);
        }, builder: (BuildContext context, (int, String, int)? triple) {
          if (triple == null) return gap0;
          var (localPort, remoteHost, remotePort) = triple;
          return Text('$localPort:$remoteHost:$remotePort');
        }),
      ),
    );
  }
}
