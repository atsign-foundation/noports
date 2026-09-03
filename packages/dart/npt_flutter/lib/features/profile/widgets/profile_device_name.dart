import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

import '../../../styles/sizes.dart';

class ProfileDeviceName extends StatelessWidget {
  const ProfileDeviceName({this.width, super.key});
  final double? width;
  @override
  Widget build(BuildContext context) {
    final Widget content =
        BlocSelector<ProfileBloc, ProfileState, (String, String)?>(
      selector: (state) {
        if (state is! ProfileLoadedState) return null;
        return (
          state.profile.deviceName,
          state.profile.sshnpdAtsign?.toString() ?? '',
        );
      },
      builder: (BuildContext context, (String, String)? tuple) {
        if (tuple == null) return gap0;
        var (deviceName, sshnpdAtsign) = tuple;
        return Tooltip(
          verticalOffset: Sizes.p10n,
          message: '$deviceName$sshnpdAtsign',
          child: Text(
            '$deviceName$sshnpdAtsign',
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
