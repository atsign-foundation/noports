import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

import '../../../styles/sizes.dart';

class ProfileDeviceName extends StatelessWidget {
  const ProfileDeviceName({required this.width, super.key});
  final double width;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: BlocSelector<ProfileBloc, ProfileState, (String, String)?>(selector: (state) {
          if (state is! ProfileLoadedState) return null;
          return (state.profile.deviceName, state.profile.sshnpdAtsign);
        }, builder: (BuildContext context, (String, String)? tuple) {
          if (tuple == null) return gap0;
          var (deviceName, sshnpdAtSign) = tuple;
          return Tooltip(message: '$deviceName$sshnpdAtSign', child: Text('$deviceName$sshnpdAtSign'));
        }),
      ),
    );
  }
}
