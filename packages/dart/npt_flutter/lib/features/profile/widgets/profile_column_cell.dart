import 'package:flutter/widgets.dart';
import 'package:npt_flutter/features/profile/widgets/profile_device_name.dart';
import 'package:npt_flutter/features/profile/widgets/profile_display_name.dart';
import 'package:npt_flutter/features/profile/widgets/profile_service_view.dart';
import 'package:npt_flutter/features/profile/widgets/profile_status_indicator.dart';
import 'package:npt_flutter/features/profile_list/models/profile_column.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileColumnCell extends StatelessWidget {
  const ProfileColumnCell({
    super.key,
    required this.column,
    required this.width,
  });

  final ProfileColumn column;
  final double width;

  @override
  Widget build(BuildContext context) {
    return switch (column) {
      ProfileColumn.profileName => ProfileDisplayName(width: width),
      ProfileColumn.deviceName => ProfileDeviceName(width: width),
      ProfileColumn.serviceMapping => ProfileServiceView(width: width),
      ProfileColumn.status => ProfileStatusIndicator(width: width),
      ProfileColumn.select ||
      ProfileColumn.favorite ||
      ProfileColumn.menu => gap0,
    };
  }
}
